# Pull Request Convention

A lightweight convention for PR titles and descriptions. Extends `conventional_commits.md` — read that first; this document only covers what differs at the PR level.

---

## Title

The PR title follows the same format as a commit subject line:

```
<type>[optional scope][!]: <description>
```

- Same types, scopes, and `!` breaking-change marker as `conventional_commits.md`.
- Describe the PR as a whole, not its largest commit. If the PR mixes types, pick the type of the primary change (a `feat` PR that includes incidental `fix`/`refactor` commits is still `feat:`).
- The title becomes the squash-merge commit subject, so it MUST stand alone in the git log: imperative mood, no trailing period, ideally ≤ 72 characters.

---

## Description

Use these sections, in this order. `## Summary` and `## Changes` are REQUIRED; the rest appear only when applicable.

### `## Summary` (required)

1–3 sentences: what changed and why. Written for a reviewer with no context — lead with the problem or goal, not the implementation.

### `## Changes` (required)

Bullet list of logical changes, one `-` bullet per change, same imperative style as commit bodies (e.g. `- Add demand tags to CustomerEntry`). Group by area if the list exceeds ~8 bullets.

### `## Testing` (when code changed)

How the change was verified: headless check, linter on changed files, manual scene walkthrough, etc. One bullet per verification step. Omit for docs-only PRs.

### `## Breaking changes` (when applicable)

Required whenever the title carries `!` or any commit has a `BREAKING CHANGE:` footer. State what breaks and the migration path (e.g. save-store migration version, YAML schema change requiring regeneration).

### `## Notes` (optional)

Anything the reviewer should know that isn't a change: known limitations, follow-up work, review focus areas, screenshots for UI changes.

---

## Rules

- The description describes *what changed in the codebase* — the same "no administrative housekeeping" rule as commits applies (no bullets for archiving plans or updating `TODO.md`/`CHANGELOG.md`).
- Do not paste the commit list as the description; `## Changes` summarizes logical changes, which may not map 1:1 to commits.
- Do not hard-wrap prose at a column boundary — let the client wrap.
- Reference issues/plans with closing keywords where supported (e.g. `Closes #123`) at the end of the Summary, not as a separate section.

---

## Example

```
feat(customer_sell): add demand-tag matching to nightly customers

## Summary

Customers previously bought any item regardless of category, making demand tags cosmetic. This wires demand tags into the nightly sell flow so matching items earn the aggressive-sell dice bonus. Closes #88.

## Changes

- Add demand-tag match check to CustomerSellService price resolution
- Surface matched tags on the customer card in customer_sell scene
- Add `demand_bonus` constant to economy constants

## Testing

- Headless check via /tmp snapshot procedure — boots clean
- Linter on changed files — no findings
- Manual hub-night walkthrough: matched and unmatched items price as expected
```
