[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$cases = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $PSScriptRoot 'router-cases.json') | ConvertFrom-Json
$router = Join-Path (Split-Path $PSScriptRoot -Parent) 'hooks\router.ps1'
$core = Join-Path (Split-Path $PSScriptRoot -Parent) 'hooks\router-core.ps1'
$rules = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'hooks\routing-rules.json') | ConvertFrom-Json
. $core
Test-RoutingRules -Rules $rules

foreach ($case in $cases) {
    $inputJson = $case.payload | ConvertTo-Json -Depth 6 -Compress
    $actualText = & $router -InputJson $inputJson
    if ($case.route -eq 'off') {
        if (-not [string]::IsNullOrWhiteSpace(($actualText -join ''))) { throw "Expected no output for '$($case.name)', got: $actualText" }
        continue
    }
    $actual = ($actualText -join '') | ConvertFrom-Json
    $context = [string] $actual.hookSpecificOutput.additionalContext
    if ($actual.hookSpecificOutput.hookEventName -ne 'UserPromptSubmit') { throw "Wrong event name for '$($case.name)'" }
    if ($context -notmatch "\[DSH route: $([regex]::Escape($case.route))(?:;|])") { throw "Expected route '$($case.route)' for '$($case.name)', got: $context" }
    if ($context -notmatch 'DSH-CODEX-ROUTER-V1') { throw "Router identity is missing for '$($case.name)'" }
    if ($context -notmatch 'rules v2') { throw "Rules version marker is missing for '$($case.name)'" }
}

$payloadA = @{ prompt = '修复测试'; model = 'codex-one' } | ConvertTo-Json -Compress
$payloadB = @{ prompt = '修复测试'; model = 'codex-two' } | ConvertTo-Json -Compress
$outputA = & $router -InputJson $payloadA
$outputB = & $router -InputJson $payloadB
if (($outputA -join '') -ne ($outputB -join '')) { throw 'Classification changed with the model slug.' }

$pluginRoot = Split-Path $PSScriptRoot -Parent
$previousPluginRoot = $env:PLUGIN_ROOT
try {
$env:PLUGIN_ROOT = $pluginRoot
$hookEntryOutput = '{"prompt":"fix this","permission_mode":"default"}' |
        pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand 'JgAgACgASgBvAGkAbgAtAFAAYQB0AGgAIAAkAGUAbgB2ADoAUABMAFUARwBJAE4AXwBSAE8ATwBUACAAJwBoAG8AbwBrAHMALwByAHUAbgAtAHIAbwB1AHQAZQByAC4AcABzADEAJwApAA=='
    if (($hookEntryOutput -join '') -notmatch '\[DSH route: fix(?:;|])') { throw 'Windows hook command did not route stdin.' }
    $utf8Payload = Join-Path $env:TEMP ('dsh-router-utf8-' + [guid]::NewGuid().ToString('N') + '.json')
    [System.IO.File]::WriteAllText($utf8Payload, '{"prompt":"修复这个示例报错：Error: timeout","permission_mode":"default","model":"any"}', [System.Text.UTF8Encoding]::new($false))
    $utf8EntryOutput = Get-Content -Raw -Encoding UTF8 -LiteralPath $utf8Payload |
        pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand 'JgAgACgASgBvAGkAbgAtAFAAYQB0AGgAIAAkAGUAbgB2ADoAUABMAFUARwBJAE4AXwBSAE8ATwBUACAAJwBoAG8AbwBrAHMALwByAHUAbgAtAHIAbwB1AHQAZQByAC4AcABzADEAJwApAA=='
    Remove-Item -LiteralPath $utf8Payload -Force
    if (($utf8EntryOutput -join '') -notmatch '\[DSH route: fix(?:;|])') { throw 'UTF-8 stdin regression failed: Chinese prompt did not route to fix.' }
}
finally {
    $env:PLUGIN_ROOT = $previousPluginRoot
}

$stress = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $PSScriptRoot 'stress-cases.json') | ConvertFrom-Json
$stressCount = 0
foreach ($testCase in $stress) {
    $prompt = if ($null -eq $testCase.prompt) { '' } else { [string] $testCase.prompt }
    $permission = if ($null -eq $testCase.permission_mode) { '' } else { [string] $testCase.permission_mode }
    $classification = Get-RouteClassification -Rules $rules -Prompt $prompt -PermissionMode $permission
    if ($classification.route -ne $testCase.route) { throw "Stress '$($testCase.id)': expected route '$($testCase.route)', got '$($classification.route)'" }
    if ($classification.complex -ne $testCase.complex) { throw "Stress '$($testCase.id)': expected complex '$($testCase.complex)', got '$($classification.complex)'" }
    $output = New-HookOutput -Rules $rules -Prompt $prompt -PermissionMode $permission
    if ($testCase.route -eq 'off') {
        if ($null -ne $output) { throw "Stress '$($testCase.id)': off must emit no context" }
    } else {
        $context = [string] $output.hookSpecificOutput.additionalContext
        if ($context -notmatch 'DSH-CODEX-ROUTER-V1') { throw "Stress '$($testCase.id)': identity missing" }
        if ($context -notmatch 'rules v2') { throw "Stress '$($testCase.id)': rules version missing" }
    }
    $stressCount++
}

$failOpen = & $router -InputJson 'not-json'
if (-not [string]::IsNullOrWhiteSpace(($failOpen -join ''))) { throw 'Fail-open expected for malformed input.' }

Write-Host "PowerShell router tests passed: $($cases.Count) base + $stressCount stress cases"
