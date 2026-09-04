---
name: pr-diff-since-review
description: Use when the user wants to see what changed on a PR since it was last reviewed, wants a diff/compare link for the new commits a reviewer hasn't seen yet, asks "what's changed since the review", or wants to point a reviewer at just the latest round of changes — builds a GitHub compare link from the last-reviewed commit to the current head.
---

# PR Diff Since Review

## Overview

A reviewer already read the PR at some commit. Since then it got more commits. Produce a link showing only the new work:

```
https://github.com/<owner>/<repo>/compare/<last-reviewed-sha>...<head-sha>
```

Every review records the commit it was submitted against, so the baseline is a lookup, not a guess. Report the commit list alongside the link — a bare URL doesn't say whether it holds one typo fix or a rewrite.

## Workflow

### 1. Resolve the PR

`<PR>` may be a number, URL, or omitted (current branch). Everything below also accepts `--repo <owner>/<repo>`.

```bash
gh pr view <PR> --json url,headRefOid,baseRefOid --jq '"\(.url) \(.headRefOid) \(.baseRefOid)"'
```

### 2. Find the last-reviewed commit

Use the **REST** reviews endpoint — it exposes `user.type`, the only reliable bot flag. (`gh pr view --json reviews` also carries `commit.oid`, but reports CodeRabbit as `coderabbitai`, not `coderabbitai[bot]`, so you can't separate bots from humans by login.)

```bash
gh api repos/<owner>/<repo>/pulls/<PR>/reviews \
  --jq '.[] | select(.state != "PENDING") | "\(.submitted_at) \(.user.login) \(.user.type) \(.state) \(.commit_id)"'
```

Pick the baseline:

| Situation | Baseline commit |
|---|---|
| Default | Latest review with `user.type == "User"` |
| User named a reviewer | That person's latest review |
| Several reviewers, different baselines | Say so; offer one link per reviewer |
| Only bot reviews (CodeRabbit, Copilot) | Fall back to `baseRefOid` — no human has looked yet |
| No reviews at all | Fall back to `baseRefOid` — the link is the whole PR |

Bots re-review on every push, so counting them makes the answer "nothing new" forever. Exclude them unless asked. Drop `PENDING` too — that's an unsubmitted draft, which no one has seen.

### 3. Verify the range before handing over a link

```bash
gh api repos/<owner>/<repo>/compare/<from>...<head> \
  --jq '"\(.status) ahead=\(.ahead_by) behind=\(.behind_by) commits=\(.total_commits) files=\(.files|length)"'
```

| `status` | Meaning | Do |
|---|---|---|
| `identical` | Reviewed at the current head | **No link.** Say nothing has changed since the review. |
| `ahead` | Clean new commits on top | Give both links (below). |
| `diverged` | Force-push, rebase, or base merged in | Give the compare link, and warn it also contains base-branch commits pulled in since the review. |

`diverged` is the common case on a long-lived branch, not an error.

### 4. Report

Both link forms, when they apply:

- `https://github.com/<owner>/<repo>/compare/<from>...<head>` — always resolves. What the user asked for. Include it.
- `https://github.com/<owner>/<repo>/pull/<PR>/files/<from>..<head>` — PR-scoped, hides base-branch noise, but **404s unless `status == "ahead"`**, because a force-pushed baseline is no longer in the PR's commit list. Only offer it on `ahead`.

Then the commits, so the size of the change is visible:

```bash
gh api repos/<owner>/<repo>/compare/<from>...<head> \
  --jq '.commits[] | "\(.sha[0:8]) \(.commit.message | split("\n")[0])"'
```

State whose review the baseline came from and when. "Since Sam's approval on Aug 19" is checkable; "since the last review" isn't.

## Quick Reference

| Step | Command |
|---|---|
| Head + base | `gh pr view <PR> --json headRefOid,baseRefOid` |
| Reviews with bot flag | `gh api repos/<O>/<R>/pulls/<PR>/reviews --jq '.[] \| "\(.user.type) \(.commit_id)"'` |
| Range summary | `gh api repos/<O>/<R>/compare/<from>...<head> --jq .status` |
| Commits in range | `gh api repos/<O>/<R>/compare/<from>...<head> --jq '.commits[].sha'` |

## Common Mistakes

- **Counting bot reviews.** CodeRabbit reviews every push, so its baseline is always the head — the answer becomes a permanent "nothing new".
- **Emitting a same-SHA link.** `compare/abc...abc` renders an empty diff. Check `status` first.
- **Two dots in the API.** REST compare only accepts `<a>...<b>`; `<a>..<b>` returns 404. Two dots work in the web UI only.
- **Offering the `/pull/N/files/` link after a force-push.** It 404s. Gate it on `status == "ahead"`.
- **Treating `diverged` as broken.** It just means base commits are in the range. Warn, don't bail.
- **Reading the newest review from array order.** Sort on `submitted_at`.

> Only if you run the `rtk` hook: it replaces `gh api` output with a JSON *schema* when `--jq` emits an object, turning SHAs into `string`. Every `--jq` above returns a flat string for that reason. Keep it that way, or route around it with `gh`.

Pairs with [`coderabbit-feedback`](../coderabbit-feedback/SKILL.md) and [`gh-actions-monitor`](../gh-actions-monitor/SKILL.md) for the rest of the review loop.
