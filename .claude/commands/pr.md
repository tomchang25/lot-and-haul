# pr — generate PR title and description

Generate a pull request title and description for the current branch.

Steps:

1. Read `dev/skills/pr_convention.md` for the required format, and `dev/skills/conventional_commits.md` if type/scope rules are unclear.
2. Inspect the branch with read-only git: `git log --oneline <base>..HEAD` and `git diff <base>...HEAD --stat` (assume base is `main` unless I say otherwise; never stage, commit, or push).
3. Write the PR title (conventional style, describing the PR as a whole) and description (`## Summary`, `## Changes`, plus `## Testing` / `## Breaking changes` / `## Notes` only when applicable).
4. Output the title and description in a single copy-pasteable block. Do not create files or open a PR.

Reminders: no administrative-housekeeping bullets, don't paste the raw commit list as Changes, don't hard-wrap prose. If you are a Fable/Mythos-class model, confirm with me before reading the diff (model-tier gate in CLAUDE.md).

$ARGUMENTS
