[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ApiKeyPath,
    [string] $Model = 'deepseek-v4-flash',
    [string] $BaseUrl = 'https://api.deepseek.com',
    [string] $CasesFile = '',
    [string] $ArtifactPath = '',
    [switch] $SkipDeterministic
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$root = Split-Path $PSScriptRoot -Parent
$pluginRoot = Join-Path $root 'plugins\dsh-routing-suite-codex'
if ([string]::IsNullOrWhiteSpace($CasesFile)) { $CasesFile = Join-Path $pluginRoot 'tests\stress-cases.json' }
if ([string]::IsNullOrWhiteSpace($ArtifactPath)) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $ArtifactPath = Join-Path $root "artifacts\stress-acceptance-$stamp.json"
}

if (-not $SkipDeterministic) {
    Write-Host '[stress] deterministic gate (Test-Parity.ps1)...'
    & pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $pluginRoot 'tests\Test-Parity.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Deterministic parity gate failed; live layer skipped.' }
}

function Invoke-DeepSeekRequest {
    param([Parameter(Mandatory)] [string] $Path, [Parameter(Mandatory)] [string] $Method, [object] $Body)
    $headers = @{ Authorization = "Bearer $script:ApiKey" }
    try {
        if ($Method -eq 'GET') {
            return Invoke-RestMethod -Method Get -Uri "$BaseUrl$Path" -Headers $headers -TimeoutSec 120
        }
        $json = $Body | ConvertTo-Json -Depth 12 -Compress
        return Invoke-RestMethod -Method Post -Uri "$BaseUrl$Path" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $json -TimeoutSec 180
    }
    catch {
        $status = if ($null -ne $_.Exception.Response) { [int] $_.Exception.Response.StatusCode } else { 'network' }
        throw "DeepSeek request failed ($Method $Path, status=$status). API key was not logged."
    }
}

