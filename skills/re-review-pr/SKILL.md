---
name: re-review-pr
description: Use when the user already reviewed a pull request and wants to re-review it — check whether the feedback they left was addressed by the commits pushed since their last review, catch up on a PR they reviewed a while ago, or find changes the author made that nobody asked for.
---

# Re-Review PR

## Overview

You reviewed a PR. The author pushed more commits. Two narrow questions — not "is this code good":

1. Did each thing you asked for actually happen?
2. What else changed that you didn't ask for?

Answer both from the diff. "Fixed in 2a2676c" is a claim; a hunk in the range is evidence.

Scope is one PR and the commits since **your** last review. This skill reports — it never posts comments and never approves.

## Workflow

### 1. Resolve the baseline

`<PR>` may be a number, URL, or omitted (current branch). Everything below also accepts `--repo <O>/<R>`.

```bash
gh api user --jq .login
gh pr view <PR> --json url,author,headRefOid,baseRefOid --jq '"\(.url) \(.author.login) \(.headRefOid) \(.baseRefOid)"'
gh api repos/<O>/<R>/pulls/<PR>/reviews \
  --jq '.[] | select(.state != "PENDING") | select(.user.login == "<me>") | "\(.submitted_at) \(.state) \(.commit_id)"'
```

Baseline = `commit_id` of your latest **submitted** review, sorted on `submitted_at`.

| Situation | Do |
|---|---|
| No submitted review by you | Stop. Nothing to follow up on — this is a first review, so run a full review instead. |
| Only a `PENDING` review by you | Stop. Pending means unsubmitted; the author never saw it. Finish that review instead. |
| A newer review by someone else | Ignore it. You're auditing your asks, so the baseline is yours. |
| Compare says `identical` | Stop. Nothing has changed since you looked. |

### 2. Gather your asks

GraphQL returns threads, replies, and resolution state in one call — use it for inline comments:

```bash
gh api graphql -f query='
{ repository(owner: "<O>", name: "<R>") {
    pullRequest(number: <PR>) {
      reviewThreads(first: 50) { nodes {
        isResolved isOutdated path line
        comments(first: 10) { nodes { author { login } createdAt body } } } } } } }' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[]
        | select(.comments.nodes[0].author.login == "<me>")
        | "resolved=\(.isResolved) \(.path):\(.line) \(.comments.nodes[0].body)"'
```

Plus review bodies and PR-level comments, both filtered to you:

```bash
gh api repos/<O>/<R>/pulls/<PR>/reviews  --jq '.[] | select(.user.login=="<me>") | select(.body != "") | "\(.submitted_at) \(.body)"'
gh api repos/<O>/<R>/issues/<PR>/comments --paginate --jq '.[] | select(.user.login=="<me>") | "\(.created_at) \(.body)"'
```

Then split into discrete, numbered asks:

- One comment often holds several asks. Number each separately — a comment that got half-answered is `Partial`, but its two asks are `Addressed` and `Not addressed`.
- Keep your own severity marker (`**Important**`, `**Minor**`) and sort the report by it.
- **Asks you posted after the baseline review still count.** The baseline sets the diff range; it does not decide which asks are open.
- Default to asks from your latest review onward. Widen to every ask on the PR when that review didn't repeat still-open earlier asks, or when the user asks for a full audit.

### 3. Pull the range

```bash
gh api repos/<O>/<R>/compare/<baseline>...<head> --jq '"status=\(.status) ahead=\(.ahead_by) behind=\(.behind_by) commits=\(.total_commits) files=\(.files|length)"'
gh api repos/<O>/<R>/compare/<baseline>...<head> --jq '.commits[] | "\(.sha[0:8]) \(.commit.message | split("\n")[0])"'
gh api repos/<O>/<R>/compare/<baseline>...<head> --jq '.files[] | "\(.status) +\(.additions)/-\(.deletions) \(.filename)"'
gh api repos/<O>/<R>/compare/<baseline>...<head> --jq '.files[] | select(.filename == "<path>") | .patch'
```

Patches come back inline, so one endpoint covers commits, files, and hunks. Compare caps at 300 files and omits `patch` on very large ones — fall back to `gh pr diff <PR>` or `git diff <baseline>...<head> -- <path>`.

| `status` | Meaning |
|---|---|
| `identical` | Reviewed at the current head. Stop. |
| `ahead` | Clean new commits. Normal case. |
| `diverged` | Force-push, rebase, or base merged in. The range also holds base-branch commits — don't attribute those to the author. |

### 4. Verdict per ask

