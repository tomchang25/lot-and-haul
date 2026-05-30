# dev/docs

Project documentation for Lot & Haul. This folder is a separate git repo.

## The model: 3 levels, one source of truth

Every fact about this project lives at exactly **one** level. Duplication across levels is what causes docs to rot — when the same thing is written twice, one copy goes stale and you can't tell which. The level is chosen by **audience + how often the fact changes**, not by how "important" it feels.

| Level                   | What                                                                                                | Audience            | Lives in                                 | Changes             |
| ----------------------- | --------------------------------------------------------------------------------------------------- | ------------------- | ---------------------------------------- | ------------------- |
| **L1 Vision**           | The whole-project concept: core loop, the fantasy, why it's fun. ≤5 artifacts total.                | Humans              | `vision/` (interactive HTML or md)       | Almost never        |
| **L2 Systems & design** | One system's design intent + flow, or a standalone design/work doc. Agent-readable, human-readable. | Agents (humans too) | `systems/` `plans/`                      | When design changes |
| **L3 Detail**           | Function names, fields, signatures, step-by-step logic.                                             | Agents reading code | Code docstrings (`#` header, `##` GDDoc) | Every commit        |

Why this resists rot:

- **L3** never goes stale because it's edited in the same commit as the code.
- **L1** never goes stale because the vision rarely changes.
- **L2 is the danger zone** — far enough from code that it isn't auto-updated, specific enough that code changes invalidate it. Every rule below exists to keep L2 honest.

## Tracking lives at the repo root, not here

Documentation (this folder) describes **how the project works**. _Tracking_ — what's done, what's planned, what's next — is a separate concern and lives in three root-level files. Keeping them apart is what stops architecture docs from filling with status noise.

| File           | Direction | What it holds                                                                                                                                                                                         | Rots?                                              |
| -------------- | --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| `CHANGELOG.md` | backward  | Append-only record of shipped work. The permanent "done" history.                                                                                                                                     | Never — append-only, never reconciled against code |
| `TODO.md`      | forward   | The single forward surface: `## Active` in-flight flows, open work (Plan/Chore/Bug one-liners), and a `## Draft` section of brewing concepts. Multi-step flows detail out to `dev/docs/plans/` files. | No — done = delete the line                        |

> **The one principle behind all of them: there is no living "Done" list anywhere.** "Done" is recorded once in `CHANGELOG.md` (immutable history) and erased everywhere else. A `systems/` doc never enumerates what was built; a `dev/docs/plans/` file cuts shipped phases out rather than checking them off; `TODO.md` has no Done section. A standing list of finished work is the single most reliable way to rot — so we don't keep one.

### TODO vs plans/ vs CHANGELOG

