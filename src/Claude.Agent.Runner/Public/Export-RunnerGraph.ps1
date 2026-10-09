function Export-RunnerGraph {
    <#
    .SYNOPSIS
        Reads one captured agent run and returns one Graph.Node envelope: a Plan that contains the Run, the Run that contains its Steps, order edges between consecutive Steps, and follows edges from a Step onto the agent: Rule that directed it.
    .DESCRIPTION
        -Driver names a folder under the module's drivers/ that turns the vendor's stream into Steps (design.md 4); when
        it is not given, drivers/drivers.psd1 names the default. The Plan is 'runner:<plan>', <plan> the -InputPath file
        name up to its first '.'; the Run is '<plan id>/<session id>'; Step n is '<run id>/step-<n>', n from 1 in stream
        order (design.md 1). Token counts are stored per Step only; Run and Plan totals are sums at query time (design.md 3).
        The envelope's layer is the Run's first stream timestamp (whole seconds), else now; its root is the Plan.

        A follows edge ends on an agent: id that Graph.Emitter.Agent emits, so it dangles in this envelope. -Strict
        throws when any follows edge dangles. Without it, those edges are kept and the dangling-edge errors Graph.Node
        reports for them (agent: is not registered there yet) are the only problems tolerated (design.md 6).

        With -LayersPath the envelope is also written to <LayersPath>/<layer stamp, ':' as '-'>.graph.json with
        ontology.yaml copied beside it when absent, and the file is checked with Test-Graph -Strict, which throws on any
        other error; the graphnode binary must be built in the Graph.Node checkout.
    .EXAMPLE
        Export-RunnerGraph -InputPath .\tests\fixtures\three-turns.stream.jsonl
    .EXAMPLE
        Export-RunnerGraph -InputPath .\run.stream.jsonl -LayersPath .\artifacts\layers
    #>
    [CmdletBinding()]
    [OutputType('GraphNode.Envelope')]
    param(
        [Parameter(Mandatory, Position = 0)] [string] $InputPath,
        [string] $Driver,
        [string] $LayersPath,
        [switch] $Strict
    )
    if (-not $Driver) { $Driver = $script:DefaultDriver }
    $file = Get-Item -LiteralPath $InputPath -ErrorAction Stop
    if ($file -isnot [IO.FileInfo]) { throw "'$InputPath' is not a file" }
    $run = Invoke-RunnerDriver -Name $Driver -Path $file.FullName

    $planName = $file.Name.Split('.')[0]
    $planId = $script:IdPrefix + $planName
    $runId = "$planId/$($run.SessionId)"
    $source = @{ tool = $script:ModuleName; path = $file.FullName }

    $nodes = [System.Collections.Generic.List[object]]::new()
    $edges = [System.Collections.Generic.List[object]]::new()
    $nodes.Add((New-GraphNode -Id $planId -Kind Plan -Name $planName -Properties @{ name = $planName }))
    $runProperties = @{ sessionId = [string] $run.SessionId; driver = $Driver }
    if ($run.Model) { $runProperties.model = [string] $run.Model }
    if ($run.StartedAt) { $runProperties.startedAt = [string] $run.StartedAt }
    $nodes.Add((New-GraphNode -Id $runId -Kind Run -Name ([string] $run.SessionId) -Properties $runProperties -Source $source))
    $edges.Add((New-GraphEdge -From $planId -To $runId -Kind contains))

    $n = 0
    $previous = $null
    foreach ($step in @($run.Steps)) {
        $n++
        $stepId = "$runId/step-$n"
        $properties = @{ index = $n; metered = [bool] ($step.Metered ?? $true); tools = (@($step.Tools) -join ', ') }
        foreach ($p in 'MessageId', 'Model', 'StartedAt', 'Text') {
            if ($step.$p) { $properties[$p.Substring(0, 1).ToLowerInvariant() + $p.Substring(1)] = [string] $step.$p }
        }
        foreach ($p in 'TokensInput', 'TokensOutput', 'TokensCache') {
            if ($null -ne $step.$p) { $properties[$p.Substring(0, 1).ToLowerInvariant() + $p.Substring(1)] = [int] $step.$p }
        }
        $name = if (@($step.Tools).Count) { "$n $(@($step.Tools) -join ', ')" } else { "$n text" }
        $nodes.Add((New-GraphNode -Id $stepId -Kind Step -Name $name -Properties $properties -Source $source))
        $edges.Add((New-GraphEdge -From $runId -To $stepId -Kind contains))
        if ($previous) { $edges.Add((New-GraphEdge -From $previous -To $stepId -Kind order)) }
        foreach ($rule in @($step.Follows)) { $edges.Add((New-GraphEdge -From $stepId -To $rule -Kind follows)) }
        $previous = $stepId
    }

    $graph = New-GraphEnvelope -Module $script:ModuleName -Version $script:Version -Layer ($run.StartedAt ?? [datetime]::UtcNow) `
        -Ontology 'ontology.yaml' -Root $planId -Nodes $nodes.ToArray() -Edges $edges.ToArray()

    $ids = [System.Collections.Generic.HashSet[string]]::new([string[]] @($graph.nodes.id))
    $dangling = @($graph.edges | Where-Object { $_.kind -eq 'follows' -and -not $ids.Contains($_.to) })
    if ($Strict -and $dangling) {
        throw ("{0} dangling follows edge(s): {1}" -f $dangling.Count, (@($dangling.id) -join '; '))
    }

    if ($LayersPath) {
        $dir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LayersPath)
        $out = Join-Path $dir "$($graph.layer -replace ':', '-').graph.json"
        # -Force: Export-Graph would refuse the dangling follows edges, which are checked below with every other problem.
        Export-Graph $graph -Path $out -Force | Out-Null
        $ontology = Join-Path $dir 'ontology.yaml'
        if (-not (Test-Path -LiteralPath $ontology)) { Copy-Item -LiteralPath $script:OntologyPath -Destination $ontology }
        $tolerated = @(for ($i = 0; $i -lt @($graph.edges).Count; $i++) { if ($graph.edges[$i] -in $dangling) { "/edges/$i" } })
        $result = Test-Graph -Path $out -Strict
        $errors = @($result.Problems | Where-Object { $_.Severity -eq 'error' -and -not ($_.Code -eq 'dangling-edge' -and $_.Path -in $tolerated) })
        if ($errors) {
            throw ("{0} failed Test-Graph -Strict; {1} problem(s): {2}" -f $out, $errors.Count, (($errors | ForEach-Object { "$($_.Code) $($_.Path): $($_.Message)" }) -join '; '))
        }
    }
    $graph
}
