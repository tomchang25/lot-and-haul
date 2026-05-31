# Handoff: Eliminate `# node-src: ephemeral` markers

## Context

The repo `lot-and-haul` (Godot 4.6) enforces a Node Source Rule
(`dev/standards/block_scene_architecture_standard.md`, §11): every persistent node
in a block scene must live in the `.tscn`, referenced via `@onready`. Runtime
`add_child` of a non-`.instantiate()` node must carry a `# node-src: <tag>` marker
declaring which permitted exception applies (`instance` / `ephemeral` / `drawn` /
`debug` / `timer`).

A previous pass took the lazy path: it stamped **every** `add_child` with
`# node-src: ephemeral` to silence the linter (`dev/tools/lint_standards.py §11`),
regardless of whether the node is actually ephemeral. The standard explicitly warns
this is wrong: "The marker doesn't prove the node is genuinely ephemeral — it forces
the author to declare intent so a reviewer can judge the claim."

There are currently **40** `# node-src: ephemeral` markers across 13 files. Your job
is to triage each one and **eliminate as many as legitimately possible**, per the
user's two rules:

1. If a node can be built as a static component, split it into a `.tscn` component.
2. If not, try to generalize/modularize it into a standalone scene file.

You are NOT just deleting markers or relabeling to pass lint. Every marker you remove
must be removed because the node genuinely moved into a `.tscn` (static child or an
instantiated component) — or, in the mis-tagged cases, because you corrected it to the
honest tag.

## Read these first

- `dev/standards/block_scene_architecture_standard.md` — the full standard. Pay special
  attention to §11 (Node Source Rule), "Permitted exceptions" table, "Component
  `setup()` implementation", "Component `.tscn` default content", and "Instantiating
  packed scenes".
- `dev/standards/standards_enforcement.md` — how the lint works.
- `dev/skills/conventional_commits.md` — commit format.

## Critical environment warnings

- **The sandboxed shell can report phantom file corruption / wrong grep results for
  this repo** (mount artifact, documented in `CLAUDE.md`). The Read/Edit file tools and
  `git show HEAD:<file>` are authoritative. Do NOT diagnose anything from a raw `cat` /
  `grep` / `wc` through the shell mount, and never `git restore` to "recover" from a
  shell-reported corruption. Verify every edit with the **Read** tool.
- Before editing a file, re-grep `node-src: ephemeral` within it — **line numbers below
  will drift** as you edit. Treat the line numbers as anchors, not addresses.
- If you are not Claude Code (no in-loop lint hook), run
  `python dev/tools/lint_standards.py --files <changed>` after each change and ensure it
  passes before moving on.

## The four buckets

Classify each marker into exactly one bucket.

**Bucket 1 — Mis-tagged: change the tag, don't extract.** The node is a legitimate
code-created exception but under the WRONG tag. Just correct the tag.