- **TODO** = the WHAT-NOW and the single forward surface — every open item and brewing idea, so nothing gets forgotten in a second list. `## Active` holds in-flight flows, `## Plan` holds queued flows backed by a file, `## Draft` holds concepts. Entries are one line; the moment something needs sequencing, a dependency reason, or phases, it earns a `dev/docs/plans/` file and `TODO.md` keeps only a one-line pointer.
- **plans/** = the WHY and the _order_. A multi-step flow's phases, dependencies, and acceptance criteria live in its own file. **Forward-only**: ship a phase → cut it out; ship the flow → archive the file.
- **CHANGELOG** = the permanent record. The only place finished work persists.

## The maturity scale (one item, one home)

A forward item has exactly one home, chosen by how much substance it carries. It moves home as it grows — it is never written in two places at once.

| Maturity                                                                    | Home                                                                                                   | Form                                   |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | -------------------------------------- |
| One line, no reasoning                                                      | `TODO.md` → `Plan` / `Chore` / `Bug`                                                                   | a single line                          |
| Bigger than a line, but one section says enough                             | `TODO.md` → `## Draft`                                                                                 | one `###` sub-section under `## Draft` |
| Earned its own file (grew sub-structure / actionable / needs a stable link) | `dev/docs/plans/<x>.md` + a one-line pointer in `TODO.md` `## Plan`                                    | a standalone design/work file          |
| Design locked                                                               | graduate the conclusion into `systems/`, archive the file                                              | present-tense paragraph in `systems/`  |
| Shipped                                                                     | `CHANGELOG.md` entry; cut the phase from its plan file; delete the TODO line when the whole flow lands | append-only history                    |

> **The one rule — now about sections, not files:** the actionable TODO tiers (`Plan`/`Chore`/`Bug`) are **one line each**. The instant an item needs a paragraph of _why_, a table, or a trade-off, it belongs in `## Draft` as its own section — never inline in a one-liner tier. When that section grows sub-structure, becomes actionable, or needs to be linked, it graduates to a `plans/` file.

There is no separate `draft/` folder and no separate draft file: the draft tier is the `## Draft` section of `TODO.md`. This keeps one forward surface to check, and keeps the actionable one-liners clean by corralling reasoning into a single labelled section.

## Where each thing lives

```
repo root/
├── TODO.md      Single forward surface: ## Active + Plan/Chore/Bug one-liners + a ## Draft section.
└── CHANGELOG.md Append-only shipped history. The permanent "done" record.

dev/docs/
├── vision/      L1: whole-project concept. ≤5 artifacts. Changes almost never.
├── systems/     L2: per-system design intent + flow, present tense. Evergreen. (concept only)
├── plans/       L2: one standalone design/work doc per file (multi-step flow detail).
├── archived/    Completed or superseded docs (read-only reference)
└── README.md    This file
```

## Lifecycle (maintenance happens as a side effect, never as a ritual)

You will not "tidy docs" on a schedule — so the system must update itself while you work:

- **Finish a chore/bug** → delete its line in `TODO.md`. Nothing left behind.
- **A `## Draft` idea earns a file** → move it to `dev/docs/plans/<x>.md`, leave a one-line pointer in `TODO.md` `## Plan`, and delete the Draft section. A `## Draft` idea (or a stale `## Plan` pointer) that never grew → just delete it / retire it back to Draft.
- **Ship a phase** → append one entry to `CHANGELOG.md` and cut that phase from its plan file. **Ship the whole flow** → archive the plan file and delete its `TODO.md` line — all in the same commit.
- **A plan's design gets locked** → write the _conclusion_ (1 paragraph) into the matching `systems/` doc, then move the plan to `archived/`. It never lingers as a competing source of truth.
- **Code detail changes** → it was in L3, so it's already updated in the same commit.

Tie doc maintenance to "marking something done," never to a separate cleanup pass.

## Rules per folder

### General

- Docs capture concepts, flow, and design intent. Implementation details (API, fields, step-by-step logic) belong in the file's class docstring or function header:
  ```gdscript
  # item_card.gd
  # Generalised item card for the inspection grid.
  ```
  Function docstrings use `##` (GDDoc) so Godot shows them on hover — required for all public functions and private functions over 10 lines or with non-obvious logic.
- Code-level detail (function names, field lists, signatures) → **code comments**, not here.
- If a doc hasn't been touched in 2+ weeks and isn't in `systems/` or `vision/`, consider deleting it.
- **No hard-wrapping in Markdown prose.** Every prose paragraph — whether standalone or inside a list item — must be a single logical line, not broken at ~80 columns. List markers (`-`, `*`, `1.`) and continuation indentation collapse into the line so the text reads continuously. Code blocks, tables, and headings keep their natural structure. This prevents misleading line breaks when editors reflow at different widths.

### vision/ (L1)

The project's reason to exist: core loop, player fantasy, what makes it fun. Aimed at a human seeing the whole picture, so interactive HTML is fine — but keep the _source_ maintainable (write the substance in md and render, or accept it changes almost never). Hard cap: **≤5 artifacts.** If you're adding a 6th, it's probably an L2 system doc.

### systems/ (L2, evergreen)

One file per system. Top-level files cover the cross-phase / core-loop systems (`item_system.md`, `lot_auction_run.md`, `customer_sell.md`); `meta/` holds hub-phase sub-systems (hub, knowledge, vehicle); `shared/` holds cross-cutting infrastructure (autoloads, the data model, item display).

Write everything in **present tense — describe the system as it is now.** A system doc is a snapshot of current design, not a history of how it got here.

**Goes in:** system purpose + player-facing goal (1 paragraph), conceptual flow (what triggers what), state transitions/lifecycle, current behavior and invariants (the gotchas a future editor must not break, e.g. "AP is per-lot today").

**Does NOT go in:**

- Function signatures, method names, field lists, file paths (except top-level entry points), anything that changes with a refactor.
- A **`## Status` / `Done` enumeration of what's been built.** That's a changelog — it rots, and git already has it. Delete it; the system doc's present-tense description _is_ the status.
- **Any `## Planned` / `## Future` / todo-style section** — even a links-only one. A system doc carries zero forward-looking sections. Every forward item is routed to one of two homes instead:
  - if it's an **unresolved design question about the system as it stands** (the reader needs to know this part is undecided) → an `## Open Questions` section, phrased as a question, present tense (e.g. "Should trailer items enter storage, be discarded, or be a separate risk channel? — undecided").
  - if it's **forward work or a feature idea** (something to build) → it leaves the doc entirely and goes into `TODO.md` (and, if it's a multi-step flow, a `dev/docs/plans/` file).

Guiding test: **if renaming a function would make the doc wrong, that detail doesn't belong here. If the doc would still be true after the next ship, it's evergreen.** A system doc only ever describes the present and names what's genuinely undecided about it — never what's coming.

### plans/ (L2, temporary)

One file per standalone design/work item — the place an idea lands once it has outgrown a `TODO.md` `## Draft` section. It holds both still-exploratory designs and committed pre-plans; there is no `Status:` header — whether it's actively being built is expressed by where its pointer sits in `TODO.md` (`## Plan` = queued, `## Active` = building), and a stale plan is retired by moving its content back to `## Draft`.

Name: `<scope>_<short_description>.md`. Contains goal (1–2 sentences), context/why now, high-level steps (or phases), and acceptance criteria. Keep it **forward-only**: as each phase ships, cut it out and record it in `CHANGELOG.md` — don't keep a checked-off phase ledger. When its design locks, graduate the conclusion to `systems/`. Archive the plan once it's shipped or superseded.

## Relationship to other dev/ folders

- `dev/standards/` — coding conventions, naming rules, project structure
- `dev/skills/` — AI coding tool references (commit format, GDScript patterns)
- `dev/tools/` — build scripts (yaml/tres pipeline)

These are separate concerns and live outside `docs/`.
