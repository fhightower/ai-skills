---
name: proofreading-prose
description: Use when asked to check, proofread, or review a document, blog post, or other prose file for typos, spelling, or grammar issues, or when asked to fix such issues after they were identified.
---

# Proofreading Prose

## Overview

Systematic grammar/typo review for prose files (blog posts, docs, articles). Report findings before editing; only apply what's confirmed.

## When to Use

- "Any grammar issues in X?" / "proofread this" / "check for typos"
- Follow-up "make those changes" after issues were listed
- Follow-up "reread" / "one more pass" after user edits a file

## Workflow

1. **Read the whole file fresh** — never rely on a cached view. The user may have hand-edited it since your last read (a system-reminder will show the diff if so — trust that over memory).
2. **List issues by line number**, quoting the exact fragment and its fix (`"distiction" → "distinction"`). Separate hard errors (misspellings, subject-verb agreement, punctuation) from style nits (awkward phrasing, word choice) — label the nits as optional.
3. **Don't edit yet.** Ask which to apply, unless the user already said "fix them" / "make those changes."
4. **Apply only confirmed fixes** with Edit — exact old_string/new_string per issue, not a rewrite of the surrounding prose.
5. **On any follow-up pass** ("reread", "anything else?", "one more pass"), re-read the full file from disk before answering — don't diff against what you remember writing.

## Common Mistakes

- Reporting from memory instead of re-reading after the user says they made changes.
- Bundling style preferences in with actual errors without labeling which is which.
- Rewriting a whole sentence via Edit when only one word is wrong — makes the diff noisy and risks touching text the user didn't ask about.
