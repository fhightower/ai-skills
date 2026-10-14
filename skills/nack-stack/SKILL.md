---
name: nack-stack
description: Use when review agents (Claude, Codex, etc.) raised items on a pull request that won't be addressed and the user wants that recorded on the PR — "add this to the NACK stack", "update the nack stack", "note on the PR why we're skipping these", declined or won't-fix bot feedback. A NACK stack is a single running PR comment listing each declined item and why.
---

# NACK Stack

## Overview

A NACK stack is a comment on a PR that lists the significant items review agents raised which the PR deliberately won't address, each with its reason. It answers "the bot flagged this — why wasn't it done?" once, in one place, before a human reviewer has to ask it.

It is **one comment, edited in place**. Every update appends to that comment. Try to avoid creating multiple NACK Stack comments on a single PR unless there's a compelling reason to do so.

The goal is to give human and agentic reviewers a sense of what review items you've already considered before putting this PR up for review.

## What goes on the stack

An item goes on when all three hold:

1. **A locally running agent raised it** — Review items on the PR itself from a human or agentic reviewer (e.g. CodeRabbit) doesn't go here; reply in their thread instead.
2. **The decision not to address it is made** — by the user, or by you with the user's agreement. Undecided items stay off.
3. **It's significant** — a human reviewer reading the agent's comment would reasonably ask why it wasn't done. So Nits don't make this list.

Each entry in the stack must include reasoning about why a given review item won't be done.

## Format

```markdown
## NACK Stack

Review items raised by agents that this PR deliberately won't address, and why.

| Review item | Why not |
|---|---|
| Validate `limit` before querying in `search.ts` `buildQuery()` | **False positive** — the request schema clamps `limit` to 1–100 before the handler runs (`schema.ts` `SearchParams`). |
| Extract the retry loop into a shared helper | **Out of scope** — tracked in #340; this PR only fixes the timeout. |
```

Row rules:

- **Review item** — the concern in your own words. KEEP IT BRIEF! About 15 words max, with file and symbol. No line numbers: they drift as the branch moves.
- **One row per concern.** Several agents raising the same thing is still one row.
- **Fixed after all?** Strike through its review item (`~~…~~`) and append `Addressed in <sha>` to the "Why not" column. Keep the row.
- **Cells are single-line.** Escape `|` as `\|`, including inside backticks — GitHub splits the cell otherwise.
- Don't reference any internal IDs in a row

## Workflow

`<PR>` may be a number, URL, or omitted (current branch).
