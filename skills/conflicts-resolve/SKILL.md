---
name: conflicts-resolve
description: Use when the user hits git merge/rebase/cherry-pick conflicts and wants help resolving them — "fix the conflicts", "resolve this merge", conflict markers in files. Resolves ONLY mechanically-unambiguous conflicts; when in doubt it changes nothing and leaves the conflict for the user.
---

# Conflict Resolution (Conservative)

## Overview

Resolve git conflicts, but **only the ones that need no judgment**. Anything that requires understanding intent is left untouched, with its markers intact, for the user to resolve.

**Iron rule: when in doubt, leave it.** A conflict left for the user is a good outcome. A conflict resolved the wrong way is silent data loss. Never trade the second to avoid the first.

This skill never commits, never continues the merge/rebase, and never force-anythings. It resolves what's safe, stages only fully-cleared files, and hands control back.

## What is safe to auto-resolve

Only these two categories — both are mechanical, no intent required:

1. **Identical on both sides** — both branches made the exact same change in the conflict region. Take it.
2. **Non-overlapping pure additions (union)** — ours adds lines, theirs adds lines, at the same anchor, and **neither side touches a line the other changed**. Take both. Typical: import lists, enum/dict/registry entries, append-only lists, CHANGELOG entries.
   - **Guard:** if the union would create a duplicate (same symbol, key, import, function name) or the two additions reference each other, it is NOT safe → leave it.

Everything else is **leave**.

## What to LEAVE (do not resolve)

- Both sides modified the **same logical lines** with different content.
- Anything where choosing a side changes behavior, or where you'd have to guess what the user wants.
- **Lockfiles / generated files** (`package-lock.json`, `yarn.lock`, `poetry.lock`, `Pipfile.lock`, build output, snapshots) — don't hand-merge; these are regenerated. Leave the conflict and tell the user the regenerate command.
- **Migrations / schema** — ordering and dependencies matter; leave.
- **Binary files.**
- Reformatting/whitespace-only differences (could hide a real change) — leave.

When unsure which category a conflict is in, it is **leave** by definition.

## Workflow

### 1. Survey

```bash
git status                                   # what operation is in progress (merge/rebase/cherry-pick)
git diff --name-only --diff-filter=U         # conflicted files
```

Know the operation: in a **rebase/cherry-pick**, "ours"/"theirs" are swapped relative to a merge. This is exactly why blind `--ours`/`--theirs` is banned (see Red Flags).

### 2. Classify each conflict

Read each conflicted hunk. Put it in exactly one bucket: **identical**, **union-safe** (passes the guard), or **leave**. Default to **leave**.

### 3. Resolve only the safe ones

Edit safe hunks in place (remove markers, keep the correct content). For union, include both additions in a deterministic order.

**Do not touch** the markers of any "leave" hunk.

### 4. Stage only fully-cleared files

`git add` marks the **whole file** resolved — so only stage a file if **every** conflict in it was safely resolved.

- File with all conflicts safe → resolve all, `git add <file>`.
- File with any "leave" conflict → resolve the safe hunks in place if you like, but **leave the file unstaged** with the remaining markers, so the user sees what's left.

After staging, verify nothing with markers slipped through:

```bash
git diff --cached -U0 | grep -nE '^[+]<<<<<<< |^[+]>>>>>>> ' && echo "MARKERS STAGED — unstage and fix" || echo "clean"
```

### 5. Report and hand back

- **Auto-resolved:** file — which rule (identical / union) — what was kept.
- **Left for you:** file:line — why (same-line edit / lockfile / migration / unsure).
- The command to finish once they're done (e.g. `git rebase --continue`, `git merge --continue`) — but **do not run it**.
- For lockfiles, the regenerate hint (e.g. `npm install`).

## Red Flags — STOP

- About to run `git checkout --ours/--theirs <file>` → **no.** That discards a whole side blind, and the sides are swapped in rebase.
- About to `git add` a file that still has a "leave" conflict → **no**, it marks it resolved.
- About to `git rebase --continue` / `merge --continue` / `commit` → **no**, that's the user's call.
- Thinking "it's obvious they want theirs" → that's intent-guessing → **leave it.**

## Rationalization Table

| Excuse | Reality |
|--------|---------|
| "It's obviously their version" | Obvious to you = a guess about intent. Leave it. |
| "Just take HEAD to move on" | Discards the other side's work silently. Leave it. |
| "The user said just resolve it" | "Resolve" doesn't mean "guess". Resolve the safe ones, leave the rest. |
| "Union both, more is safer" | Duplicate symbols/keys break the build. Apply the guard; if it fails, leave. |
| "I'll merge the lockfile by hand" | Hand-merged lockfiles corrupt. Regenerate, don't merge. |
| "Whitespace-only, harmless" | Whitespace diffs can hide real edits. Leave it. |

## Common Mistakes

- **Wholesale `--ours`/`--theirs`** — banned; sides differ by operation and it discards work.
- **Staging a partially-resolved file** — marks remaining markers as resolved.
- **Continuing the merge/rebase** — leave that to the user after they finish the "leave" set.
- **Treating union as always safe** — run the duplicate/cross-reference guard first.
