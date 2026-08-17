[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$pluginRoot = Join-Path $PSScriptRoot 'plugins\dsh-routing-suite-codex'
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $pluginRoot '.codex-plugin\plugin.json') | ConvertFrom-Json
$hooks = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $pluginRoot 'hooks\hooks.json') | ConvertFrom-Json
$marketplace = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $PSScriptRoot '.agents\plugins\marketplace.json') | ConvertFrom-Json
$rules = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $pluginRoot 'hooks\routing-rules.json') | ConvertFrom-Json
$core = Join-Path $pluginRoot 'hooks\router-core.ps1'

foreach ($command in 'pwsh', 'node', 'codex') {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { throw "Required command not found: $command" }
}
if ($manifest.name -ne 'dsh-routing-suite-codex') { throw 'Unexpected plugin name.' }
if ($manifest.skills -ne './skills/') { throw 'Skill path is missing.' }
if ($null -eq $hooks.hooks.UserPromptSubmit) { throw 'UserPromptSubmit hook is missing.' }
if ($manifest.version -notmatch '^0\.2\.0') { throw "Unexpected plugin version: $($manifest.version)" }
if ($rules.version -ne 2) { throw "Unexpected rules version: $($rules.version)" }
if ($marketplace.name -ne 'personal' -or $null -eq $marketplace.plugins) { throw 'Marketplace manifest is invalid.' }

$decodedEntry = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($hooks.hooks.UserPromptSubmit[0].hooks[0].commandWindows.Split(' ')[-1]))
if ($decodedEntry -notmatch 'run-router\.ps1') { throw 'Windows hook entry does not point at run-router.ps1.' }

. $core
Test-RoutingRules -Rules $rules

& node (Join-Path $pluginRoot 'tests\test-router.mjs')
if ($LASTEXITCODE -ne 0) { throw 'Node router tests failed.' }
& pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $pluginRoot 'tests\Test-Router.ps1')
if ($LASTEXITCODE -ne 0) { throw 'PowerShell router tests failed.' }
& pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $pluginRoot 'tests\Test-Parity.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Parity tests failed.' }

Write-Host "Verified project: $PSScriptRoot"
Write-Host "Plugin version: $($manifest.version) | rules v$($rules.version)"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "Node: $(node --version)"
Write-Host "Codex: $(codex --version)"
