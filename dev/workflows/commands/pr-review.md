# pr-review - review branch and generate PR title and description

Review the current branch against the base branch, then generate a pull request title and description.

Steps:

1. Read `dev/skills/pr_convention.md` for the required format, and `dev/skills/conventional_commits.md` if type/scope rules are unclear.
2. Inspect the branch with read-only git: `git log --oneline <base>..HEAD` and `git diff <base>...HEAD --stat` (assume base is `main` unless I say otherwise; never stage, commit, or push).
3. Review `git diff <base>...HEAD` with a code-review mindset before drafting PR text:
   - Prioritize bugs, behavioral regressions, standards violations, missing tests, and reviewer-facing risks.
   - Report findings first, ordered by severity, with file/line references when possible.
   - If there are no findings, say so explicitly and mention residual risks or testing gaps.
4. Write the PR title (conventional style, describing the PR as a whole) and description (`## Summary`, `## Changes`, plus `## Testing` / `## Breaking changes` / `## Notes` only when applicable).
5. Output the title and description in a single copy-pasteable block. Do not create files or open a PR.

Reminders: follow `dev/standards/change_summary_standard.md`, don't paste the raw commit list as Changes, don't hard-wrap prose. If you are a Fable/Mythos-class model, confirm with me before reading the diff (model-tier gate in CLAUDE.md).

$ARGUMENTS
