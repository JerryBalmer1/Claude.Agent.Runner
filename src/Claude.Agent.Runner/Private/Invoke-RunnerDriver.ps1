function Invoke-RunnerDriver {
    <#
        Runs drivers/<Name>/driver.ps1 on a captured stream and returns its record (design.md 4):
        @{ SessionId; Model; StartedAt; Steps = @(@{ MessageId; Model; Tools; Text; TokensInput; TokensOutput; TokensCache; Metered; Follows }) }
        Throws on an unknown driver name, naming the drivers that exist, and on a record without a SessionId.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Path
    )
    $known = @(Get-ChildItem -LiteralPath $script:DriversRoot -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'driver.ps1') } | ForEach-Object Name)
    if ($Name -cnotmatch '^[a-z0-9-]+$' -or $Name -notin $known) {
        throw "unknown driver '$Name'; drivers here: $($known -join ', ')"
    }
    $record = & (Join-Path $script:DriversRoot $Name 'driver.ps1') -Path $Path
    if (-not $record -or -not $record.SessionId) { throw "driver '$Name' found no session in $Path" }
    $record
}
