[CmdletBinding()]
param(
    [switch] $SkipVerification,
    [string] $MarketplaceName = 'personal'
)

$ErrorActionPreference = 'Stop'
if (-not $SkipVerification) { & (Join-Path $PSScriptRoot 'Verify.ps1') }

$marketplaces = codex plugin marketplace list 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "Could not list Codex marketplaces: $marketplaces" }
$escapedRoot = [regex]::Escape((Resolve-Path -LiteralPath $PSScriptRoot).Path)
if ($marketplaces -notmatch $escapedRoot) {
    codex plugin marketplace add $PSScriptRoot
    if ($LASTEXITCODE -ne 0) { throw 'Could not add the local marketplace.' }
}

codex plugin add "dsh-routing-suite-codex@$MarketplaceName" --json
if ($LASTEXITCODE -ne 0) { throw 'Could not install the plugin.' }
Write-Host 'Installed dsh-routing-suite-codex.'
Write-Host 'Start a new Codex session, run /hooks, and trust the reviewed UserPromptSubmit hook.'
Write-Host 'After trusting, verify with: codex exec --skip-git-repo-check -s read-only "修复这个示例报错：Error: timeout"'
