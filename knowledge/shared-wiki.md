---
type: concept
title: Shared OKF Wiki
description: Bridge to shared Obsidian wiki on Google Drive with 76 skill concepts
updated: 2026-08-17
tags: [knowledge, wiki, shared, bridge]
---
# Shared OKF Wiki

## Location
`/Users/daddy/Library/CloudStorage/GoogleDrive-humankindsolution@gmail.com/My Drive/ObsidianKB/wiki/`

## Contents
- **76 concept files** across 5 categories
- 28 source summaries (clippings)
- Entities, metrics directories

## Categories
- **Agent Orchestration** (13): cmux, codex-subagent, herdr, git-worktree, launch-subagent
- **Operations & Setup** (11): anti-sleep, prod-push, nuke-cursor-app, google-safe-browsing
- **Research & Web** (8): browser-harness, deep-research, youtube-transcript, research-prompt
- **Skill Authoring** (4): effective-agent-skills, distribute-skill-to-all-agents, push-skill-to-github
- **Thinking & Documentation** (11): brain-to-docs, decisions, level-up, teach, before-building

## Relationship to Local Bundle
| Aspect | Local (`./knowledge/`) | Shared (Google Drive) |
|--------|----------------------|----------------------|
| Purpose | Hermes workspace-specific | Shared skill knowledge base |
| Source | Agent-created during sessions | Ingested from davidondrej/skills |
| Sync | Git versioned locally | Google Drive sync |
| Index | `./knowledge/index.md` | `/wiki/index.md` |
| Log | `./knowledge/changelog.md` | `/wiki/log.md` |

## Access Pattern
1. Read `./knowledge/index.md` for Hermes workspace context
2. Follow links to `/wiki/` for skill documentation
3. Update shared wiki via Obsidian or direct file edits
4. Local bundle mirrors key decisions for quick access

## Git Status
Shared wiki is on Google Drive — not tracked in this repo. Local bundle is version-controlled at https://github.com/nil-liew/hermesworkspace
