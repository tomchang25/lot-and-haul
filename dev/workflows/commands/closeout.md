Close out completed work: update CHANGELOG, TODO, archive plan/spec files, and suggest running `/commit-msg` for the final commit message.

This command never stages, commits, pushes, creates PRs, or invokes `/pr-review`. It is a documentation cleanup workflow only.

## Detect mode

Run `git status` and `git branch --show-current`:

- **Staged mode** — there are staged changes: the completed scope is the staged diff.
- **Branch mode** — no staged changes, and the current branch is not `main` and is ahead of it: the completed scope is `git diff main...HEAD` (merge-base diff). A branch may close out one or more plans.
- Neither applies → ask what to close out.

## Steps

1. Identify the plan/spec file(s) in the completed scope (under `dev/docs/plans/`). Staged mode normally has exactly one; branch mode may have several — process each plan through steps 2–5. If none is found, ask which plan file(s) to use.
2. Read each plan file to understand the completed scope and phases.
3. Append a CHANGELOG entry per plan under `CHANGELOG.md`, following the rules in the file header and `dev/standards/change_summary_standard.md`:
   - Add entries under the current `## <version>` heading.
   - Group related entries under a `### <Title>` section matching the plan title.
   - Each bullet: `- YYYY-MM-DD — [scope] one-line summary`. Use today's date. No commit ref.
   - Prefer one compact, general entry per plan. Only split into multiple bullets when the shipped work contains clearly separate user-visible outcomes that would be misleading if combined.
   - Keep bullets outcome-focused per the change-summary standard.
   - If the completed scope is dev-process-only maintenance, skip the CHANGELOG step. This includes closeout workflow changes, CHANGELOG/TODO edits, plan archival, and tracking cleanup.
4. Remove each plan's one-line pointer from `TODO.md` `## Active` (or `## Plan` if it was queued). If `## Active` becomes empty, replace the section content with "Nothing currently in progress."
5. Move each plan file and its sibling spec/scout files from `dev/docs/plans/` to `dev/docs/archived/`.
6. Run `git status` to show the final state.
7. Suggest running `/commit-msg` to generate a commit message for the completed scope.
