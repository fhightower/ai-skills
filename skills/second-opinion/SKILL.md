---
name: second-opinion
description: Use when the user wants a question double-checked by another model before acting — "get a second opinion", "ask another model", "do two agents agree on this", "sanity-check this answer", or before a decision that is expensive to reverse. Runs the same question past two differently-modeled subagents and reports whether they agree.
---

# Second Opinion

## Overview

One question, two subagents on **different models**, one consolidated answer that says plainly whether they agreed.

The value is in the disagreement. Agreement tells you little — two Claude models share training and failure modes, so they fail together on the same hard questions. Disagreement is the signal worth paying for: it marks the exact spot where the answer is not as settled as one agent made it sound.

Three rules make the comparison mean anything:

1. **Identical prompts.** Different prompts produce different answers for reasons that have nothing to do with the models.
2. **Different models.** Same model twice is sampling noise, not a second opinion.
3. **No cross-talk.** Neither agent sees the other's answer, or yours.

Break any one of them and the output is theater.

## When NOT to use

- **A command would answer it.** Run the command. Two agents guessing at what `pytest -q` prints is worse than running it.
- **It is the user's preference to make**, not a fact to determine ("should we use tabs").
- **It is a task, not a question.** This dispatches two answerers, not two implementers. Never send file-modifying work through it — two agents editing the same tree collide.
- **You need many perspectives at scale** (audits, exhaustive bug hunts). That is a judge-panel workflow, not this.

## Workflow

### 1. Pick the two models

Agent A inherits the session model — omit `model`. Agent B overrides it a different model that is the most capable model available.

### 2. Write one prompt, use it twice

Subagents inherit no context, so the prompt carries everything. Write it once and pass the identical string to both.

```
<question>
[the user's question, verbatim — not your paraphrase of it]
</question>

<context>
Repo: /abs/path
Look at: path/to/file.ts:120-180, path/to/other.py:44
Constraints the answer must respect: [runtime, deps, compat, deadlines]
Already ruled out: [only what the user ruled out, with their reason]
</context>

Answer independently. Read what you need before answering; do not answer from
assumption. Do not modify, create, or delete any file.

Return exactly these sections, in this order:

VERDICT: one sentence. The answer as a decision, not a survey of options.
CONFIDENCE: high | medium | low.
WHY: at most 5 bullets. Each cites a file:line or a named, checkable fact.
KEY ASSUMPTION: the one thing that, if false, flips your verdict.
DISCARDED: the strongest answer you rejected, and why you rejected it.
```

Point at evidence, never at conclusions. "Look at `auth.ts:88`" is context. "`auth.ts:88` is where the bug is" is your answer wearing a costume — both agents will now agree with you, and the agreement is worthless.

`DISCARDED` is what makes consolidation cheap: when A's `VERDICT` is B's `DISCARDED`, you have a sharp, locatable disagreement instead of two essays to compare.

### 3. Dispatch both in one message

Both `Agent` calls go in a **single** response, so they run concurrently — wall clock is the slower agent, not the sum. Same `subagent_type` for both (`general-purpose` unless the question is domain-specific), so the only difference between them is the model.

Sequential dispatch, or feeding A's answer to B, produces a review of A — correlated by construction, and no longer a second opinion.

### 4. Validate before comparing

A bad answer is not a data point. Check each one first:

| Symptom | Do |
|---|---|
| Answered a different question | Prompt was ambiguous. Fix it, re-run both. |
| No citations, pure assertion | Re-run that agent. Do not weigh it against a cited answer. |
| Returned `null` (died or was skipped) | Re-dispatch it. One opinion is not a second opinion — never report a solo answer as a consensus. |
| Ignored a stated constraint | Discard that verdict; the constraint was in the prompt. |

### 5. Consolidate on the verdict

Compare **verdicts**, not wording. Two agents can say the same thing in prose so different it reads as conflict.

| Pattern | Means | Report |
|---|---|---|
| Same verdict, different `WHY` | Independently reached — the strongest signal this skill can produce | **Agree** |
| Same verdict, same `WHY` | Convergent, possibly correlated | **Agree**, note it is one line of reasoning, not two |
| Same verdict, split confidence | Agreement; the cautious one usually names the real risk | **Agree**, carry that caveat forward |
| Different verdict | Genuine disagreement | **Disagree** — go to step 6 |
| A's verdict is B's `DISCARDED` | Direct contradiction on a known fork | **Disagree** — the crux is already named for you |
| Same verdict, conflicting `KEY ASSUMPTION` | Fragile agreement — one of them is wrong about the premise | **Agree, unstable** — check the assumption |

