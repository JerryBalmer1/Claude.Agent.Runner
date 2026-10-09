# Working in Claude.Agent.Runner

1. Read `.claude/skills/graph-node/SKILL.md` first. It is the contract for everything this repo emits.
2. Read `ontology.yaml` and `docs/design.md`; do not reopen a numbered decision without proposing it in the report.
3. `Invoke-Build` must pass before you report. It needs the Graph.Node checkout beside this one with its `graphnode` binary built, and the Graph checkout for the Report task. If Pester or the binary is missing, say so; do not fake a pass.
4. Shape changes and id prefixes belong to Graph.Node: propose them in the report. Do not apply.
5. Edit and stage only. Stop with a report: files touched, test totals, node and edge counts of the Build layer, proposals, anything not run.
