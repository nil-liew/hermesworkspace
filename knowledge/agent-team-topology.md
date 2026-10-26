---
type: concept
title: Agent Team Topology
description: Six-node multi-agent team (orchestrator + librarian + 4 workers) — roles, toolsets, gate interlocks, kanban mechanics, and drill-verified behaviors
updated: 2026-10-26
tags: [multi-agent, kanban, architecture, team]
---

# Agent Team Topology

The Hermes multi-agent team is coordinated through the kanban board (board `team-drill`
for drills; one board per workstream). Node roster, 2026-10:

| Node | Profile | Toolsets | Delivery record |
|---|---|---|---|
| ORCHESTRATOR (router) | `apex-orchestrator` | kanban + delegation (depth ≤ 2) + core, no web/browser | plans, routing, synthesis |
| LIBRARIAN (memory) | `librarian` | file, terminal, code_exec, memory, skills | `INGEST-ACK` / `RETRIEVAL` |
| RESEARCHER (worker) | `researcher` | web, browser, file, skills | `RESEARCH-FINDINGS` |
| EXECUTOR (worker) | `executor` | terminal, code_exec, file, skills | `EXEC-RESULT` |
| SYNTHESIZER (worker) | `synthesizer` | file, skills (leanest) | `SYNTH-DELIVERY` |
| AUDITOR (quality gate) | `auditor` | terminal, code_exec, file, kanban gate | `AUDIT-VERDICT` |

All run agnes-3.0-flash (custom provider); each has a `*-protocol` skill and
SOUL.md guardrails mirroring its blueprint's §5. Record schemas: see
[Agent Record Schemas](./agent-record-schemas.md).

## Canonical Execution Sequence (Hub-and-Spoke, adopted 2026-10-26)
Closed-loop pipeline for multi-worker goals; no worker ever talks to the user or
completes a session alone — all returns land at the ORCHESTRATOR:

```
USER → ORCHESTRATOR (decompose)
ORCH → LIBRARIAN (retrieval: past lessons/schemas/context) → ORCH (RETRIEVAL record)
ORCH → RESEARCHER → ORCH (RESEARCH-FINDINGS)
ORCH → EXECUTOR → ORCH (EXEC-RESULT + artifacts)
ORCH → SYNTHESIZER → ORCH (SYNTH-DELIVERY + draft)
ORCH → AUDITOR → ORCH (AUDIT-VERDICT: PASS signal + learnings[])
ORCH → LIBRARIAN (ingest learnings[] + verified patterns) → ORCH (INGEST-ACK)
ORCH → USER (final briefing, deliverables, future improvements)
```
Bookend rules: the pre-research LIBRARIAN retrieval and the post-audit LIBRARIAN
ingestion are mandatory for multi-worker goals; AUDITOR is never skipped. Stage
skips (research/execute/synthesize) are allowed only when the librarian's
retrieval already holds verified current artifacts — record the reason.

## Gate Interlocks (the fail loop)
- Auditor PASS rule: score ≥ 0.85 (0.40 factual / 0.25 constraints / 0.20 safety / 0.15 completeness) AND zero critical items.
- FAIL → auditor `kanban_block`s the task with delta items; orchestrator re-dispatches the named worker.
- Cycle caps: orchestrator ≤ 5 re-delegation cycles/task; synthesizer ≤ 2 revision rounds; executor ≤ 3 debug loops/failure site; at any ceiling, verdict carries `escalate_to_hitl: true`.
- Destructive ops: executor plans `PENDING-SIGNOFF` items; only the auditor may issue `SIGNOFF` (one sign-off per operation). `approvals.unattended_mode: deny` auto-denies destructive commands in unattended worker runs.
- Cross-worker handoffs carry structured artifacts only (never raw transcripts).

## Kanban Mechanics (verified in 2026-10-26 drill)
- `kanban create --triage` → `kanban decompose <task>`: LLM decomposer routes children by **profile description** — keep descriptions role-precise.
- Dispatcher: gateway tick every 60 s promotes ready tasks and spawns the assigned profile; `kanban dispatch` forces a tick.
- Worker tool scoping: a dispatcher-spawned worker's `kanban_*` tools are scoped to ITS task — cross-task `kanban_complete`/`unblock` is refused ("worker is scoped to task X"). Gate-close actions belong to the orchestrator-side `kanban` toolset (or CLI).
- `kanban complete` requires `--summary`/`--result` evidence; empty completions are refused.
- Task workspaces: `--workspace dir:<path>` pins a dir (`scratch`, `worktree` also valid); children inherit the parent's pin.
- A blocked parent prevents child promotion — reparent (unlink/link) around blocked tasks.
