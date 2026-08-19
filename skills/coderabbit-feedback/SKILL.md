---
name: coderabbit-feedback
description: Use when the user wants to check for CodeRabbit feedback on a PR, wait for the coderabbitai review, or make sure CodeRabbit reviewed a pull request — detects whether CodeRabbit was triggered, polls for its review, and posts "@coderabbitai review" to trigger it if it wasn't.
---

# CodeRabbit Feedback

## Overview

Make sure CodeRabbit (`coderabbitai[bot]`) has reviewed a PR and surface its feedback. If it was triggered, poll until the review lands. If it doesn't look triggered, post `@coderabbitai review` to kick it off, then poll.

Where CodeRabbit is installed it reviews PRs automatically on open/sync by default — but it can be paused, dismissed, or skipped, so verify rather than assume.

## Detecting whether CodeRabbit was triggered

CodeRabbit's presence on a PR = any of:
- An issue comment by `coderabbitai[bot]`
- A PR review by `coderabbitai[bot]`
- A CodeRabbit status check on the head commit

```bash
gh api repos/<owner>/<repo>/issues/<PR>/comments --jq '.[] | select(.user.login=="coderabbitai[bot]") | {id, created_at, snippet: .body[0:80]}'
gh api repos/<owner>/<repo>/pulls/<PR>/reviews  --jq '.[] | select(.user.login=="coderabbitai[bot]") | {state, submitted_at}'
gh pr checks <PR> | grep -i coderabbit
```

Judge every row **against the current head SHA** (`gh pr view <PR> --json headRefOid --jq .headRefOid`). Bot activity from an earlier sync stays on the PR forever, so an unqualified "has it reviewed?" is true from the second round onward.

| Observation (at head SHA) | Meaning | Action |
|-------------|---------|--------|
| No bot comment / review / check at all | **Not triggered** | Post the trigger comment (below), then poll |
| Bot activity exists, but only against an older commit | **Stale — not yet triggered for this push** | Treat as not triggered; poll, and re-trigger if it never starts |
| Bot comment exists but says it's in progress / no submitted review yet | **Triggered, running** | Poll |
| Bot review at the head SHA, or a comment with "Actionable comments posted" / a walkthrough summary | **Done** | Surface feedback |

## Triggering it

If not triggered, post the trigger comment:

```bash
gh pr comment <PR> --body "@coderabbitai review"
```

> Only if you run the `rtk` hook: it strips flags from `gh pr comment`, so route around it with `rtk proxy gh pr comment <PR> --body "@coderabbitai review"`.

This posts a public comment — it's the intended trigger, so post it without extra confirmation, but note it in the report.

## Polling

**Scope every check to the current head SHA.** A review from a previous sync is still on the PR, so "has the bot reviewed?" is always true after the first round — poll on that and you exit immediately and report stale feedback as fresh. Compare each review's `.commit_id` against `gh pr view <PR> --json headRefOid --jq .headRefOid`.

CodeRabbit takes a few minutes. You want **one** notification when the review lands, so run a bounded wait-loop in the **background** (`run_in_background`) — the harness re-invokes you when it exits:

```bash
head=$(gh pr view <PR> --json headRefOid --jq .headRefOid)
for i in $(seq 1 10); do
  gh api repos/<owner>/<repo>/pulls/<PR>/reviews \
    | jq -e --arg h "$head" \
        'any(.[]; .user.login=="coderabbitai[bot]" and .commit_id==$h)' >/dev/null && break
  sleep 60
done
```

Pipe to real `jq` here — `gh api --jq` takes a single filter string and won't accept `--arg`, so the SHA can't be passed in safely that way.

The `seq` bound caps the wait (~10 min) so the loop always exits — on success or on giving up. When re-invoked, re-run the detection checks: if still not **Done**, report "still running" and offer to keep waiting.

Don't foreground this (blocked), and don't poll faster than the bot works. If you'd rather be told about each comment as it lands instead of once at the end, use `Monitor` with a poll loop that emits new comments and exits when the review is submitted. Give it `timeout_ms` room — see below.

