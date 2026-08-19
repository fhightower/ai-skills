---
name: gh-actions-monitor
description: Use when the user wants to watch CI on a PR, monitor GitHub Actions / checks for a pull request, wait for the build to finish, or be told when checks pass or fail — watches the PR's check runs and surfaces the cause of any failure.
---

# GitHub Actions Monitor

## Overview

Watch the GitHub Actions / status checks on a pull request until they settle, then report pass/fail — and for failures, pull the failing job's logs and summarize the cause.

Don't busy-wait with foreground `sleep` (blocked in this environment). Run `gh pr checks --watch` in the background — the harness re-invokes you when it exits — or use `Monitor` for per-check updates.

## Workflow

### 1. Resolve the PR and snapshot

```bash
gh pr checks <PR>                      # table: each check + state (pass/fail/pending) + link
gh pr view <PR> --json headRefName,statusCheckRollup --jq '.statusCheckRollup'
```

If everything is already terminal (all pass / some fail), skip to step 3.

### 2. Watch until done

Run in the **background** so the harness notifies you on exit (exits non-zero if any check fails):

```bash
gh pr checks <PR> --watch --interval 30
```

That gives you **one** notification, when everything is terminal.

If you'd rather hear about **each check as it lands**, use `Monitor` with a poll loop that emits newly-settled checks and exits once nothing is pending.

**Set `timeout_ms`.** It defaults to 300000 (5 min) — shorter than most CI suites — and a monitor killed at the deadline goes quiet, which is indistinguishable from "still pending". Size it to the suite (max 3600000 / 60 min), or pass `persistent: true` to run for the session and stop it with `TaskStop`.

```bash
prev=""
while true; do
  s=$(gh pr checks <PR> --json name,bucket)
  cur=$(jq -r '.[] | select(.bucket!="pending") | "\(.name): \(.bucket)"' <<<"$s" | sort)
  comm -13 <(echo "$prev") <(echo "$cur")
  prev=$cur
  jq -e 'all(.bucket!="pending")' <<<"$s" >/dev/null && break
  sleep 30
done
```

`while true` is right *here* and wrong in a background Bash wait-loop, because the two get their notifications differently. Under `Monitor`, every stdout line is already an event, so the loop only needs to stop once checks are terminal — and `timeout_ms` bounds it regardless. A background Bash loop notifies you by **exiting**, so an unbounded one never reports at all; those need their own bound (see the wait-loop in [`coderabbit-feedback`](../coderabbit-feedback/SKILL.md)).

Match any poll interval to how fast the checks actually move — a suite that takes ~8 minutes doesn't need a check every 30s. Keep remote polls at 30s+ to stay clear of rate limits.

### 3. On failure, find the cause

Identify the failing run and pull only the failed steps' logs:

```bash
gh run list --branch <headRefName> --limit 5 --json databaseId,workflowName,conclusion,headSha
gh run view <run-id> --log-failed
```

Summarize: which workflow/job failed, the error, and the likely fix. Don't paste the whole log — extract the failing assertion/error lines.

### 4. Report

Per-check status (✓/✗/pending). For failures: workflow + job + cause + suggested fix. If checks are still pending after the watch window, say so and offer to keep watching.

## Quick Reference

| Step | Command |
|------|---------|
| Snapshot | `gh pr checks <PR>` |
| Watch (background) | `gh pr checks <PR> --watch --interval 30` |
| List runs for branch | `gh run list --branch <head> --json databaseId,workflowName,conclusion,headSha` |
| Failed logs only | `gh run view <run-id> --log-failed` |

## Common Mistakes

- **Foreground `sleep` loops** — blocked; background the `--watch`, or use `Monitor`.
- **`Monitor` for a single notification** — an unbounded watch stays armed until timeout after the event fires. One notification → background `--watch` (it exits on its own).
- **Dumping full logs** — use `--log-failed` and extract the error lines.
- **Reporting "pending" as done** — `--watch` exits when terminal; a snapshot may still be running.
- **Wrong run** — match the run to the PR head SHA (`headRefName`/`headSha`), not just the latest run on the branch.

Pairs with [`coderabbit-feedback`](../coderabbit-feedback/SKILL.md) for watching the review bot on the same PR.
