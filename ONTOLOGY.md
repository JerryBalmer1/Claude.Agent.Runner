> This file defines the terms and Kinds this emitter writes. [README.md](README.md) says how to use the module.

# Claude.Agent.Runner ontology

The base terms (Node, Edge, Envelope, Kind, Layer, Ontology) are Graph.Node's; see `.claude/skills/graph-node/SKILL.md` and Graph.Node's ONTOLOGY.md. This file adds what this emitter means by them. The declaration itself is [ontology.yaml](ontology.yaml).

## Terminology

| Term | Meaning |
|---|---|
| Stream | A captured run, one JSON object per line, given as `-InputPath`. |
| Driver | `drivers/<name>/driver.ps1` under the module: reads one vendor's Stream into Steps. The only place a vendor is named (design.md 4). |
| Turn | One assistant message of the Stream, however many lines it is written as (design.md 5). |
| Directed | A Turn whose text names an `agent:` Rule id, the id of the prompt line it carries out. Otherwise improvised (design.md 6). |
| Layer file | `<layers>/<layer stamp with : as ->.graph.json`, written by `Export-RunnerGraph -LayersPath` with `ontology.yaml` beside it. |

## Kinds

| Kind | Id | Properties | Edges |
|---|---|---|---|
| Plan (hexagon) | `runner:<plan>`, the Stream's file name up to its first `.` | `name` | `contains` → Run |
| Run (square) | `<Plan id>/<session id>` | `sessionId`, `driver`, `model`, `startedAt`; Stream path in `source[0].path` | ← `contains` from one Plan; `contains` → Step |
| Step (circle) | `<Run id>/step-<n>` | `index`, `tools`; optional `tokensInput`, `tokensOutput`, `tokensCache`, `metered` (true when absent); `messageId`, `model`, `startedAt`, `text` | ← `contains` from one Run; `order` → next Step; `follows` → `agent:` Rule when Directed |

| Edge Kind | From | To |
|---|---|---|
| `contains` | Plan, Run | Run, Step (Plan → Run and Run → Step only) |
| `order` | Step | the next Step in the same Run |
| `follows` | Step | Rule: Graph.Emitter.Agent's Kind, by its `agent:` id; absent when the Step was improvised (design.md 6) |

## Totals

Token totals are not stored. A Run's input, output or cache total is the sum of that property over the Steps it contains, and a Plan's the sum over its Runs' Steps, computed at query time (design.md 3). A Step with no usage adds nothing; a Step with `metered: false` is left out of a metered total.

No finding Kinds and no actions.

## Not here yet

- `runner:` registered in Graph.Node's id prefix table; proposed only (design.md 1).
- `agent:` registered there, which would turn the dangling `follows` errors into warnings (design.md 6).
- The prompt itself on the Plan; the Stream does not carry it (design.md 1).
- A driver for any other vendor (design.md 4).
