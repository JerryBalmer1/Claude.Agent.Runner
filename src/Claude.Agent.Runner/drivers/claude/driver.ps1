#Requires -Version 7.4
<#
    Driver 'claude': reads the output of `claude -p --output-format stream-json --verbose` (one JSON object per line)
    and returns the runner's driver record (design.md 4):

        @{ SessionId; Model; StartedAt; Steps = @(@{ MessageId; Model; StartedAt; Tools; Text; TokensInput; TokensOutput; TokensCache; Metered; Follows }) }

    One Step per assistant message id, in the order the ids first appear. The CLI writes one line per content block
    (thinking, text, tool_use), each repeating the message's id and usage; the lines of one id are one Step, and its
    usage is taken from the last of them. TokensCache is cache_read_input_tokens + cache_creation_input_tokens.
    The stream's per-message output_tokens is the count when the line was written, not the message's final count
    (design.md 5). Follows lists the agent: Rule ids (agent:<file>#<slug>/rule-<n>) the message's text names, distinct,
    in order. Metered is true: the CLI bills or counts every message it streams. Lines that are not JSON are skipped.
#>
[CmdletBinding()]
param([Parameter(Mandatory)] [string] $Path)

Set-StrictMode -Version Latest
$rulePattern = 'agent:[^\s`''"\[\]()<>]+/rule-\d+'

# A stream timestamp as a whole-second UTC stamp ending Z; $null when absent or unreadable.
function ConvertTo-Stamp([object] $Value) {
    if (-not $Value) { return $null }
    $at = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse([string] $Value, [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref] $at)) { return $null }
    $at.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [cultureinfo]::InvariantCulture)
}

# A property of a parsed line, or $null when the line does not have it (StrictMode forbids reading a missing one).
function Get-Field([object] $Object, [string] $Name) {
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { $Object.$Name } else { $null }
}

$sessionId = $null
$model = $null
$order = [System.Collections.Generic.List[string]]::new()
$byId = @{}

foreach ($line in [IO.File]::ReadLines((Resolve-Path -LiteralPath $Path).ProviderPath)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try { $entry = ConvertFrom-Json -InputObject $line -ErrorAction Stop } catch { continue }
    $type = Get-Field $entry 'type'
    if (-not $sessionId) { $sessionId = Get-Field $entry 'session_id' }
    if ($type -eq 'system' -and (Get-Field $entry 'subtype') -eq 'init') {
        $sessionId = Get-Field $entry 'session_id'
        $model = Get-Field $entry 'model'
        continue
    }
    if ($type -ne 'assistant') { continue }
    $message = Get-Field $entry 'message'
    $id = Get-Field $message 'id'
    if (-not $id) { continue }
    if (-not $byId.ContainsKey($id)) {
        $order.Add($id)
        $byId[$id] = [ordered]@{
            MessageId = $id; Model = (Get-Field $message 'model'); StartedAt = (ConvertTo-Stamp (Get-Field $entry 'timestamp'))
            Tools = [System.Collections.Generic.List[string]]::new(); Text = [System.Collections.Generic.List[string]]::new()
            TokensInput = $null; TokensOutput = $null; TokensCache = $null; Metered = $true
            Follows = [System.Collections.Generic.List[string]]::new()
        }
    }
    $step = $byId[$id]
    foreach ($block in @(Get-Field $message 'content')) {
        switch (Get-Field $block 'type') {
            'text' {
                $text = [string](Get-Field $block 'text')
                if ($text) { $step.Text.Add($text) }
                foreach ($m in [regex]::Matches($text, $rulePattern)) { if ($m.Value -notin $step.Follows) { $step.Follows.Add($m.Value) } }
            }
            'tool_use' { $step.Tools.Add([string](Get-Field $block 'name')) }
        }
    }
    $usage = Get-Field $message 'usage'
    if ($usage) {
        $step.TokensInput = [int](Get-Field $usage 'input_tokens')
        $step.TokensOutput = [int](Get-Field $usage 'output_tokens')
        $step.TokensCache = [int](Get-Field $usage 'cache_read_input_tokens') + [int](Get-Field $usage 'cache_creation_input_tokens')
    }
}

if (-not $sessionId) { return }
$steps = @(foreach ($id in $order) {
        $s = $byId[$id]
        [pscustomobject]@{
            MessageId = $s.MessageId; Model = $s.Model; StartedAt = $s.StartedAt
            Tools = $s.Tools.ToArray(); Text = ($s.Text -join "`n")
            TokensInput = $s.TokensInput; TokensOutput = $s.TokensOutput; TokensCache = $s.TokensCache; Metered = $s.Metered
            Follows = $s.Follows.ToArray()
        }
    })
[pscustomobject]@{
    SessionId = $sessionId
    Model     = $model ?? (@($steps | ForEach-Object Model | Where-Object { $_ }) | Select-Object -First 1)
    StartedAt = @($steps | ForEach-Object StartedAt | Where-Object { $_ }) | Select-Object -First 1
    Steps     = $steps
}
