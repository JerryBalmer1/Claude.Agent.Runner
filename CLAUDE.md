# Claude.Agent.Runner — agent rules

> Every task in this repo ends by writing `artifacts/run-report.json` per `.claude/skills/run-report/SKILL.md`, after the prose report, and pasting its contents at the end of the report. That skill is copied read-only from Graph (`C:\__Code\Graph\.claude\skills\run-report`); recopy it when the `version:` of Graph's committed copy changes.

> Everything this repo emits follows `.claude/skills/graph-node/SKILL.md`, copied read-only from Graph (`C:\__Code\Graph\.claude\skills\graph-node`); recopy it when the `version:` of Graph's committed copy changes (Pester compares version and full text). If the shape does not fit, propose the change to Graph.Node in the report; do not work around it here.

> Edit and stage only. `.claude/settings.json` runs `.claude/skills/git-guard/hook.ps1` before every Bash and PowerShell call and refuses commit, push, tag and amend. git-guard is copied read-only from Graph, with its own `version:`.

## Commands

- Never use `pwsh -Command { }`. Run multi-line PowerShell by writing it to a temp `.ps1` and `pwsh -NoProfile -File`.
- Only run Pester as `pwsh -NoProfile -File .\tests\Invoke-Tests.ps1`.
- Never commit, push or tag.

## Graph.Node

- Never copy Graph.Node's files into this repo; the graph-node skill comes from Graph.
- The module imports `..\Graph.Node\src\*\*.psd1` (today `C:\__Code\Graph.Node\src\GraphNode\GraphNode.psd1`) at load and fails with a message naming the path when it is missing. `Test-Graph -Strict` needs the `graphnode` binary built there (`Invoke-Build Build` in Graph.Node).
- Do not edit Graph.Node. The `runner:` prefix is proposed in `docs/design.md`; Graph.Node registers it.

## Layout

```
ontology.yaml                         Kinds Plan, Run, Step; edge Kinds contains, order, follows
src/Claude.Agent.Runner/              PowerShell module (Public/, Private/, drivers/)
src/Claude.Agent.Runner/drivers/      one folder per vendor, driver.ps1 each; drivers.psd1 names the default
docs/                                 design.md (numbered entries)
tests/                                Pester; fixtures/three-turns.stream.jsonl is a captured run
artifacts/                            layers/ and run-report.json, written by Invoke-Build; gitignored
.build.ps1                            Invoke-Build: Build, Pester, Report (default)
.vscode/tasks.json                    Build, Pester, Report
```

## Rules

- Never name a vendor outside `src/Claude.Agent.Runner/drivers/`. The module name is the one exception; Pester greps `Public/`, `Private/` and the manifest (design.md 4).
- Always build node ids from the rules in `ontology.yaml`: `runner:<plan>`, `<plan id>/<session id>`, `<run id>/step-<n>` (design.md 1).
- Never store a token total on a Run or Plan; totals are sums over Steps at query time (design.md 3).
- Always point `follows` at Graph.Emitter.Agent's `agent:` Rule ids. Never issue `agent:` ids for this repo's own nodes.
- Must declare a new Kind or edge Kind in `ontology.yaml` in the same task, and `graphnode validate-ontology ontology.yaml` must return `[]`.
- Only build edges with `New-GraphEdge` and envelopes with `New-GraphEnvelope`. Never build an edge id or counts by hand.
- Every exported function has one file under `src/Claude.Agent.Runner/Public/` and a `tests/<Verb-Noun>.Tests.ps1`.
- README and ONTOLOGY.md are the two doors; each links the other on its first line.
