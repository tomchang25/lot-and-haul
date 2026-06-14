Close out completed work: update CHANGELOG, TODO, archive plan/spec files, and optionally suggest a commit message when explicitly asked.

This command never stages, commits, pushes, creates PRs, or invokes `/pr`. It is a documentation cleanup workflow only.

## Detect mode

Run `git status` and `git branch --show-current`:

- **Staged mode** — there are staged changes: the completed scope is the staged diff.
- **Branch mode** — no staged changes, and the current branch is not `main` and is ahead of it: the completed scope is `git diff main...HEAD` (merge-base diff). A branch may close out one or more plans.
- Neither applies → ask what to close out.

## Steps

1. Identify the plan/spec file(s) in the completed scope (under `dev/docs/plans/`). Staged mode normally has exactly one; branch mode may have several — process each plan through steps 2–5. If none is found, ask which plan file(s) to use.
2. Read each plan file to understand the completed scope and phases.
3. Append a CHANGELOG entry per plan under `CHANGELOG.md` following the existing format:
   - Group under a `## <Title>` heading matching the plan title.
   - Each bullet: `- YYYY-MM-DD — [scope] one-line summary`. Use today's date. No commit ref.
   - Cover each major change block (one bullet per logical unit).
4. Remove each plan's one-line pointer from `TODO.md` `## Active` (or `## Plan` if it was queued). If `## Active` becomes empty, replace the section content with "Nothing currently in progress."
5. Move each plan file and its sibling spec/scout files from `dev/docs/plans/` to `dev/docs/archived/`.
6. Run `git status` to show the final state.
7. If the user explicitly asks for a commit message, write one in conventional commit format (`type(scope): summary`) with a 2-3 bullet body summarizing the key changes. Follow `dev/skills/conventional_commits.md` and the CLAUDE.md commit conventions (no hard-wrapped prose). Never include TODO/CHANGELOG/archive operations in the commit body — those are dev-process actions, not code changes.
