---
name: pr-file-by-file-walkthrough
description: Use when the user wants to walk through a pull request file by file, review a PR one file at a time, go through the changed files one by one, or says "walk me through this PR" — establishes the real diff first, then presents one file per turn and stops for questions in between.
---

# PR File-by-File Walkthrough

## Overview

The user wants to read a PR **with** you, not receive a review of it. That makes two things true:

1. **One file per turn.** Summarize, then stop. The questions between files are the point — batching files destroys the format.
2. **Verify, don't relay.** If a PR description says "pure relocation" or "no behavior change", your job is to confirm that from the code, not to paraphrase it back.

## Workflow

### 1. Flag any conflicts

Pull the diff from GitHub and make sure there are no conflicts on the branch.

### 2. Order the files and announce the count

GitHub's Files-changed tab sorts **alphabetically by path**. Match that order so "the first file" means the same thing to both of you.

```bash
gh api --paginate repos/<owner>/<repo>/pulls/<PR>/files \
  --jq '.[] | "\(.status)\t+\(.additions)\t-\(.deletions)\t\(.filename)"' | sort -k4
```

`gh pr view --json files` caps at 100 — use the paginated API for anything larger.

### 3. Present one file

Per turn, one file and nothing more:

```
**`path/to/file.ext`** (+N / −M)

<One line naming what kind of change this is.>

<The smallest diff excerpt that carries the point (when relevant and feasible) — not the whole hunk.>

<What it means, and anything you checked to be sure.>

Ready for questions.
```

Rules that keep the format working:

- **Stop after each file.** No "and the next file does X." Wait.
- **Excerpt, don't dump.** Three lines that show the change beat forty lines of context.
- **Name the category up front** — "import rewrite only", "pure deletion", "the big one" — so the user knows instantly whether to ask anything.
- **Group only true duplicates.** Ten identical one-line import rewrites can share a turn. Two files that merely look similar cannot.
- **Surface a finding where it lives**, once, in a sentence. A walkthrough is not a review report; don't accumulate a findings table unless the user asks for one.

### 4. Verify the claim the file is making

Every moved, renamed, or "mechanical" change is an assertion. Check it. This is where a walkthrough earns its keep.

**Moved code — did all of it arrive, with identical bodies?** Compare parsed symbols, not grep counts:

Without a parser, `git diff -M --find-renames` plus `git log --follow` gets you most of the way, and a sorted symbol dump (`ctags -x`, or `grep -o 'func [a-zA-Z_]*'`) covers the rest.

**Renames — did every reference follow?** Sweep the whole tree, not just the changed files, and include non-code:

```bash
git grep -n '<old-name>' -- ':!*/migrations/*' ':!vendor/'
git grep -rn '<old-name>' -- '*.md' '*.yml' '*.tf' '*.sh' '*.json'
```

Docs, comments, config keys, mock/patch target strings, raw SQL, and generated identifiers are where stale references survive — they don't break a build.

**Extracted helpers — are they equivalent?**

**Base-class or interface swaps — what was dropped?** Diff the old parent against the new one and confirm nothing the subclasses call went missing. Auth and permission attributes especially.

**Claims about the environment.** "This branch isn't deployed", "no one uses this", "the table is empty" — these are checkable against the actual deploy pipeline, dashboard, or database, and they are exactly the claims an approval rests on.

### 5. Follow the thread the user pulls

When the user asks a follow-up — "was everything moved?", "what is X?", "any other references?" — that question **replaces** the next file. Answer it completely, with evidence, then return to the walk when they say so. Don't advance the file counter to stay on schedule.

## Relation w/ other skills

Pairs with [`pr-diff-since-review`](../pr-diff-since-review/SKILL.md) when the user only wants the newest round, and [`re-review-pr`](../re-review-pr/SKILL.md) when they've read the PR before.
