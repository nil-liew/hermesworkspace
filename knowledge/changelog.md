# Knowledge Base Changelog

## [2026-11-19] uninstall | TREK trip planner removed
- `~/trek` deleted in full per user directive — install tree, `.env` (admin creds), SQLite trip data (3.1M, discarded per user), and uploads (404K)
- No Docker containers/volumes remained (stack was already down); no tailscale serve config present
- Removed `knowledge/trek-selfhosted-planner.md` + "Self-Hosted Services" section from index.md
- Install history (2026-10-29) remains in this changelog; doc link removed

## [2026-11-19] ingest | OKF docfix verdict bookend (knowledge-ops board)
- Gate: auditor t_1080ffbf PASS (score 1.00, 0 items, loop 0/5) on apply t_1a4681ce ← audit t_76c58558; byte-identity 112/116 snapshot files, exactly the 4 intended files modified, 0 unexpected, 0 deleted
- `knowledge/shared-wiki.md`: "76 skill concepts" → 48 concept pages (47 ingested from davidondrej/skills + 1 local hermes-workspace); "28 source summaries" → 29; added "26 entity pages (reconciled 2026-11-17)" line; frontmatter updated 2026-08-17 → 2026-11-19
- `AGENTS.md`: abbreviated `~/Library/CloudStorage/GoogleDrive-.../` Drive shorthand → full `GoogleDrive-humankindsolution@gmail.com/My Drive/` path (×4 at L22/52/60/65)
- `wiki/index.md`: gained hermes-workspace row (L73; link target `concepts/hermes-workspace.md` exists on disk)
- `wiki/log.md`: [2026-11-19] docfix entry (L298) verified present + well-formed — executor-authored; not modified by this ingest
- Verified learnings[] (persist for future sessions):
  - shared-wiki.md's "76" was NEVER drift: a concepts+sources total (48+28) mislabeled as "concept files," born wrong at bridge commit 7ba7bfb (2026-08-17 14:06, one minute before hermes-workspace.md was created); correct headline count = 48 concept pages
  - Today's true total: 48 concept pages + 29 source pages = 77; entities = 26 stubs; `metrics/` dir still hollow (index only, 0 of 16 pages — pre-existing known issue, not fixed in this loop)
  - hermes-workspace was the only concept that was unindexed; now in `wiki/index.md`
  - AGENTS.md's abbreviated `~/Library/CloudStorage/GoogleDrive-.../` shorthand does not resolve literally; the full `GoogleDrive-humankindsolution@gmail.com` path is the only working one
  - `wiki/log.md`'s [2026-07-22] "All 28 Clippings Processed" header was an off-by-one (29 bullets); corrected to 29
- No git commit (user has not requested one — hermesworkspace working tree left dirty, HEAD unchanged at 1ef028c7 2026-10-26; vault has no .git)

## [2026-11-17] reconcile | Obsidian OKF wiki link-graph repair (knowledge-ops board)
- Pass 1 routed t_ee0ba194 (executor) → t_b70a03c4 (auditor, parent-gated); audit verdict PASS @ 0.98, 0 critical items
- 26 entity stubs created from entities/index.md (YAML-valid OKF frontmatter, Related-links verified live, zero fabricated content)
- 51 drifted-link rewrites across 6 files (index.md, log.md, 4 sources); 216 distinct unresolvable targets flagged under log's "Unresolved" list; 0 unflagged dead links
- Integrity proof: 164/164 pre-state snapshot paths intact (0 deletions); Clippings/, raw/, guide/, local bundle byte-identical (0 scope violations)
- Learnings ingested into new skill `okf-wiki-maintenance`: strip fenced/inline code before counting [[links]] (grouped log counts include code-quoted refs); exclude .obsidian/workspace.json from byte-identity scope (drifts with open Obsidian); pin link-resolution semantics before counting (strict-path 248 vs basename-fallback 249); trust log.md over handoff narrative (M2: handoff claimed 252 resolvable, fresh scan measured 248/249)
- Open follow-up (pass 2, not started): ~18 missing metrics/ pages + unregistered entity refs (total-typescript, tree-sitter, vllm, z-lab…); backfill sharbel.com "10 Hermes skills" clip with install commands
- No commit (commit-on-request policy)

## [2026-10-29] https | TREK phone-install layer (Tailscale serve)
- Enabled tailnet-only `tailscale serve --bg 3000` on familys-mac-mini → `https://familys-mac-mini.tailc128e8.ts.net` proxies to TREK (ACME cert, no public exposure; one-time /f/serve admin activation required)
- Verified end-to-end via tailnet DNS (`dig @100.100.100.100` + `curl --resolve`): HTTP 200, TLS chain valid
- Updated trek-selfhosted-planner.md with HTTPS section + phone PWA steps; `trek-install` skill gained an "HTTPS for phone PWA" section
- `COOKIE_SECURE=false` retained deliberately (LAN-HTTP path still primary)

## [2026-10-29] install | TREK self-hosted trip planner (Mac)
- Added [trek-selfhosted-planner.md](./trek-selfhosted-planner.md) — install layout (~/trek, Docker Compose), compose deviations (unwired ADMIN_*/COOKIE_SECURE lines), agnes.ai AI connection (custom OpenAI-compatible, agnes-3.0-flash), multi-user + ops notes
- Created skill `trek-install` (devops): full install flow, 7 production-hit pitfalls, admin-API AI setup incl. `scripts/trek-ai-setup.py`
- Updated index.md: new "Self-Hosted Services" category; Last updated → 2026-10-29
- No commit (commit-on-request policy)

## [2026-10-28] retrieve | P1 travel-itinerary pre-retrieval (t_fa03adac)
- RETRIEVAL record written: `~/monkeycodeworkspace/travel-itinerary/.orchestration/retrieval-p1.md` — 8 cited hits (project-context.md ×2, oiui-laya-integration.md ×2, agent-record-schemas.md, auditor-p1.md body, wiki arahim3-mlx-dspark.md + nextlevelbuilder-ui-ux-pro-max.md), 2 honest misses (Google Maps JS API patterns; React/Vite build pitfalls → spec defaults)
- Data quality: `index.md` broken link `./projects/cinema-player.md` (file/dir absent); wiki `nextlevelbuilder-ui-ux-pro-max.md` links missing `concepts/design-tokens.md` + `concepts/design-systems.md` — no files created by this task (retrieval only; ingest is the post-audit bookend)
- No concepts written; no commit (commit-on-request policy)

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
