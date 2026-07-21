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
| [`proofreading-prose`](skills/proofreading-prose/SKILL.md) | Systematic grammar and typo review for prose files. Reports findings by line number before editing, separating hard errors from optional style nits. |
| [`resuming-after-usage-limit`](skills/resuming-after-usage-limit/SKILL.md) | Checkpoints in-progress work and schedules a cloud routine to resume it automatically once a usage limit resets. |
| [`handle-dependabot-pr`](skills/handle-dependabot-pr/SKILL.md) | Triages a Dependabot PR — classifies the dependency, checks CI, investigates the upgrade, and applies consistent version-range handling. Never merges. |

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
