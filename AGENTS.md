# Agent Instructions

## Agent skills

### Issue tracker

Issues are tracked as local markdown files under `.scratch/<feature>/` (no git remote). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### OKF Knowledge Base

You have access to a persistent, long-term memory system located at `./knowledge/`. This directory complies with the Open Knowledge Format (OKF) v0.1 specification — a structured directory of Markdown files with YAML frontmatter, cross-linked to form a knowledge graph.

**You must not use vector databases, external embedding models, or implicit semantic retrieval for your long-term memory.** Instead, interact with your memory transparently using direct file-based search, explicit path navigation, and Git version control.

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
   - **Step A**: Read `./knowledge/index.md` or scan file names/paths to map available topic domains.
   - **Step B**: Inspect only the YAML frontmatter of candidate files first to filter by metadata (e.g., check `type` or `status`).
   - **Step C**: Read the full Markdown body only for files relevant to the active task.
   - **Step D**: Follow internal Markdown links to explore neighbor concepts if deeper context is required.

#### 3. Memory Maintenance & Writing Protocol

- **Create/Update on Breakthrough**: When you resolve a complex problem, establish a new architecture decision, or learn a critical codebase rule, write or update a concept file in `./knowledge/`.
- **In-Place Updates**: Update existing files directly rather than fragmenting context across multiple redundant files. Keep content clean, concise, and heavily cross-linked.
- **Git Integration**: Treat memory modifications as code changes. Every significant memory update should be cleanly diffable so humans can review, audit, or roll back changes via Git.
- **Logging**: Record all updates in `./knowledge/changelog.md` with format: `## [YYYY-MM-DD] action | Short Title`