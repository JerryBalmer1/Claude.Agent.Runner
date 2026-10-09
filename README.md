> Terms used here (Stream, Driver, Turn, Directed, Layer file; Plan, Run, Step, contains, order, follows) are defined in [ONTOLOGY.md](ONTOLOGY.md).

# Claude.Agent.Runner

A Graph.Node emitter for agent runs: a captured Stream becomes one Plan, one Run and a Step per model turn, Steps chained by `order`, each Directed Step `follows` the `agent:` Rule whose prompt line directed it. Token counts sit on the Steps; totals are sums at query time. Pure PowerShell; depends on Graph.Node, and on Graph for the Report task.

## What is here

| Path | What |
|---|---|
| `ontology.yaml` | Kinds `Plan`, `Run`, `Step`; edge Kinds `contains`, `order`, `follows`. Passes `graphnode validate-ontology` with `[]`. |
| `src/Claude.Agent.Runner/` | PowerShell module: `Export-RunnerGraph`. Vendor parsers under `drivers/` only. |
| `docs/design.md` | Decisions, numbered. |
| `tests/` | Pester, run only as `pwsh -NoProfile -File .\tests\Invoke-Tests.ps1`; `fixtures/three-turns.stream.jsonl` is a captured run (design.md 8). |
| `.claude/skills/` | `graph-node`, `run-report`, `git-guard`, copied read-only from Graph. |
| `.vscode/tasks.json` | Build, Pester, Report. |
| `artifacts/` | Layers and run report, written by `Invoke-Build`; gitignored. |

## Requirements

| Tool | Notes |
|---|---|
| PowerShell 7.4+ | |
| Graph.Node checkout | Beside this repo, at `..\Graph.Node`. Imported at load; the import fails naming the path when it is missing. |
| graphnode binary | Built in that checkout with `Invoke-Build Build`; `Test-Graph -Strict` needs it. |
| Graph checkout | At `C:\__Code\Graph`, for `New-GraphRunReport` (Report task) and the copied-skill checks. |
| Pester 5.5+, InvokeBuild | `Install-Module Pester, InvokeBuild -Scope CurrentUser` |

## Build

```powershell
Invoke-Build            # Build, Pester, Report
Invoke-Build Build      # validate the ontology and write a layer of the fixture only
```

## Use from PowerShell

```powershell
Import-Module .\src\Claude.Agent.Runner\Claude.Agent.Runner.psd1
claude -p "..." --output-format stream-json --verbose > .\my-plan.stream.jsonl
$g = Export-RunnerGraph -InputPath .\my-plan.stream.jsonl -LayersPath .\artifacts\layers
$g.counts.byKind                                   # Plan 1, Run 1, Step n
($g.nodes | ? kind -eq Step).properties.tokensOutput | Measure-Object -Sum   # a total, at query time
```

`Export-RunnerGraph -InputPath <stream> [-Driver <name>] [-LayersPath <dir>] [-Strict]`. `-Strict` throws when a `follows` edge dangles, which every one does until this layer is merged with Graph.Emitter.Agent's (design.md 6).

## Status

0.1.0, scaffold. Next: Graph.Node registering `runner:` and `agent:`.
