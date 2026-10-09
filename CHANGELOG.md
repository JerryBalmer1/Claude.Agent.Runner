# Changelog

## 0.1.1 — 2026-10-08

- 0.1.1: git-guard hook; run-report 0.2.2; graph-node 0.2.1
- Skills git-guard 0.1.0 (line endings only; content was already 0.1.0), run-report 0.2.2 and graph-node 0.2.1 recopied from Graph HEAD; `.claude/settings.json` already held git-guard's PreToolUse entry. `tests/Module.Tests.ps1` checks each copy's version and full text against `git show HEAD:` in Graph; `tests/GitGuard.Tests.ps1` the hook's exit codes.
- Copied-skill tests now compare every file in each skill folder, not only SKILL.md; GitGuard tests add gh pr merge. Report task comment and VS Code task detail: New-GraphRunReport -Repo writes this repo's artifacts only, never Graph's.

## 0.1.0 — 2026-10-09

- Scaffold, laid out as Graph.Emitter.FileSystem. PowerShell module `Claude.Agent.Runner`: `Export-RunnerGraph` (`-InputPath`, `-Driver`, `-LayersPath`, `-Strict`).
- `ontology.yaml` 0.1.0: Kinds Plan (hexagon), Run (square), Step (circle), with colours and `idRule`; Step's optional `tokensInput`, `tokensOutput`, `tokensCache`, `metered` (true when absent); edge Kinds `contains` (Plan → Run → Step), `order` (Step → Step), `follows` (Step → Graph.Emitter.Agent's Rule). `graphnode validate-ontology` returns `[]`. Token totals are not stored (design.md 3).
- Id prefix `runner:` proposed in design.md 1; Graph.Node registers it. Pester asserts it is still unregistered.
- `drivers/claude/` reads `claude -p --output-format stream-json` into Steps, one per assistant message id (design.md 5). Nothing outside `drivers/` names a vendor; Pester greps `Public/`, `Private/` and the manifest (design.md 4).
- `follows` from the `agent:` Rule id a Step's text names; Graph.Node's dangling-edge errors on those edges are tolerated, `-Strict` throws on them (design.md 6).
- Fixture `tests/fixtures/three-turns.stream.jsonl`, a trimmed real capture: three turns with usage, two directed (design.md 8).
- Invoke-Build tasks Build, Pester, Report; default `Build, Pester, Report`; VS Code tasks for each. No Up task.
- Skills: `run-report`, `graph-node`, `git-guard` copied from Graph's committed copies, unchanged; git-guard's fragment is `.claude/settings.json`. Pester checks each one's version and full text against `git show HEAD:` in Graph, and git-guard's six exit codes.
- design.md 1–8; ONTOLOGY.md; README; CLAUDE.md; AGENTS.md.
