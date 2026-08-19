# ai-skills

A collection of [Claude Code](https://claude.com/claude-code) skills for writing, research, and development workflows.

## Install

```
/plugin marketplace add fhightower/ai-skills
/plugin install ai-skills@fhightower
```

## Skills

| Skill | What it does |
| --- | --- |
| [`prose-proofreading`](skills/prose-proofreading/SKILL.md) | Systematic grammar and typo review for prose files. Reports findings by line number before editing, separating hard errors from optional style nits. |
| [`resume-after-usage-limit`](skills/resume-after-usage-limit/SKILL.md) | Schedules a one-shot local cron job so the current session wakes itself up and continues the task once a usage limit resets. |
| [`dependabot-pr-handle`](skills/dependabot-pr-handle/SKILL.md) | Triages a Dependabot PR — classifies the dependency, checks CI, investigates the upgrade, and applies consistent version-range handling. Never merges. |
| [`conflicts-resolve`](skills/conflicts-resolve/SKILL.md) | Resolves git merge/rebase/cherry-pick conflicts that are mechanically unambiguous, and leaves everything requiring judgment untouched for you. Never commits or continues the operation. |
| [`gh-actions-monitor`](skills/gh-actions-monitor/SKILL.md) | Watches a PR's GitHub Actions checks until they settle without busy-waiting, then reports pass/fail — pulling only the failed steps' logs to explain the cause. |
| [`coderabbit-feedback`](skills/coderabbit-feedback/SKILL.md) | Verifies CodeRabbit actually reviewed a PR rather than assuming it did, triggers it if not, polls until the review lands, and surfaces only the unresolved actionable items. |

## What is a skill?

A skill is a capability Claude reaches for on its own. Each skill is a directory
under `skills/` containing a `SKILL.md` with YAML frontmatter:

```markdown
---
name: my-skill
description: Use when <the situation that should trigger this skill>.
---

Instructions for Claude go here.
```

The `description` is what Claude matches against the task at hand, so it should
describe *when* to use the skill, not just what it does. Only the description
stays in context; the body loads when the skill is invoked. A skill directory can
also hold reference docs, templates, and scripts — none of which cost tokens
until needed.

## Developing

Clone the repo and symlink the skills into `~/.claude/skills/` so edits are live
without a reinstall:

```
git clone git@github.com:fhightower/ai-skills.git
cd ai-skills
bin/link.sh
```

`bin/link.sh` never deletes a real directory and never overwrites a symlink owned
by another repo — on conflict it reports and skips.

```
bin/link.sh --dry-run    show what would happen, change nothing
bin/link.sh --prune      remove symlinks whose source skill was deleted or renamed
```

To sync another machine: `git pull && bin/link.sh`.

Don't also install this repo through the marketplace on a machine where it's
symlinked — that yields two copies of every skill.

## License

MIT
