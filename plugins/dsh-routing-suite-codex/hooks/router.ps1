[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline)]
    [AllowEmptyString()]
    [string] $InputJson
)

begin {
    $ErrorActionPreference = 'Stop'
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
    $inputChunks = [System.Collections.Generic.List[string]]::new()
    . (Join-Path $PSScriptRoot 'router-core.ps1')
}

process {
    $inputChunks.Add($InputJson)
}

end {
    try {
        $payload = ($inputChunks -join [Environment]::NewLine) | ConvertFrom-Json
        $rules = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $PSScriptRoot 'routing-rules.json') | ConvertFrom-Json
        Test-RoutingRules -Rules $rules
        $output = New-HookOutput -Rules $rules -Prompt ([string] $payload.prompt) -PermissionMode ([string] $payload.permission_mode)
        if ($output) { $output | ConvertTo-Json -Depth 4 -Compress }
    }
    catch {
        # Fail open: malformed input or local configuration must never block Codex.
        if ($env:DSH_DEBUG) {
            Add-Content -LiteralPath $env:DSH_DEBUG -Value ("[router.ps1] " + (Get-Date -Format o) + " " + $_.Exception.Message) -Encoding UTF8
        }
        exit 0
    }
}