## Surfacing feedback

When done, present CodeRabbit's review:
- The summary / walkthrough.
- Actionable line comments. Show **only unresolved/active** ones (skip resolved/outdated threads).

Resolution state is **not** in the REST comments API — `repos/<o>/<r>/pulls/<PR>/comments` returns every review comment with no resolved field, so it cannot answer "unresolved". That lives on GraphQL `reviewThreads.isResolved`:

```bash
gh api graphql -f owner=<owner> -f repo=<repo> -F pr=<PR> -f query='
  query($owner:String!, $repo:String!, $pr:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first:100) {
          nodes {
            isResolved
            isOutdated
            path
            line
            comments(first:1) { nodes { author { login } body } }
          }
        }
      }
    }
  }' --jq '.data.repository.pullRequest.reviewThreads.nodes[]
           | select(.isResolved | not) | select(.isOutdated | not)
           | select(.comments.nodes[0].author.login | test("coderabbitai"))
           | {path, line, body: .comments.nodes[0].body[0:200]}'
```

Two gotchas: bot logins differ by API — REST gives `coderabbitai[bot]`, GraphQL gives `coderabbitai`, hence `test(...)` rather than `==`. And `reviewThreads(first:100)` truncates silently on a large PR; page it if the count looks capped.

Use REST only where resolution doesn't matter (detecting presence, reading the walkthrough).

Report concisely — group by file, one line per actionable item; don't paste CodeRabbit's full collapsible boilerplate.

If you watch with `Monitor` instead of the background loop, set `timeout_ms` explicitly: the 300000 (5 min) default is shorter than CodeRabbit often takes, and a monitor killed at the deadline just goes silent — which reads as "still running". Max is 3600000 (60 min); `persistent: true` runs for the session, ended with `TaskStop`.

## Quick Reference

| Step | Command |
|------|---------|
| Bot comments | `gh api repos/<o>/<r>/issues/<PR>/comments --jq '.[]\|select(.user.login=="coderabbitai[bot]")'` |
| Bot reviews | `gh api repos/<o>/<r>/pulls/<PR>/reviews --jq '.[]\|select(.user.login=="coderabbitai[bot]")'` |
| Trigger | `gh pr comment <PR> --body "@coderabbitai review"` (prefix `rtk proxy` only under the rtk hook) |
| Inline comments (all) | `gh api repos/<o>/<r>/pulls/<PR>/comments --jq '.[]\|select(.user.login=="coderabbitai[bot]")'` |
| Unresolved threads only | GraphQL `reviewThreads { isResolved }` — see [Surfacing feedback](#surfacing-feedback); REST can't do this |

## Common Mistakes

- **Assuming it auto-ran** — verify bot presence; it can be paused/dismissed.
- **`--body` silently dropped** — only under the rtk hook, which strips the flag; prefix with `rtk proxy`. Not applicable without that hook.
- **Polling faster than the bot works** — CodeRabbit needs minutes; 30s polls burn turns and find nothing. Space checks to its actual latency, and cap them.
- **An unbounded loop in background Bash** — the notification comes from the process *exiting*, so a `while true` with no break means you're never re-invoked. Bound it so it ends either way. (Under `Monitor` the rule inverts: there each output line is its own event and `timeout_ms` supplies the bound, so a `while true` that breaks on the terminal state is correct — see [`gh-actions-monitor`](../gh-actions-monitor/SKILL.md).)
- **Dumping boilerplate** — surface only actionable, unresolved items.
- **Filtering "unresolved" via REST** — that field doesn't exist there; you'd silently re-surface threads the author already resolved. Use the GraphQL query.
- **Re-triggering when already running** — a bot comment with no submitted review yet means it's working; poll, don't re-post.
- **Matching a review from an earlier push** — the previous sync's review never leaves the PR, so an unscoped check exits the poll on iteration 1 and reports stale feedback as fresh. Always compare `.commit_id` to the head SHA.

Pairs with [`gh-actions-monitor`](../gh-actions-monitor/SKILL.md) for watching CI on the same PR.
