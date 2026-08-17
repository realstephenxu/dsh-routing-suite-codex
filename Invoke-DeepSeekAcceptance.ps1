[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ApiKeyPath,
    [string] $Model = 'deepseek-v4-flash',
    [string] $BaseUrl = 'https://api.deepseek.com'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

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

$pluginRoot = Join-Path $PSScriptRoot 'plugins\dsh-routing-suite-codex'
$router = Join-Path $pluginRoot 'hooks\router.ps1'
$cases = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $PSScriptRoot 'acceptance\cases.json') | ConvertFrom-Json
$models = Invoke-DeepSeekRequest -Path '/models' -Method 'GET'
if ($Model -notin @($models.data.id)) { throw "Requested model '$Model' is not available from /models." }

$baseSystem = @'
You are a coding agent. Follow the current user's requested scope exactly and complete the response without inventing authority. For this evaluation, return one JSON object only with keys: route, scope, done, answer. route must be one of plan, inspect, fix, build, adaptive, off. scope must be read_only, change, or no_engineering. done means this evaluation response is complete at the currently available scope; set it to true when you have given the appropriate answer or next action, even if repository context or tools would be required for later execution. Keep answer under 120 Chinese characters.
'@

$results = [System.Collections.Generic.List[object]]::new()
$callNumber = 0
foreach ($case in $cases) {
    foreach ($condition in 'baseline', 'routed') {
        $callNumber++
        $permissionMode = if ($null -eq $case.permission_mode) { 'default' } else { [string] $case.permission_mode }
        $messages = [System.Collections.Generic.List[object]]::new()
        $messages.Add(@{ role = 'system'; content = $baseSystem })
        $routeContext = $null
        if ($condition -eq 'routed') {
            $hookPayload = @{ prompt = [string] $case.prompt; permission_mode = $permissionMode; model = $Model } | ConvertTo-Json -Compress
            $hookText = & $router -InputJson $hookPayload
            if (-not [string]::IsNullOrWhiteSpace(($hookText -join ''))) {
                $routeContext = [string] ((($hookText -join '') | ConvertFrom-Json).hookSpecificOutput.additionalContext)
                $messages.Add(@{ role = 'system'; content = $routeContext })
            }
        }
        $messages.Add(@{ role = 'user'; content = [string] $case.prompt })

        Write-Host "[$callNumber/32] $condition / $($case.id)"
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
$passed = $routedRoute -eq $cases.Count -and $routedScope -eq $cases.Count -and $routedConvergence -eq $cases.Count -and $routedScore -ge $baselineScore

$report = [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    baseUrl = $BaseUrl
    requestedModel = $Model
    availableModels = @($models.data.id)
    callCount = $results.Count
    criteria = [ordered]@{
        routedRouteRequired = $cases.Count
        routedScopeRequired = $cases.Count
        routedConvergenceRequired = $cases.Count
        noRegressionAgainstBaseline = $true
    }
    summary = [ordered]@{
        baselineScore = $baselineScore
        routedScore = $routedScore
        routedRoute = "$routedRoute/$($cases.Count)"
        routedScope = "$routedScope/$($cases.Count)"
        routedConvergence = "$routedConvergence/$($cases.Count)"
        passed = $passed
    }
    cases = $cases
    results = $results
}

$artifactDir = Join-Path $PSScriptRoot 'artifacts'
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$artifactPath = Join-Path $artifactDir "deepseek-acceptance-$stamp.json"
$report | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 -LiteralPath $artifactPath
$script:ApiKey = $null

Write-Host ($report.summary | ConvertTo-Json -Compress)
Write-Host "Artifact: $artifactPath"
if (-not $passed) { throw 'DeepSeek live acceptance failed. Inspect the sanitized artifact.' }
