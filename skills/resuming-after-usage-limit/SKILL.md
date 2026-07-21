---
name: resuming-after-usage-limit
description: Use when a task is long enough to run out of usage before finishing, or when you're about to hit a usage/rate limit mid-task and need the work to pick back up automatically once the limit resets.
---

# Resuming After Usage Limit

## Overview

A local session can't wake itself up — once usage is exhausted, no more tool calls happen until reset, and nothing schedules the continuation for you. The fix: before (or as) you hit the wall, checkpoint progress somewhere durable, then schedule a **cloud** routine (via the `schedule` skill / `RemoteTrigger` tool) to fire once at the reset time and pick the work back up.

**REQUIRED SUB-SKILL:** Use `schedule` for the actual routine create/list/update mechanics.

## Key Constraint

Cloud routines run in an isolated sandbox with a fresh git clone — **zero local context, zero local files.** Two consequences:

1. The checkpoint must live somewhere the cloud agent can reach: committed and pushed to the repo (preferred), or inlined directly in the routine prompt if it's short.
2. The task must be doable from a git checkout alone. If it depends on local-only state (uncommitted files, a local server, local env vars), this pattern doesn't apply — resume manually after reset instead.

## Workflow

1. **Checkpoint before you run out.** Write (and commit/push) a short progress note: what's done, what's left as concrete steps, any decisions made and why, exact file paths touched. Don't rely on the cloud agent inferring intent from a diff.
2. **Get the reset time.** The app surfaces this when a limit is hit ("resets at 3pm"). Ask the user if it's not already stated — don't guess.
3. **Invoke `schedule`** to create a **one-time** routine (`run_once_at`, not `cron_expression` — this fires once then auto-disables):
   - `session_context.sources`: the repo the checkpoint was pushed to
   - prompt: fully self-contained — repo/branch, path to the checkpoint file (or its content inlined), and the exact remaining steps. The cloud agent has no memory of this conversation.
   - confirm the UTC conversion for the reset time before creating it
4. **Tell the user** the routine was created and link `https://claude.ai/code/routines/{id}` so they can check on it.

## Common Mistakes

- Scheduling the routine before the checkpoint is pushed — the cloud clone won't have it.
- Writing the checkpoint as a diff/summary of what happened instead of what's left to do — the next agent needs a task list, not a changelog.
- Using `cron_expression` for what's actually a single resume-once event — leaves a recurring routine running after the task is done.
- Assuming the cloud agent can touch local files, run local servers, or see uncommitted changes — it can't.