Read the patch at each ask's `path`. Assign exactly one verdict, each with evidence:

| Verdict | Means | Evidence |
|---|---|---|
| `Addressed` | The change does what you asked | `file:line` in the range |
| `Partial` | Some of it landed | what's still missing |
| `Not addressed` | Path untouched, or the hunk misses the concern | the absence, stated plainly |
| `Declined` | Author replied explaining why not | quote the reply |
| `Moot` | The code is gone | the hunk that removed it |

No verdict without evidence. An unresolved thread is not `Not addressed` — teams routinely leave threads unresolved on PRs that were fully addressed and merged. Treat `isResolved` as a hint about intent, never as the verdict.

### 5. Flag what nobody asked for

Start from files in the range that carry no ask, then **subtract consequences** — a new test file, a helper extraction, or a rename that the requested fix required is a response, not scope creep. Check whether each unmapped change traces back to an ask before flagging it.

| Bucket | Examples | Report |
|---|---|---|
| Risky | auth, migrations, deps/lockfiles, deleted tests, public API, config | Always, first, however small |
| Scope creep | new behavior, endpoint, flag, dependency | Always, with the hunk |
| Consequential | refactor the requested fix dragged in | One line, naming the ask it serves |
| Incidental | formatting, import order, comment typos | One grouped line |

If nothing is unrequested, say so explicitly. Never let an empty bucket pass as silence.

### 6. Report

1. **Verdict line** — "7 of 9 asks addressed; 3 unrequested changes, 1 risky" plus a ship / hold call.
2. **Ask table** — `# | Severity | File:line | Ask | Verdict | Evidence`, numbered `1..N` after sorting, so the user can point at findings by number.
3. **Unrequested changes** — `# | Bucket | File:line | What changed | Why flagged`.
4. **Range footer** — `https://github.com/<O>/<R>/compare/<baseline>...<head>`, the commit list, and whose review the baseline is plus when ("since your review of Aug 17"). Add `https://github.com/<O>/<R>/pull/<PR>/files/<baseline>..<head>` only when `status == "ahead"` — it 404s otherwise.

Stop there. Posting comments and approving are separate, deliberate steps — hand over the numbered findings and let the user pick what to act on.

## Quick Reference

| Step | Command |
|---|---|
| Your login | `gh api user --jq .login` |
| Your reviews | `gh api repos/<O>/<R>/pulls/<PR>/reviews --jq '.[] \| select(.state != "PENDING") \| "\(.user.login) \(.commit_id)"'` |
| Your threads + replies | `gh api graphql` → `reviewThreads` (see step 2) |
| Range summary | `gh api repos/<O>/<R>/compare/<baseline>...<head> --jq .status` |
| Hunks for a file | `gh api repos/<O>/<R>/compare/<baseline>...<head> --jq '.files[] \| select(.filename=="<path>") \| .patch'` |

## Common Mistakes

- **Baselining on someone else's review.** The asks are yours, so the baseline is your latest submitted review.
- **Counting a `PENDING` review.** Its `submitted_at` is `null`, it sorts unpredictably, and the author never saw it. Filter `state != "PENDING"` before sorting.
- **Reading thread resolution as the verdict.** Unresolved threads sit on plenty of addressed, approved, merged PRs. Check the diff.
- **Accepting "fixed in abc123".** Confirm that sha is in the range and the hunk does what the reply claims.
- **Flagging every unmapped file as unrequested.** A new test file with no comment on it is usually the answer to a test-coverage ask. Subtract consequences first.
- **Dropping asks posted after the baseline review.** They're your newest feedback, not out of scope.
- **Blaming the author for base commits on a `diverged` range.**
- **Two dots in the REST compare path.** Only `<a>...<b>` works; `<a>..<b>` 404s outside the web UI.
- **Auditing your own PR.** Your inline comments there are usually self-annotations ("Deferred: …", "Intentionally retained: …"), not asks. Confirm before treating them as feedback.
- **Reviewing the new code on its merits.** That's a fresh review — this pass is the feedback audit plus unrequested changes. Offer the full review separately.

> Only if you run the `rtk` hook: it replaces `gh api` output with a JSON *schema* when `--jq` emits an object, turning SHAs into `string`. Every `--jq` above returns a flat string for that reason. Keep it that way, or route around it with `gh`.

Baseline resolution is shared with [`pr-diff-since-review`](../pr-diff-since-review/SKILL.md), which turns the same range into a link for someone else to read. [`coderabbit-feedback`](../coderabbit-feedback/SKILL.md) covers the bot side of the loop.
