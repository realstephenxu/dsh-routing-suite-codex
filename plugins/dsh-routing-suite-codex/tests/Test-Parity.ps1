[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$hooks = Split-Path $here -Parent | Join-Path -ChildPath 'hooks'
$core = Join-Path $hooks 'router-core.ps1'
$nodeCli = Join-Path $here 'run-router-cli.mjs'
$rules = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $hooks 'routing-rules.json') | ConvertFrom-Json
. $core

$all = @()
$all += Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $here 'router-cases.json') | ConvertFrom-Json
$all += Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $here 'stress-cases.json') | ConvertFrom-Json

$checked = 0
foreach ($testCase in $all) {
    $payload = if ($null -ne $testCase.payload) { $testCase.payload } else { @{ prompt = $testCase.prompt; permission_mode = $testCase.permission_mode; model = $testCase.model } }
    $prompt = if ($null -eq $payload.prompt) { '' } else { [string] $payload.prompt }
    $permission = if ($null -eq $payload.permission_mode) { '' } else { [string] $payload.permission_mode }

    $psResult = Get-RouteClassification -Rules $rules -Prompt $prompt -PermissionMode $permission
    $nodeResult = ($payload | ConvertTo-Json -Depth 6 -Compress) | node $nodeCli
    if ($LASTEXITCODE -ne 0) { throw "Node CLI failed for '$($testCase.id)'" }
    $nodeParsed = $nodeResult | ConvertFrom-Json

    if ([string] $psResult.route -ne [string] $nodeParsed.route) { throw "Parity route mismatch '$($testCase.id)': PS=$($psResult.route) Node=$($nodeParsed.route)" }
    if ([bool] $psResult.complex -ne [bool] $nodeParsed.complex) { throw "Parity complex mismatch '$($testCase.id)': PS=$($psResult.complex) Node=$($nodeParsed.complex)" }
    if ([string] $psResult.route -ne [string] $testCase.route) { throw "Expected route '$($testCase.route)' for '$($testCase.id)', got '$($psResult.route)'" }
    if ($null -ne $testCase.complex -and [bool] $psResult.complex -ne [bool] $testCase.complex) { throw "Expected complex '$($testCase.complex)' for '$($testCase.id)', got '$($psResult.complex)'" }

    $modelA = @{ prompt = $prompt; permission_mode = $permission; model = 'codex-a' } | ConvertTo-Json -Compress
    $modelB = @{ prompt = $prompt; permission_mode = $permission; model = 'codex-b' } | ConvertTo-Json -Compress
    $psA = Get-RouteClassification -Rules $rules -Prompt $prompt -PermissionMode $permission
    $psB = Get-RouteClassification -Rules $rules -Prompt $prompt -PermissionMode $permission
    $nodeA = ($modelA | node $nodeCli) | ConvertFrom-Json
    $nodeB = ($modelB | node $nodeCli) | ConvertFrom-Json
    if (($psA.route -ne $psB.route) -or ($nodeA.route -ne $nodeB.route)) { throw "Model-slug invariance failed for '$($testCase.id)'" }
    $checked++
}

Write-Host "Parity passed: $checked cases (Node == PowerShell, model-agnostic)"