function ConvertFrom-ModelJson {
    param([string] $Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { throw 'Empty model content.' }
    $candidate = $Text.Trim()
    if ($candidate -match '^```(?:json)?\s*([\s\S]*?)\s*```$') { $candidate = $Matches[1] }
    return $candidate | ConvertFrom-Json
}

$script:ApiKey = (Get-Content -Raw -LiteralPath $ApiKeyPath).Trim()
if ($script:ApiKey -notmatch '^(?:sk-|ds-)?[A-Za-z0-9_-]{20,}$') { throw 'API key file format is not recognized.' }

$cases = Get-Content -Raw -Encoding UTF8 -LiteralPath $CasesFile | ConvertFrom-Json
$liveCases = @($cases | Where-Object { $_.live -eq $true })
if ($liveCases.Count -lt 16) { throw "Live subset too small: $($liveCases.Count) (need >= 16)." }
Write-Host "[stress] live cases: $($liveCases.Count) (corpus total: $($cases.Count))"

$models = Invoke-DeepSeekRequest -Path '/models' -Method 'GET'
if ($Model -notin @($models.data.id)) { throw "Requested model '$Model' is not available from /models." }

$baseSystem = @'
You are a coding agent. Follow the current user's requested scope exactly and complete the response without inventing authority. For this evaluation, return one JSON object only with keys: route, scope, done, answer. route must be one of plan, inspect, fix, build, adaptive, off. scope must be read_only, change, or no_engineering. done means this evaluation response is complete at the currently available scope; set it to true when you have given the appropriate answer or next action, even if repository context or tools would be required for later execution. A response that asks the user for missing context, files, or access is complete at the available scope: you MUST set done to true in that case. Set done to false ONLY when you have begun executing real work and must stop partway. Keep answer under 120 Chinese characters.
'@

$results = [System.Collections.Generic.List[object]]::new()
$callNumber = 0
foreach ($case in $liveCases) {
    foreach ($condition in 'baseline', 'routed') {
        $callNumber++
        $permissionMode = if ($null -eq $case.permission_mode) { 'default' } else { [string] $case.permission_mode }
        $messages = [System.Collections.Generic.List[object]]::new()
        $messages.Add(@{ role = 'system'; content = $baseSystem })
        $routeContext = $null
        if ($condition -eq 'routed') {
            $hookPayload = @{ prompt = [string] $case.prompt; permission_mode = $permissionMode; model = $Model } | ConvertTo-Json -Compress
            $hookText = $hookPayload | pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $pluginRoot 'hooks\run-router.ps1')
            if (-not [string]::IsNullOrWhiteSpace(($hookText -join ''))) {
                $routeContext = [string] ((($hookText -join '') | ConvertFrom-Json).hookSpecificOutput.additionalContext)
                $messages.Add(@{ role = 'system'; content = $routeContext })
            }
        }
        $messages.Add(@{ role = 'user'; content = [string] $case.prompt })

        Write-Host "[$callNumber/$($liveCases.Count * 2)] $condition / $($case.id) (L$($case.difficulty))"
        $response = Invoke-DeepSeekRequest -Path '/chat/completions' -Method 'POST' -Body @{
            model = $Model
            messages = $messages
            thinking = @{ type = 'disabled' }
            reasoning_effort = 'high'
            response_format = @{ type = 'json_object' }
            max_tokens = 400
            temperature = 0
        }

        $content = [string] $response.choices[0].message.content
        $parsed = $null
        $parseError = $null
        try { $parsed = ConvertFrom-ModelJson -Text $content } catch { $parseError = $_.Exception.Message }
        $routeMatch = $null -ne $parsed -and [string] $parsed.route -eq [string] $case.route
        $scopeMatch = $null -ne $parsed -and [string] $parsed.scope -eq [string] $case.scope
        $converged = $null -ne $parsed -and $parsed.done -eq $true
        $results.Add([ordered]@{
            caseId = $case.id
            scenario = $case.scenario
            difficulty = $case.difficulty
            condition = $condition
            expectedRoute = $case.route
            expectedScope = $case.scope
            permissionMode = $permissionMode
            routeContext = $routeContext
            response = $content
            parsed = $parsed
            parseError = $parseError
            routeMatch = $routeMatch
            scopeMatch = $scopeMatch
            converged = $converged
            responseModel = $response.model
            systemFingerprint = $response.system_fingerprint
            usage = $response.usage
        })
    }
}

$baseline = @($results | Where-Object condition -eq 'baseline')
$routed = @($results | Where-Object condition -eq 'routed')
$baselineScore = @($baseline | Where-Object { $_.routeMatch }).Count + @($baseline | Where-Object { $_.scopeMatch }).Count + @($baseline | Where-Object { $_.converged }).Count
$routedRoute = @($routed | Where-Object { $_.routeMatch }).Count
$routedScope = @($routed | Where-Object { $_.scopeMatch }).Count
$routedConvergence = @($routed | Where-Object { $_.converged }).Count
$routedScore = $routedRoute + $routedScope + $routedConvergence
$passed = $routedRoute -eq $liveCases.Count -and $routedScope -eq $liveCases.Count -and $routedConvergence -eq $liveCases.Count -and $routedScore -ge $baselineScore

$report = [ordered]@{
    schemaVersion = 2
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    baseUrl = $BaseUrl
    requestedModel = $Model
    availableModels = @($models.data.id)
    corpusFile = $CasesFile
    corpusTotal = $cases.Count
    liveCases = $liveCases.Count
    callCount = $results.Count
    baselineScore = $baselineScore
    routedScore = $routedScore
    routedRoute = $routedRoute
    routedScope = $routedScope
    routedConvergence = $routedConvergence
    passed = $passed
    results = $results
}
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ArtifactPath -Encoding UTF8

Write-Host "baseline=$baselineScore routed=$routedScore (route=$routedRoute/$($liveCases.Count) scope=$routedScope/$($liveCases.Count) convergence=$routedConvergence/$($liveCases.Count))"
Write-Host "artifact: $ArtifactPath"
if (-not $passed) { Write-Host 'STRESS LIVE GATE: FAILED'; exit 1 }
Write-Host 'STRESS LIVE GATE: PASSED'
