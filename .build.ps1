#Requires -Version 7.4
# Invoke-Build script. Run: Invoke-Build            (Build, Pester, Report)
#                           Invoke-Build Build      (validate the ontology and write a layer of the fixture only)
param()

$repo     = $PSScriptRoot
$manifest = Join-Path $repo 'src' 'Claude.Agent.Runner' 'Claude.Agent.Runner.psd1'
$fixture  = Join-Path $repo 'tests' 'fixtures' 'three-turns.stream.jsonl'
$layers   = Join-Path $repo 'artifacts' 'layers'
$results  = Join-Path $repo 'tests' 'testResults.xml'
$started  = [datetime]::UtcNow
$ran      = [System.Collections.Generic.List[string]]::new()   # tasks that finished in this invocation, for Report

# The manifest loads, the ontology validates with [], and a layer of the fixture passes Test-Graph -Strict but for the
# dangling follows edges (design.md 6).
task Build {
    Test-ModuleManifest -Path $manifest | Out-Null
    Import-Module $manifest -Force
    $bin = Join-Path (Split-Path (Get-Module GraphNode).Path) 'bin' $(if ($IsWindows) { 'win-x64\graphnode.exe' } else { 'linux-x64/graphnode' })
    $problems = (& $bin validate-ontology (Join-Path $repo 'ontology.yaml')) -join ''
    if ($LASTEXITCODE -ne 0 -or $problems.Trim() -ne '[]') { throw "ontology.yaml: $problems" }
    $graph = Export-RunnerGraph -InputPath $fixture -LayersPath $layers
    Write-Build Green ("{0}: {1} nodes ({2} Plan, {3} Run, {4} Step), {5} edges ({6} contains, {7} order, {8} follows)" -f $layers, $graph.counts.nodes,
        $graph.counts.byKind.Plan, $graph.counts.byKind.Run, $graph.counts.byKind.Step, $graph.counts.edges,
        @($graph.edges | Where-Object kind -eq 'contains').Count, @($graph.edges | Where-Object kind -eq 'order').Count,
        @($graph.edges | Where-Object kind -eq 'follows').Count)
    $ran.Add('Build')
}

task Pester {
    $script = Join-Path $repo 'tests' 'Invoke-Tests.ps1'
    & pwsh -NoProfile -File $script
    if ($LASTEXITCODE -ne 0) { throw "Pester failed: $LASTEXITCODE test(s)" }
    $ran.Add('Pester')
}

# The build's facts as a run report (run-report skill): Graph's New-GraphRunReport -Repo writes this repo's
# artifacts\run-report.json and nowhere else, never Graph's artifacts. A failed task stops the chain before Report, so Report sees only tasks that passed;
# Build or Pester not run in this invocation is a NotRun and the result is not-run, never a stale pass.
task Report {
    Import-Module C:\__Code\Graph\src\Graph\Graph.psd1 -Force
    $facts = @{ Repo = $repo; Task = "Invoke-Build ($((@($ran) + 'Report') -join ', '))"; StartedAt = $started }
    $notRun = @(foreach ($t in 'Build', 'Pester') { if ($t -notin $ran) { @{ text = $t; reason = 'not run in this Invoke-Build invocation' } } })
    $facts.BuildResult = if ($notRun) { 'not-run' } else { 'succeeded' }
    if ($notRun) { $facts.NotRun = $notRun }
    if ('Pester' -in $ran) {
        $r = ([xml](Get-Content -LiteralPath $results -Raw))['test-results']
        $skipped = [int]$r.skipped + [int]$r.'not-run' + [int]$r.ignored + [int]$r.inconclusive
        $failed = [int]$r.failures + [int]$r.errors
        $facts.PesterPassed = [int]$r.total - $failed - $skipped
        $facts.PesterFailed = $failed
        $facts.PesterSkipped = $skipped
    }
    $files = New-GraphRunReport @facts
    Write-Build Green "wrote $(@($files).FullName -join ', ')"
}

task . Build, Pester, Report
