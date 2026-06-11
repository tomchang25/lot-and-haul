Ship completed work: update CHANGELOG, TODO, archive plan/spec files, and suggest a commit message.

## Detect mode

Run `git status` and `git branch --show-current`:

- **Staged mode** — there are staged changes: the shipped scope is the staged diff.
- **Branch mode** — no staged changes, and the current branch is not `main` and is ahead of it: the shipped scope is `git diff main...HEAD` (merge-base diff). A branch may ship one or more plans.
- Neither applies → ask what to ship.

## Steps

1. Identify the plan/spec file(s) in the shipped scope (under `dev/docs/plans/`). Staged mode normally has exactly one; branch mode may have several — process each plan through steps 2–5. If none is found, ask which plan file(s) to use.
2. Read each plan file to understand the scope and phases shipped.
3. Append a CHANGELOG entry per plan under `CHANGELOG.md` following the existing format:
   - Group under a `## <Title>` heading matching the plan title.
   - Each bullet: `- YYYY-MM-DD — [scope] one-line summary`. Use today's date. No commit ref.
   - Cover each major change block (one bullet per logical unit).
4. Remove each plan's one-line pointer from `TODO.md` `## Active` (or `## Plan` if it was queued). If `## Active` becomes empty, replace the section content with "Nothing currently in progress."
5. Move each plan file and its sibling spec/scout files from `dev/docs/plans/` to `dev/docs/archived/`.
6. Run `git status` to show the final state.
7. After cleanup, ask which kind of commit message is wanted:
   - **Staged mode**: a single conventional commit for the staged work.
   - **Branch mode**: a bookkeeping commit for the ship changes themselves (CHANGELOG/TODO/archive), a squash-merge message covering the whole branch, or hand off to `/pr` for a PR description.

   Then write it in conventional commit format (`type(scope): summary`) with a 2-3 bullet body summarizing the key changes. Follow `dev/skills/conventional_commits.md` and the CLAUDE.md commit conventions (no hard-wrapped prose). Never include TODO/CHANGELOG/archive operations in the commit body — those are dev-process actions, not code changes.
