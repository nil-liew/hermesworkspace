# Knowledge Base Changelog

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
