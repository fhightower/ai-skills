---
name: write-for-humans
description: Use when producing content a person will read — a README, PR or issue description, release notes, status report, summary, design doc, commit body, or a final answer — and it should be direct, skimmable, and free of padding. Also use when a caller asks for output that is human-readable, plain, concise, or "not an essay". Not for creative, marketing, or persuasive copy.
---

# Write for Humans

## Overview

Two published skills already encode the rules. This skill exists so an agent reaches for both, in the right order, for anything a person will read.

| Skill | Covers | Source |
|---|---|---|
| `i-have-adhd` | **Shape** — lead with the action, number the steps, cut preamble and closers, cap lists, restate state, make the outcome visible | [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) |
| `asd-ste100` | **Sentences** — active voice, simple tenses, one meaning per word, short sentences, no jargon padding | [danyuchn/asd-ste100-skill](https://github.com/danyuchn/asd-ste100-skill) |

Shape first, then wording. Fixing sentences inside a badly ordered document wastes the pass.

## Workflow

1. **Invoke `i-have-adhd`** and lay out the content: the point or the next action goes first, multi-step work becomes a numbered list, anything still open ends as one concrete next step.
2. **Invoke `asd-ste100`** on the drafted text. Pick the mode:
   - **Strict** — text a machine parses or a person must not misread: error messages, tool descriptions, instructions to another agent, safety or migration steps.
   - **STE-flavored** — prose a person reads: READMEs, PR descriptions, changelogs, reports, summaries.
3. **On conflict, `i-have-adhd` wins.** `asd-ste100` defers to it by its own rule.
4. **Delete** before returning: the opening sentence if it announces what you are about to do, the closing sentence if it recaps or asks "anything else?", any "by the way" sidebar, any idiom, and any hedging adverb carrying no real uncertainty.

Both skills are content-shaping, not content-generating. Draft the substance first; these passes fix how it reads, not whether it is true or complete.

## When Not to Use

- Creative, marketing, or persuasive copy. Voice is the point there, and both skills flatten it.
- Text where the required register is set by someone else — a legal notice, a customer-facing template, a document with a house style guide.

## Common Mistakes

- **Shortening past clarity.** The goal is removing ambiguity, not cutting words. Stop when the sentence has one reading, not when it is shortest.
- **Dropping a hedge.** "May have failed" is not "failed". A shorter sentence that upgrades a hedge to a fact is a different claim, not a simplification.
- **Cutting a condition or a number to hit a length cap.** Keep the longer phrasing and say why.
- **Running the sentence pass before the structure pass.** Reordering afterward re-breaks the sentences you just fixed.
- **Polishing hollow content.** These passes fix form, not substance. Weak content becomes short, clean, weak content — say the content is thin instead.
