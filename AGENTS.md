# Agent Instructions

## Agent skills

### Issue tracker

Issues are tracked as local markdown files under `.scratch/<feature>/` (no git remote). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### OKF Knowledge Base

You have access to **two** OKF v0.1 compliant knowledge systems:

1. **Local Bundle** (`./knowledge/`) — Workspace-specific context, project decisions, agent instructions
2. **Shared Wiki** (`~/Library/CloudStorage/GoogleDrive-.../ObsidianKB/wiki/`) — 76 skill concepts from davidondrej/skills

[Read the bridge documentation](./shared-wiki.md) for details on both systems.

**You must not use vector databases, external embedding models, or implicit semantic retrieval for your long-term memory.** Instead, interact with your memory transparently using direct file-based search, explicit path navigation, and Git version control (for local bundle only).

#### 1. Structure
- **Concepts as Files**: Every distinct concept, entity, decision, runbook, or architecture pattern is stored as a single `.md` file inside `./knowledge/`. The file path is the concept's unique identity.
- **YAML Frontmatter**: Every concept file begins with YAML frontmatter containing at minimum:
  ```yaml
  ---
  type: concept # or playbook, dataset, table
  title: Short Title
  description: Concise summary of content
  updated: YYYY-MM-DD
  ---
  ```
- **Graph Traversal**: Concepts link using standard Markdown relative links: `[Link Text](./other-concept.md)`
- **Directory Listings & Logs**: Use `index.md` files for navigation and `changelog.md` to trace chronological changes.

#### 2. Operational Rules & Search Methodology

When recalling past decisions, specifications, or historical context:

1. **File-System Search (`grep` / Globbing)**:
   - Use workspace tools to search `./knowledge/` for keywords, YAML keys, or identifiers.
   - Example: Search for files containing specific frontmatter tags using pattern matching or text-search tools rather than semantic vector similarity.

2. **Progressive Disclosure**:
   - **Step A**: Read `./knowledge/index.md` to map Hermes workspace context, then read `./knowledge/shared-wiki.md` to understand the shared wiki.
   - **Step B**: For local concepts, inspect frontmatter in `./knowledge/`. For skills, check YAML frontmatter in `~/Library/CloudStorage/.../wiki/concepts/`.
   - **Step C**: Read full content only for files relevant to the active task.
   - **Step D**: Follow Markdown links across both systems — local concepts link to shared wiki skills and vice versa.

#### 3. Memory Maintenance & Writing Protocol

- **Create/Update on Breakthrough**: When you resolve a complex problem, establish a new architecture decision, or learn a critical codebase rule:
  - Write to `./knowledge/` for workspace-specific context (version-controlled via Git)
  - Update `~/Library/CloudStorage/.../wiki/concepts/` for shared skill documentation
- **In-Place Updates**: Update existing files directly rather than fragmenting context across multiple redundant files.
- **Git Integration**: Local bundle changes are tracked via Git at https://github.com/nil-liew/hermesworkspace
- **Logging:** Record updates in both locations:
  - `./knowledge/changelog.md` for local changes
  - `~/Library/CloudStorage/.../wiki/log.md` for shared wiki changes