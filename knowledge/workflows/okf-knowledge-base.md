---
type: workflow
title: OKF Knowledge Base
description: Instructions for using the local OKF knowledge bundle in the workspace
updated: 2026-08-17
tags: [okf, knowledge, workflow]
---

# OKF Knowledge Base Workflow

## Location
`./knowledge/` in workspace root

## Usage

### Retrieval
1. Read `./knowledge/index.md` first
2. Follow wiki links to concept files via progressive disclosure
3. Use agentic file search (Grep, file listing) to navigate

### Creation
1. Create new concept files when learning patterns, decisions, or code structures
2. Always include YAML frontmatter:
   ```yaml
   ---
   type: concept # or playbook, dataset, table
   title: Short Title
   description: Concise summary
   updated: YYYY-MM-DD
   ---
   ```
3. Structure body in plain Markdown

### Linking
- Use standard Markdown links: `[Topic Name](./path-to-file.md)`
- Maintain the knowledge graph across files

### Logging
- Record all updates in `./knowledge/changelog.md`
- Format: `[YYYY-MM-DD] action | Short Title`

## Types
- **concept** — Abstract ideas, frameworks, patterns
- **playbook** — Step-by-step procedures, workflows
- **dataset** — Data tables, structured information
- **table** — Tabular data representations
