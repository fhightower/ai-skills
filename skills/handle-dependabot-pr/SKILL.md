---
name: handle-dependabot-pr
description: Use when handling, reviewing, or triaging a Dependabot pull request — classifying the dependency, checking CI, investigating the upgrade, and applying consistent version-range handling before commenting (never merging).
---

# Handle Dependabot PR

## Overview

Triage a Dependabot PR with consistent version-range handling. Classify the
dependency, check CI, investigate breaking changes, adjust the range per the rules
below, then commit and comment. **Never merge.**

## Input

PR number: `$ARGUMENTS`

## Steps

### 1. Fetch PR details

Use `gh pr view $ARGUMENTS` to get the title, body, changed files, and CI status.
Identify which dependency is being updated and the proposed version change.

### 2. Classify the dependency

Determine whether the dependency is **dev** or **non-dev (production)** by checking
the project's dependency configuration (e.g., `pyproject.toml`):

- **Non-dev (production)**: listed under `[project] dependencies` (or equivalent
  production deps section)
- **Dev**: listed under `[dependency-groups] dev`,
  `[project.optional-dependencies] dev`, or a similar dev/test section

### 3. Check CI status

Run `gh pr checks $ARGUMENTS`.

- If all checks pass: note this and continue.
- If any check is **failing**: investigate. Read the failing check logs. Decide
  whether the failure is caused by the upgrade or is flaky/unrelated. Report your
  findings. **Do not merge if CI is red unless you can confirm the failure is
  unrelated to this upgrade** (and this skill never merges anyway).

### 4. Investigate the upgrade

Check the dependency's changelog and/or release notes for breaking changes between
the old and new versions.

- **Dev dependencies**: normal investigation — skim the changelog for obvious
  breaking changes.
- **Non-dev (production) dependencies**: investigate thoroughly. Larger blast
  radius. Read the changelog carefully; look for migration guides, deprecation
  notices, and breaking changes.

### 5. Adjust the version range

Dependabot often just widens the upper bound. Apply these rules instead:

**Non-dev (production) dependencies — expand the upper bound only:**
- Keep the existing lower bound unchanged.
- Bump the upper-bound major version up by one.
- Example: `>=4.1.0,<7.0` becomes `>=4.1.0,<8.0`
- This purely widens the supported range — no existing consumers lose support.

**Dev dependencies — upgrade the range:**
- Drop the old lower bound and set a tight range around the new major version.
- Example: `>=4.1.0,<7.0` becomes `>=7.0,<8.0`
- The lower bound becomes what was the old upper bound (the new major version), and
  the upper bound is the next major above that.

After determining the correct new range, edit the dependency file (e.g.,
`pyproject.toml`) to use the adjusted range instead of whatever Dependabot proposed.
Commit this change to the PR branch.

If the range was changed from what Dependabot proposed, update the PR title with
`gh pr edit $ARGUMENTS --title "<new title>"`.

### 6. Commit and comment

Commit the version-range fix and any other fixes (CI failures, breaking changes) to
the PR branch. **Do NOT merge the PR.**

Leave a short comment on the PR summarizing:
- Whether it's a dev or non-dev dependency
- CI status
- Any notable changelog findings (breaking changes, deprecations)
- What version-range adjustment was made and why

## Common Mistakes

- Sliding the production lower bound up — the rule is expand-only, keep the lower
  bound where it is.
- Applying the dev "upgrade" rule to a production dependency (or vice versa) — always
  classify first (step 2).
- Merging the PR. This skill stops at commit + comment.