**Bucket 2 — Extract a reusable `.tscn` component (rule #2).** A per-data-item "row"
or "cell" assembled in a loop from labels/buttons. Build a component `.tscn` + script
using the standard's `setup()`/`_apply()` pattern, then in the parent replace the manual
construction with `Scene.instantiate()` → `setup()` → `connect()` → `add_child()`. An
`.instantiate()`'d node needs **NO marker** — it is auto-recognized. This eliminates the
marker AND aligns with the architecture.

**Bucket 3 — Promote to a static node in the `.tscn` (rule #1).** The node exists for
the full lifetime of the scene and there is exactly one of it. It should be a static
child in the `.tscn`, referenced via `@onready`, with the `add_child` deleted entirely.
Key test from the standard: *"does this node exist for the full lifetime of the scene?"*

**Bucket 4 — Genuinely ephemeral: leave it, keep the marker.** Tooltips, separators in
dynamic lists, empty-state labels ("No X found"), and shape/grid cells whose count is
unknown at edit time and which are torn down on refresh. Per the exceptions table these
are correct as-is. **Do not over-engineer these.** Removing them would violate the
standard. Resist the urge to hit zero.

## Per-marker action list

Work file-by-file, one component/commit at a time. Re-grep each file before editing.

### Quick wins — Bucket 1 (retag)

- `game/run/auction/auction_scene.gd` ~:94 — `_circle_node = _CircleProgress.new()` is a
  custom-drawn inner class with `_draw()`. Retag → `# node-src: drawn`.
- `game/run/auction/auction_scene.gd` ~:231 — `_npc_timer = Timer.new()`. Retag →
  `# node-src: timer`.

### Bucket 3 — promote to static `.tscn` node (delete the add_child)

- `game/shared/item_display/item_row_tooltip.gd` ~:29 `_clue_separator = HSeparator.new()`
  and ~:35 `_clue_container = VBoxContainer.new()` — both built in `_ready()` and live for
  the full tooltip lifetime. These are textbook persistent nodes. Move both into the
  tooltip `.tscn` (`$VBox` at the correct sibling positions), reference via `@onready`,
  delete the `add_child` calls. (The `Clues` header at ~:132 is rebuilt per refresh inside
  `_clue_container` — that one stays Bucket 4.)
- `game/run/inspection/inspection_scene.gd` ~:581 `_clues_vbox = VBoxContainer.new()` and
  ~:621 the static `CLUES` header — both always-present structural nodes under
  `_detail_section`. Move into the `.tscn`. Once `_clues_vbox` is static, re-evaluate the
  separator at ~:615 (it can become a static child too).
- `game/meta/knowledge/mastery_panel/mastery_panel.gd` ~:31 the single `Mastery Rank: N`
  heading — one persistent node; make it a static `@onready` label in the `.tscn` and set
  only its `.text` at runtime. (The separator ~:33 can follow as a static node; the
  per-super-category rows at ~:41 are Bucket 2.)
- `game/shared/item_display/item_list_panel/item_list_panel.gd` ~:147 — the column-header
  buttons map 1:1 to the fixed `ItemRow.Column` enum (a closed set, not data-driven). Prefer
  making them static children in the `.tscn` referenced via `@onready`; if the header text
  is enum-derived, set `.text` at runtime but keep the nodes static. If a static layout is
  impractical, fall back to Bucket 2 (a `ColumnHeaderButton.tscn`).

### Bucket 2 — extract reusable component `.tscn`

For each, create `<Name>.tscn` + `<name>.gd` next to the parent scene, implement
`setup(...)` (store args, gate on `is_node_ready()`, call `_apply()`), `_apply()` (the
only function touching `@onready` nodes), placeholder text in the `.tscn`, then replace the
loop body in the parent with instantiate→setup→connect→add_child (no marker).

- `game/meta/knowledge/attribute_panel/attribute_panel.gd` ~:34/48/49 (name label +
  upgrade button → row) → `AttributeRow.tscn`. Expose an `upgrade_pressed(attr)` signal
  instead of binding the callback inside the row.
- `game/run/inspection/inspection_scene.gd` ~:468–481 (found-clue row: name + value) →
  `FoundClueRow.tscn`.
- `game/run/inspection/inspection_scene.gd` ~:501–512 (veiled-clue row: name + AP) →
  `VeiledClueRow.tscn`.
- `game/run/inspection/inspection_scene.gd` ~:629–654 (clue row: name + value) →
  `ClueRow.tscn`. (These three rows are similar — consider one parameterized
  `ClueRow.tscn` with a variant/mode arg if it doesn't bloat the component. Use judgment;
  don't force a merge that adds branching complexity.)
- `game/run/auction/auction_scene.gd` ~:337 (`YOU -- $N`) and ~:357 (incoming bid label,
  fades in) → `BidHistoryRow.tscn`. The fade-in tween can stay in the parent or move into
  the component via a `play_enter()` method — prefer the component owning its own animation.
- `game/run/auction/auction_scene.gd` ~:211 (per-item lot summary line) → fold into a
  `LotSummaryRow.tscn`. The trailing total label at ~:221 and the separator at ~:213 are
  Bucket 4 (single transient footer / separator) unless folding them into the same
  component reads cleanly.
- `game/meta/knowledge/mastery_panel/mastery_panel.gd` ~:41 (per-super-category
  `name — rank N` row) → `MasteryRow.tscn`.
- `game/run/cargo/cargo_scene.gd` ~:339 + ~:574 — `_make_extra_slot_cell()` builds a
  PanelContainer + IconLabel per extra slot (count = `extra_slot_count`). Extract
  `ExtraSlotCell.tscn`; the `icon_label` add_child at ~:574 disappears into the component.
  Keep the `mouse_entered` hover wiring as a component signal.

### Bucket 4 — leave as-is (verify the marker is honest, then move on)

These are legitimately ephemeral. Confirm each is genuinely transient/dynamic and keep the
`ephemeral` tag:

- `game/meta/customer_sell/customer_sell_scene.gd` ~:91 (per-customer tab button — dynamic
  count), ~:163 (`No matching items` empty state), ~:324 (per-die toggle button — dynamic
  count). *Optional:* tabs/dice could become small components if you have spare cycles, but
  they are acceptable as ephemeral. Do not block on them.
- `game/meta/knowledge/perk_panel/perk_panel.gd` ~:32 (`No perks discovered` empty state).
- `game/meta/vehicle/car_shop/car_shop_scene.gd` ~:59 (`No cars available` empty state).
- `game/run/cargo/cargo_item_row.gd` ~:164 (per-shape-cell `ColorRect` icon — dynamic
  shape visualization, torn down on refresh).
- `game/run/inspection/inspection_scene.gd` ~:133 (per-grid-cell button, W×H, count
  unknown at edit time). *Optional* `GridCell.tscn` component, otherwise keep.
- `game/shared/packing/packing_grid.gd` ~:308 (per-grid-cell, W×H). *Optional* component,
  otherwise keep.
- `game/run/auction/auction_scene.gd` ~:213 (separator), ~:221 (single total footer label).
- `game/meta/knowledge/mastery_panel/mastery_panel.gd` ~:33 (separator).
- `game/run/inspection/inspection_scene.gd` ~:615 (separator — revisit after the Bucket 3
  vbox move).
- `game/shared/item_display/item_row_tooltip.gd` ~:132 (`Clues` header, rebuilt per
  refresh).

## Guardrails (do not skip)

1. **Extracting a component ≠ deleting a marker.** Follow the standard's component shape
   exactly: `setup()` only stores args + calls `_apply()` gated by `is_node_ready()`;
   `_apply()` is the sole function touching `@onready` nodes; `.tscn` ships placeholder
   values (`" - "`, `"0"`, `"? / ?"`, null textures); instantiate order is
   instantiate → `setup()` → `connect()` → `add_child()`. Components expose data via
   `setup()` and behavior via signals, not via parent-side property poking.
2. **Verify every edit with the Read tool, never via shell `cat`/`grep`** (phantom
   corruption — see warnings above). The lint run is the only shell command you should
   trust for these files, and even then judge results sanely.
3. **Run `python dev/tools/lint_standards.py --files <changed>` after each change**; green
   before proceeding.
4. **One component / one logical change per commit**, conventional-commits format, so the
   reviewer can confirm each marker was genuinely eliminated (moved to `.tscn`) rather than
   relabeled. Suggested scopes: `refactor(inspection): extract ClueRow component`, etc.
5. **Don't chase zero.** Bucket 4 markers staying is the correct outcome. A good result is
   ~Bucket 1+2+3 eliminated, Bucket 4 retained and verified honest.
6. **Don't touch `.tres` files by hand** and don't restate standard rules in `CLAUDE.md` —
   if a rule needs clarifying, edit the standard doc.

## Definition of done

- All Bucket 1 markers retagged correctly (`drawn` / `timer`).
- All Bucket 3 nodes moved into their `.tscn` as static `@onready` children, `add_child`
  deleted.
- All Bucket 2 rows/cells extracted into component `.tscn` + script following the standard
  pattern, parents using `instantiate()` with no marker.
- All Bucket 4 markers reviewed and confirmed genuinely ephemeral.
- `lint_standards.py` passes for every changed file.
- Each change is a separate conventional commit.
- A short summary listing: markers eliminated, markers retagged, markers intentionally
  kept (with one-line justification each).
