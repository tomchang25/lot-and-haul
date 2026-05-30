# Item Display

`ItemRow`, `ItemCard`, and `ItemListPanel` — the components that render items across stages. Live under `game/shared/item_display/`. This doc is the architecture and the key design decisions; method names, enum values, and signatures live in those `.gd` files.

---
There is **no `ItemViewContext`** — it was removed when identity layers and per-stage display rules collapsed onto the clue model. All display components take an `ItemEntry` directly and read display getters off it. There is no stage enum, no view-context branching, and no merchant/order side-channel in the display layer.

Every visible value (name + colour, estimated value, base value, condition, rarity, weight, grid, inspection level, sort key) is a getter on `ItemEntry` — see `../shared/data_model.md` for the runtime type and `item_entry.gd` for the getters themselves. Veil state is read via the entry's veil check (true until the anchor clue is revealed): veiled items return `"???"` and hide most fields. Estimated value renders as a range while revealed-but-unverified and as a single number once verified, all resolved through the entry's price resolution.

Column visibility **and** left-to-right order are driven entirely by each consuming scene passing its own ordered column array to `setup()` — no component hard-codes a column set.

---

## ItemRow

Generalised item row used by list_review, reveal, run_review, and storage. The columns array passed at setup drives both which columns show and their order (re-applied after visibility toggles so on-screen order matches the array). Each cell renders straight from its `ItemEntry` getter; the name cell also shows an authentication tag once the entry is verified. There are **no transaction columns** (merchant offer, special order, market factor, research status) — those belonged to the deprecated merchant channel.

Rows carry a selection state (none / selected / available / blocked) that applies a tint and toggles click handling, used by capacity-limited packing screens. Hover is decoupled: the row emits tooltip request/dismiss signals with an anchor rect and the parent scene positions the tooltip, which reads the same getters off the entry.

## ItemCard

Card widget for the inspection grid. Takes an `ItemEntry`. Veiled items hide super-category / category / rarity / condition / weight / grid and show `"???"` for price; once unveiled it shows them all. Supports field-change flash tweens, a border flash when the lot-level action bar targets the card, selection, and an intuition shimmer effect.

## ItemListPanel

Reusable panel wrapping a column-header row plus a scrollable `ItemRow` list with click-to-sort headers. Used by storage, run review, and list review. Headers are runtime-built from the columns array (a permitted exception under the Node Source Rule). Clicking a header sorts by that column and clicking again reverses; the active column shows a direction indicator. Sorting calls the entry's per-column sort getter — there is no `RowDataProvider` and no view-context dispatch.


