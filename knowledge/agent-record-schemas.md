---
type: concept
title: Agent Record Schemas
description: Structured delivery-record contracts (RESEARCH-FINDINGS, EXEC-RESULT, SYNTH-DELIVERY, AUDIT-VERDICT, RETRIEVAL) — fields, invariants, and machine-parse rules
updated: 2026-10-26
tags: [multi-agent, schemas, contracts]
---

# Agent Record Schemas

Every node returns structured records, not prose. Stable keys, machine-parseable.
Topology: see [Agent Team Topology](./agent-team-topology.md).

## RESEARCH-FINDINGS (researcher)
Header: `task`, `queries_run[]`, `ceiling_hit` (none|queries|pages|depth|time), `gaps[]`.
Per finding `Fn`: `claim` (atomic, self-contained), `source_url`, `fetched_at` (ISO 8601),
`version`, `confidence` (high|medium|low), `verified` (true only with ≥ 2 independent sources).
Invariant: no finding without source_url + fetched_at; unverified claims recorded as gaps.

## EXEC-RESULT (executor)
`status` (done|blocked|partial|failed), `done_criterion_met` (bool + quoted criterion),
`commands_run[]` (with exit codes), `artifacts[]`, `metrics {}` (runtime_s, rows_in/out, loops_used),
`loops_used` n/3 per failure site, `stop_reason` (none|cap-hit|signoff-pending|blocked-on-input),
`notes_for_auditor[]` (invariants to check).

## SYNTH-DELIVERY (synthesizer)
`draft` (path), `structure_used` (template + reported deviations), `inputs_consumed[]`,
`citations_preserved` (n), `gaps_flagged[]`, `conflicts_surfaced[]`, `revisions_applied` (0-2),
`open_issues[]` (when revision cap hit).

## AUDIT-VERDICT (auditor)
`verdict` (PASS|FAIL — binary), `score` 0.00-1.00 with dimension breakdown
(factual/constraints/safety/completeness), `items[]` each:
[id, severity (critical|major|minor), what, where, evidence, fix, re-audit],
`verification_evidence[]` (commands + exit codes), `loop_count` n/ceiling,
`escalate_to_hitl` (bool), `re_audit_target` (worker profile(s)), `signoffs[]`,
`learnings[]` (0-5 evidence-backed takeaways; PASS: 0-3, escalated FAIL: 1-2 failure-mode notes —
forwarded by the orchestrator to the librarian ingestion bookend).

## RETRIEVAL / INGEST-ACK (librarian)
RETRIEVAL: `query`, `hits`, per hit: `[path, title, type, updated, excerpt, relevance_reason]`, `misses[]`.
INGEST-ACK: `status` (created|updated|rejected|duplicate), `path`, `tier` (local-bundle|shared-wiki|archived),
`changelog` (line written), `duplicates_checked[]`.
