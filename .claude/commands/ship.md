Ship the currently staged work: update CHANGELOG, TODO, archive plan/spec files, and suggest a commit message. Steps:

1. Identify the plan/spec file among staged changes (under `dev/docs/plans/`). If none is staged, ask which plan file to use.
2. Read the plan file to understand the scope and phases shipped.
3. Append a CHANGELOG entry under `CHANGELOG.md` following the existing format:
   - Group under a `## <Title>` heading matching the plan title.
   - Each bullet: `- YYYY-MM-DD — [scope] one-line summary`. Use today's date. No commit ref.
   - Cover each major change block (one bullet per logical unit).
4. Remove the corresponding one-line pointer from `TODO.md` `## Active` (or `## Plan` if it was queued). If `## Active` becomes empty, replace the section content with "Nothing currently in progress."
5. Move the plan file and its sibling spec/scout files from `dev/docs/plans/` to `dev/docs/archived/`.
6. Run `git status` to show the final state.
7. Suggest a commit message in conventional commit format (`type(scope): summary`) with a 2-3 bullet body summarizing the key changes. Follow `dev/skills/conventional_commits.md` and the CLAUDE.md commit conventions (no hard-wrapped prose). Never include TODO/CHANGELOG/archive operations in the commit body — those are dev-process actions, not code changes.
