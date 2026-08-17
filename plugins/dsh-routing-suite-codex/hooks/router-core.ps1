[CmdletBinding()]
param()

function Get-MatchCount {
    param([Parameter(Mandatory)] [string] $Text, [Parameter(Mandatory)] [string] $Pattern)
    $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    return [regex]::Matches($Text, $Pattern, $options).Count
}

function Test-RoutingRules {
    param([Parameter(Mandatory)] [object] $Rules)
    foreach ($signal in @('greeting', 'planExplicit', 'inspect', 'fix', 'build', 'complex', 'noChange')) {
        if ($null -eq $Rules.signals.PSObject.Properties[$signal]) { throw "Missing signal: $signal" }
        [void] [regex]::new([string] $Rules.signals.PSObject.Properties[$signal].Value)
    }
    foreach ($key in @('prefix', 'plan', 'inspect', 'fix', 'build', 'adaptive', 'simpleTail', 'complexTail')) {
        if ($null -eq $Rules.guidance.PSObject.Properties[$key]) { throw "Missing guidance: $key" }
    }
    if ($null -eq $Rules.complexity.minLength) { throw 'Missing complexity.minLength' }
    if ($null -eq $Rules.version) { throw 'Missing rules version' }
}

function Get-RouteClassification {
    param(
        [Parameter(Mandatory)] [object] $Rules,
        [string] $Prompt = '',
        [string] $PermissionMode = ''
    )
    $prompt = if ($null -eq $Prompt) { '' } else { ([string] $Prompt).Trim() }
    $permissionMode = if ($null -eq $PermissionMode) { '' } else { ([string] $PermissionMode).ToLowerInvariant() }
    $route = 'off'
    $complex = $false

    if ($prompt.Length -gt 0) {
        if ($permissionMode -eq 'plan') { $route = 'plan'; $complex = $true }
        elseif ($prompt -match $Rules.signals.greeting) { $route = 'off' }
        elseif ($prompt -match $Rules.signals.planExplicit) { $route = 'plan'; $complex = $true }
        else {
            $fixScore = Get-MatchCount -Text $prompt -Pattern $Rules.signals.fix
            $buildScore = Get-MatchCount -Text $prompt -Pattern $Rules.signals.build
            $inspectScore = Get-MatchCount -Text $prompt -Pattern $Rules.signals.inspect
            if ($prompt -match $Rules.signals.noChange) { $fixScore = 0; $buildScore = 0 }
            if ($fixScore -gt 0 -and $buildScore -gt 0) { $route = 'adaptive' }
            elseif ($fixScore -gt 0) { $route = 'fix' }
            elseif ($buildScore -gt 0) { $route = 'build' }
            elseif ($inspectScore -gt 0) { $route = 'inspect' }
            if ($route -ne 'off') {
                $complex = $prompt.Length -ge [int] $Rules.complexity.minLength -or ($prompt -match $Rules.signals.complex)
            }
        }
    }
    return [pscustomobject] @{ route = $route; complex = $complex }
}

function New-HookOutput {
    param(
        [Parameter(Mandatory)] [object] $Rules,
        [string] $Prompt = '',
        [string] $PermissionMode = ''
    )
    $classification = Get-RouteClassification -Rules $Rules -Prompt $Prompt -PermissionMode $PermissionMode
    if ($classification.route -eq 'off') { return $null }
    $routeGuidance = $Rules.guidance.PSObject.Properties[$classification.route].Value
    $tail = if ($classification.complex) { $Rules.guidance.complexTail } else { $Rules.guidance.simpleTail }
    $marker = "[DSH route: $($classification.route); rules v$($Rules.version)]"
    $additionalContext = @($marker, $Rules.guidance.prefix, $routeGuidance, $tail) -join ' '
    return [pscustomobject] @{
        hookSpecificOutput = [pscustomobject] @{
            hookEventName = 'UserPromptSubmit'
            additionalContext = $additionalContext
        }
    }
}
