Close out completed work: update CHANGELOG, TODO, archive plan/spec files, and optionally suggest a commit message when explicitly asked.

This command never stages, commits, pushes, creates PRs, or invokes `/pr-review`. It is a documentation cleanup workflow only.

## Detect mode

Run `git status` and `git branch --show-current`:

- **Staged mode** — there are staged changes: the completed scope is the staged diff.
- **Branch mode** — no staged changes, and the current branch is not `main` and is ahead of it: the completed scope is `git diff main...HEAD` (merge-base diff). A branch may close out one or more plans.
- Neither applies → ask what to close out.

## Steps

1. Identify the plan/spec file(s) in the completed scope (under `dev/docs/plans/`). Staged mode normally has exactly one; branch mode may have several — process each plan through steps 2–5. If none is found, ask which plan file(s) to use.
2. Read each plan file to understand the completed scope and phases.
3. If the completed scope includes `.gd` or `.tscn` changes, explicitly re-check the touched scripts/scenes against `dev/standards/gdscript_structure_standard.md` before doing closeout bookkeeping. Confirm section order, signal connection placement, packed-scene instantiation order, and component `setup()`/`_apply()` shape where applicable.
4. Append a CHANGELOG entry per plan under `CHANGELOG.md`, following the rules in the file header and `dev/standards/change_summary_standard.md`:
   - Add entries under the current `## <version>` heading.
   - Group related entries under a `### <Title>` section matching the plan title.
   - Each bullet: `- YYYY-MM-DD — [scope] one-line summary`. Use today's date. No commit ref.
   - Prefer one compact, general entry per plan. Only split into multiple bullets when the shipped work contains clearly separate user-visible outcomes that would be misleading if combined.
   - Keep bullets outcome-focused per the change-summary standard.
   - If the completed scope is dev-process-only maintenance, skip the CHANGELOG step. This includes closeout workflow changes, CHANGELOG/TODO edits, plan archival, and tracking cleanup.
5. Remove each plan's one-line pointer from `TODO.md` `## Active` (or `## Plan` if it was queued). If `## Active` becomes empty, replace the section content with "Nothing currently in progress."
6. Move each plan file and its sibling spec/scout files from `dev/docs/plans/` to `dev/docs/archived/`.
7. Run `git status` to show the final state.
8. If the user explicitly asks for a commit message, write one in conventional commit format (`type(scope): summary`) with a 2-3 bullet body summarizing the key changes. Follow `dev/skills/conventional_commits.md`, `dev/standards/change_summary_standard.md`, and the CLAUDE.md commit conventions (no hard-wrapped prose). Never include TODO/CHANGELOG/archive operations in the commit body — those are dev-process actions, not code changes.
