---
type: concept
title: Hermes Skills Visibility
description: Matt Pocock engineering skills are user-invoked and don't appear in the Skills tab UI by design.
updated: 2026-08-31
---

# Hermes Skills Visibility

Most Matt Pocock engineering skills (`grill-me`, `to-spec`, `implement`, `wayfinder`, etc.) are intentionally **user-invoked** with `disable-model-invocation: true` in their SKILL.md frontmatter. This means:

- They DON'T appear in the Skills tab UI
- They only activate when explicitly typed (e.g., `/grill-me`, `/to-spec`)
- They have zero context load until invoked
- They exist in `~/.hermes/skills/` but are hidden from the UI by design

This is intentional — they're workflow tools invoked on demand, not background context that loads every turn.

## Checking Skill Existence

```bash
hermes skills list 2>&1 | grep <skill-name>
ls ~/.hermes/skills/ | grep <skill-name>
```

## User-Invoked vs Model-Invoked

| Type | Description | Skills Tab | Context Load |
|------|-------------|------------|--------------|
| User-invoked | `disable-model-invocation: true` | No | Zero (on-demand) |
| Model-invoked | No disable flag | Yes | Always loaded |

## Related Skills

- [hermes-skills-system](./hermes-skills-system.md) - Full mechanics and CLI reference
- [writing-for-agents](./writing-for-agents.md) - SKILL-MECHANICS.md for deeper context
