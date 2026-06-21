# Pull Request Convention

A lightweight convention for PR titles and descriptions. Extends `conventional_commits.md` and `dev/standards/change_summary_standard.md` — read those first; this document only covers what differs at the PR level.

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

Use these sections, in this order. `## Summary` and `## Changes` are REQUIRED; the rest appear only when useful.

### `## Summary` (required)

1–3 sentences: what changed and why. Written for a reviewer with no context — lead with the problem or goal, not the implementation.

### `## Changes` (required)

The logical changes the PR makes. Format is free for simple PRs: use prose or a bullet list with one logical change per `-` bullet. Bullets, when used, follow the same imperative style as commit bodies (e.g. `- Add demand tags to CustomerEntry`). Summarize logical changes, not commits — the two need not map 1:1.

For a PR large enough to warrant grouping, use `###` subheadings inside `## Changes`. Do not use bold-label bullets as section substitutes (for example, avoid `- **Localization** — ...` or `**Localization** — ...`). Pick whichever grouping fits the PR; default to **by area** when in doubt:

- **By area / module** (default) — group bullets under `###` headings for the module or scene they touch (`### CustomerEntry`, `### customer_sell scene`, …). Matches how a reviewer reads the diff, so it's the safe choice for most PRs.
- **By feature / theme** — group under each self-contained sub-feature or theme (`### Demand-tag matching`, `### Incidental fixes`, …). Use only when one PR genuinely carries several independent strands; if the strands are fully independent, prefer splitting into separate PRs instead.

### `## Breaking changes` (when applicable)

Required whenever the title carries `!` or any commit has a `BREAKING CHANGE:` footer. State what breaks and the migration path (e.g. save-store migration version, YAML schema change requiring regeneration).

### `## Notes` (optional)

Anything the reviewer should know that isn't a change: known limitations, follow-up work, review focus areas, screenshots for UI changes.

---

## Rules

- The description describes _what changed in the codebase_ — follow `dev/standards/change_summary_standard.md` for tone, content, and administrative-housekeeping exclusions.
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
```

Grouped PRs use `###` subheadings inside `## Changes`:

```
feat(i18n): add multilingual localization support

## Summary

Hardcoded game strings are now externalized into per-language localization sources. The game can present UI and data text in multiple languages without scene-specific string edits.

## Changes

### Localization framework

- Add per-language localization source files
- Migrate UI and data-definition strings to localization keys

### Dev tooling

- Add YAML key naming lint coverage
- Add localization export support
```

Optional verification, when useful:

```

```
