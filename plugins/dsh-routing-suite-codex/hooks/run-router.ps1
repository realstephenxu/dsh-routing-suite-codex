[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$json = [Console]::In.ReadToEnd()
& (Join-Path $PSScriptRoot 'router.ps1') -InputJson $json