### 6. Resolve the disagreement you can

Name the **crux**: the one fact or judgment where they part. Then classify it.

- **Factual crux** (what the code does, what a version supports, what a test returns) → **check it yourself, now.** Read the file, run the command. Report who was right with the evidence. A disagreement you could have settled in thirty seconds is not a finding to hand upward.
- **Judgment crux** (which trade-off wins, how much a risk is worth) → not yours to settle. Present both cases at their strongest, then state your own read **labeled as yours**, and leave the call with the user.

Never average two verdicts into a hedge neither agent endorsed. The mushy middle is an answer nobody argued for.

### 7. Report

1. **Headline** — `Agree` / `Agree, unstable` / `Disagree`, then the answer in one sentence, then the models by name (`opus-5` + `fable-5`).
2. **The verdicts** — one row each: `Model | Verdict | Confidence`.
3. **If they disagree** — the crux in one sentence, its type, and either the resolution with evidence or the open call with a recommendation.
4. **The load-bearing assumption** — the `KEY ASSUMPTION` that most affects the answer, and whether it holds.
5. **What agreement does not mean** — one line, whenever they agree: two Claude models agreeing means no cheap disagreement surfaced, not that the answer is verified.

## Quick Reference

| Step | Action |
|---|---|
| Models | A: omit `model`. B: `model: "fable"` (or `"opus"` from a Fable session) |
| Prompt | One string, byte-identical for both, evidence pointers only |
| Dispatch | Both `Agent` calls in one message, same `subagent_type` |
| Compare | `VERDICT` first; `DISCARDED` locates the fork |
| Factual crux | Check it yourself; report who was right |
| Judgment crux | Both cases, your read labeled, user decides |

## Red Flags — STOP

- Prompts differ between A and B → the comparison measures the prompts.
- Your own lean, hypothesis, or preferred answer is in the prompt → you manufactured the agreement.
- `subagent_type: "fork"` on agent B → forks ignore `model`. Two same-model agents, silently.
- Second dispatch happens after the first returns → that is a review of A.
- Reporting "both agreed, so it's right" → agreement is not verification.
- One agent came back empty and you reported the other as the answer.
- Splitting a real disagreement into a compromise verdict.

## Rationalization Table

| Excuse | Reality |
|--------|---------|
| "I'll tighten B's prompt, A misunderstood" | Then re-run **both** on the tightened prompt. Asymmetric prompts void the result. |
| "Telling them what I suspect saves time" | It buys you your own answer back, twice. |
| "Both agreed, so we're done" | Same family, same blind spots. Agreement is the weak outcome, not the win. |
| "They disagree, so I'll pick the better-argued one" | If the crux is factual, go check it. Rhetoric is not evidence. |
| "Fable is smaller, so A wins ties" | Model size does not adjudicate facts. Check the crux. |
| "Averaging both is the balanced answer" | Neither agent endorsed the average. |
| "Fable isn't available, two Opus agents is close enough" | Same model twice is sampling noise. Say the override failed. |
| "Just let B review A's answer" | Anchored to A. That is review, not independence. |

## Common Mistakes

- **Paraphrasing the question.** Your paraphrase already narrows the answer. Pass it verbatim.
- **Sending conclusions as context.** Pointers to evidence are context; claims about that evidence are contamination.
- **Comparing prose instead of verdicts.** Two identical calls, worded differently, are agreement.
- **Forgetting the session model.** From a Fable session, `model: "fable"` on B silently collapses the experiment.
- **Escalating a resolvable disagreement.** Factual cruxes are yours to settle before reporting.
- **Letting your own opinion break the tie unlabeled.** You are the consolidator, not a third vote. Say when it is you talking.
- **Using it on work, not questions.** Two agents editing one tree conflict; keep both read-only.
- **Hiding the cost.** Two full agents is roughly double one agent's tokens. Worth it before an expensive decision, waste on a question a command answers.
