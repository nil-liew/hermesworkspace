# Knowledge Base Changelog

## [2026-10-26] adopt | Hub-and-Spoke canonical execution sequence
- [agent-team-topology.md](./agent-team-topology.md): added "Canonical Execution Sequence (Hub-and-Spoke)" section — memory bookends (librarian pre-retrieval + post-audit ingestion), stage-skip rules, no-worker-user rule
- [agent-record-schemas.md](./agent-record-schemas.md): AUDIT-VERDICT schema extended with `learnings[]` field (0-5 evidence-backed takeaways for the librarian ingestion bookend)
- Team skills synced in step: apex-orchestration v1.1.0 (apex-orchestrator profile), audit-protocol v1.1.0 (auditor profile)

## [2026-10-26] ingest | Agent Team reference concepts
- Added [agent-team-topology.md](./agent-team-topology.md) — six-node team roster, gate interlocks, kanban mechanics (frontmatter valid, no fix)
- Added [agent-record-schemas.md](./agent-record-schemas.md) — structured delivery-record contracts (frontmatter fix: added missing `updated: 2026-10-26`)
- Updated index.md: new "Agent Team" category listing both; Last updated → 2026-10-26

- [oiui-laya-integration.md](./oiui-laya-integration.md)
- [2026-10-14] OpenIntelligentUI + Laya decision-engine integration
- Added oiui-laya-integration.md playbook (agnes chat model + Laya /route/visual router)
- Laya: new laya/api/visual_route_api.py, mounted in main.py; settings: custom provider `agnes`, router model `agnes/agnes-3.0-flash`
- OIUI: model.py accepts custom OPENAI_BASE_URL models; visualization_router.py supports ROUTING_AUTH_TOKEN; design-system dist must be built

## [2026-08-17] init | Knowledge Bundle Initialized
- Created initial knowledge bundle structure
- Added project-context.md
- Added workflows/okf-knowledge-base.md
- Established OKF v0.1 compliance

## [2026-08-17] git | Repository Initialized
- Initialized git repository in workspace
- Created initial commit with knowledge bundle structure
- All knowledge files are now version-controlled
- Enables diffable memory changes as per AGENTS.md Git integration directive

## [2026-08-17] github | Remote Connected
- Authenticated as nil-liew on GitHub
- Created public repository: https://github.com/nil-liew/hermesworkspace
- Pushed 2 commits to origin/main
- Knowledge bundle is now synced to GitHub

## [2026-08-17] bridge | Shared Wiki Connected
- Created bridge documentation: `./knowledge/shared-wiki.md`
- Connected local bundle (`./knowledge/`) to shared wiki (`~/Library/CloudStorage/.../wiki/`)
- Shared wiki contains 76 skill concepts from davidondrej/skills
- AGENTS.md updated to reference both knowledge systems
- Two-source OKF workflow: local (Git-tracked) + shared (Google Drive)

## [2026-08-31] skills | Hermes Skills Visibility Documented
- Added `hermes-skills-visibility.md` to explain user-invoked vs model-invoked skills
- Matt Pocock engineering skills (`grill-me`, `to-spec`, `implement`, `wayfinder`) are user-invoked by design
- User-invoked skills have `disable-model-invocation: true` and don't appear in Skills tab UI
- Created `hermes-skills-system` skill with full mechanics reference
