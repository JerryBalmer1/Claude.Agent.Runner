# Claude.Agent.Runner design decisions

Numbered. Do not reopen without a proposal in a report.

## 1. Ids carry the `runner:` prefix, built from the plan, the session and the step number

Proposed: the id prefix `runner:`, owned by Claude.Agent.Runner, with the shapes

| Kind | Id |
|---|---|
| Plan | `runner:<plan>`, `<plan>` the captured stream's file name up to its first `.` (`three-turns.stream.jsonl` → `runner:three-turns`) |
| Run | `<Plan id>/<session id>` (`runner:three-turns/70c11582-dade-4bbc-9cab-4999f761dc1a`) |
| Step | `<Run id>/step-<n>`, `n` from 1 in stream order |

Graph.Node registers prefixes (`schemas/ids.md`, `Get-GraphIdPrefix`); this repo does not edit Graph.Node, so `runner:` is a proposal until Graph.Node registers it. Until then the validators treat these ids as unregistered, which costs nothing: every `runner:` endpoint is a node in the same envelope. Pester asserts it is still unregistered so the day it is, the test fails and a shape check replaces it. The Plan is named by file because the stream does not carry the prompt; two captures of the same prompt saved as `x.1.stream.jsonl` and `x.2.stream.jsonl` are two Runs of Plan `runner:x`.

## 2. Three Kinds: Plan, Run, Step; edges contains, order, follows

A Plan is what was asked, a Run one session working it, a Step one model turn: one assistant message and the tool calls it made. `contains` runs Plan → Run → Step. `order` joins each Step to the next one in the same Run, so the sequence is an edge walk rather than a sort on `index`. `follows` goes from a Step to the `agent:` Rule (Graph.Emitter.Agent's `agent:<file>#<slug>/rule-<n>`) whose prompt line directed it, and is absent when the Step was improvised. Rule is Graph.Emitter.Agent's Kind; this ontology names it in `follows.to` and does not declare it.

## 3. Tokens live on Steps only; totals are sums at query time

A Step carries `tokensInput`, `tokensOutput`, `tokensCache` (all optional: absent when the stream reported no usage for the turn) and `metered` (optional, true when absent; the drivers here always write it). Run and Plan carry no token properties. A total is the sum over the Steps a Run or Plan contains, computed by whoever asks; storing it would be a second copy that can disagree with the first.

## 4. Vendors live under drivers/ only

`src/Claude.Agent.Runner/drivers/<name>/driver.ps1` is a script that takes `-Path` and returns

```
@{ SessionId; Model; StartedAt; Steps = @(@{ MessageId; Model; StartedAt; Tools; Text; TokensInput; TokensOutput; TokensCache; Metered; Follows }) }
```

`Export-RunnerGraph -Driver <name>` runs it through `Private/Invoke-RunnerDriver.ps1`; without `-Driver`, `drivers/drivers.psd1` names the default (`claude`). Nothing outside `drivers/` names a vendor: Pester greps `Public/`, `Private/` and the manifest for `claude`, case-insensitive, with the module name itself the one exception.

## 5. The claude driver: one Step per assistant message id

`drivers/claude/driver.ps1` reads `claude -p --output-format stream-json --verbose`, one JSON object per line. The CLI writes one `assistant` line per content block (thinking, text, tool_use), each repeating the message id and its usage, so the lines of one id are one Step, in the order ids first appear, and usage is taken from the id's last line. `tokensCache` is `cache_read_input_tokens + cache_creation_input_tokens`. The stream's per-message `output_tokens` is the count when the line was written, not the message's final count: the fixture's three Steps report 6, 2 and 1 output tokens while its `result` line reports 746 for the run (460 of them thinking). The Step records what the stream says; the `result` line's totals are not stored (design.md 3). `tools` is the tool names joined by `, ` rather than a list, because Graph.Node's `New-GraphNode` unrolls an array property (one name becomes a string, none becomes null).

## 6. follows comes from the rule id a Step names, and dangles until the Agent layer is merged

A Step follows every `agent:<...>/rule-<n>` id its text names, distinct, in order. The prompt tells the agent to cite the id of the line it is acting on; nothing else in the stream links a turn to a prompt line. The endpoint belongs to Graph.Emitter.Agent's layer, so in this envelope it dangles, and because `agent:` is not registered in Graph.Node either, Graph.Node reports that `dangling-edge` as an error, not a warning. `Export-RunnerGraph` keeps those edges and tolerates exactly those errors when it writes a layer; any other problem throws. `-Strict` throws on any dangling `follows` edge, before writing.

## 7. One function: Export-RunnerGraph

`Export-RunnerGraph -InputPath <stream> [-Driver <name>] [-LayersPath <dir>] [-Strict]` returns the envelope; with `-LayersPath` it also writes `<layer stamp, : as ->.graph.json` there with `ontology.yaml` beside it and checks the file with `Test-Graph -Strict`, as Graph.Emitter.Agent's `Export-AgentGraph` does. The layer is the Run's first stream timestamp at whole seconds, so exporting the same capture twice writes the same file; a stream without timestamps gets the current time. The envelope's root is the Plan.

## 8. The fixture is a real capture, trimmed

`tests/fixtures/three-turns.stream.jsonl` was captured on 2026-10-09 with `claude -p --output-format stream-json --verbose --model haiku --allowedTools Read --max-turns 5`, a prompt of two lines tagged `[agent:CLAUDE.md#rules/rule-1]` and `[...rule-2]` (read `a.txt`, read `b.txt`) and an untagged third (answer in one sentence). Two edits, nothing else: the `system/init` line keeps only `type`, `subtype`, `cwd`, `session_id`, `model`, `apiKeySource`, `claude_code_version`, `uuid` (it listed every tool, plugin and local path of the machine), and the scratch directory's path is shortened to `C:\capture` everywhere. Three assistant messages, eight assistant lines, two `follows`.
