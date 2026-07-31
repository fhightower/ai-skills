---
name: resume-after-usage-limit
description: Use when a task is long enough to run out of usage before finishing, or when you're about to hit a usage/rate limit mid-task and need this session to pick the work back up automatically once the limit resets.
---

# Resume After Usage Limit

## Overview

A session can't wake itself up on its own — once usage is exhausted, no more tool calls happen until reset, and nothing restarts the work for you. The fix: before you run out, schedule a **one-shot local cron job** (`CronCreate` with `recurring: false`) that fires just after the reset time and enqueues a prompt telling this same session to continue.

This keeps the work local: same machine, same working tree, same uncommitted changes, same running processes. Nothing has to be committed or pushed.

## Key Constraints

`CronCreate` jobs are **session-only and in-memory**. Consequences:

1. The terminal and Claude session must stay open until the job fires. Closing Claude discards the job silently.
2. Jobs fire only while the REPL is **idle** — fine here, since the session is sitting blocked on the limit.
3. Context may be compacted between now and the reset. Don't assume the future turn remembers this conversation — put the task description in the cron prompt itself.

If the session can't be left open (machine shutting down, ephemeral shell), this pattern doesn't apply — either resume manually after reset, or schedule a cloud routine via the `schedule` skill instead.

## Workflow

1. **Schedule before you're fully out.** Creating the job costs a tool call; don't wait until you can't make one.
2. **Get the reset time.** The app surfaces it when a limit is hit ("resets at 3pm"). Ask the user if it isn't already stated — don't guess.
3. **Pick a fire time a few minutes _after_ reset**, on an off-minute. One-shot jobs landing on `:00` or `:30` can fire up to **90 seconds early**, which would land back inside the limit. For a 3pm reset, use `04 15 <dom> <month> *`, not `0 15 …`.
4. **Create the job** with `CronCreate`:
   - `recurring: false` — fires once, then auto-deletes
   - `cron`: minute / hour / day-of-month / month all pinned, day-of-week `*`
   - times are **local**, not UTC — no conversion
   - `prompt`: self-contained. State the working directory, the branch, what's already done, and the exact remaining steps. Write it as a task list for a fresh reader, not a changelog of what happened.
5. **Write a checkpoint file** if the remaining work is more than a few steps — a scratch file with decisions made and why, then reference its path from the cron prompt. Keeps the prompt short and survives compaction.
6. **Confirm to the user**: the fire time, that the session must stay open, and that `CronList` shows pending jobs while `CronDelete` cancels one.

## Common Mistakes

- Waiting until usage is fully exhausted to schedule — no tool calls left to schedule with.
- Scheduling at the exact reset minute, or on `:00`/`:30` — early-fire jitter puts the run back inside the limit.
- Writing the prompt as "continue what we were doing" — after compaction there may be no "what we were doing" left. Spell out the steps.
- Using `recurring: true` for a single resume event — leaves a job re-firing for a week.
- Forgetting to tell the user the session must stay open; a closed terminal drops the job with no warning.
- Converting the reset time to UTC — `CronCreate` already uses local time.
