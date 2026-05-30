# Phase 8 — Dynamic Naming via Clue Affix Composition

## Goal

Replace the binary display name (unknown label vs. verified name) with a progressive affix system: each clue optionally declares a naming slot (prefix / body / suffix) and a priority, and the item's visible name assembles from the winning clue text per slot as clues are revealed. Veiled and unresolved items show a fixed "Unknown Item" label. Verified items show the authored item name directly.

## Relational Context

- `ClueData` already carries `known_text: String`. Phase 8 adds two new fields (`naming_slot`, `naming_priority`) and enforces the three-word ceiling on `known_text` at the pipeline level. No runtime validation needed.
- `ItemEntry` already tracks `anchor_revealed: bool` and `revealed_clue_ids: Array[String]` separately. The new `display_name` computed property reads both to build the naming clue pool.
- `ItemEntry.verified` is already a computed property (all hidden clues in `revealed_clue_ids`). `display_name` checks it before composing.
- The anchor clue is **not** automatically added to `revealed_clue_ids` — it is tracked only via `anchor_revealed`. The naming composition logic must handle both pools explicitly.
- Display name consumers already read a single computed string; no UI changes are required.
- Phase 8b (content regeneration — authoring naming entries on all existing items) is a separate effort and not in scope here.

## Scope

### Included

- `naming_slot` and `naming_priority` fields on `ClueData` (GDScript + YAML schema).
- `display_name` computed property on `ItemEntry`.
- Three-word `known_text` validation rule in `validate_yaml.py`.
- Full-reveal composition validation rule in `validate_yaml.py` (composed name must equal `item_name`).
- YAML pipeline support: `tres_lib/entities/clue.py` and `yaml_to_tres.py` updated for naming fields.
- Generation prompt updates: `base.md` / `item.md` document the naming entry schema and conventions.
- Fallback behaviour for existing save data and items with no naming entries.

### Excluded

- Combination-based naming (two clues producing a different word together) — deferred.
- Changes to the price pipeline — naming entries are purely cosmetic.
- UI layout or widget changes.
- Regenerating existing YAML content (Phase 8b).
- Pool-based or procedural item generation.

## Design Decisions

| Question | Decision |
| --- | --- |
| Relationship between anchor clue and body slot | Anchor typically carries the body naming entry (low priority), but this is a convention, not a constraint. Higher-priority hidden clues can displace it. Standard priority logic applies. |
| Empty slot handling | Empty slots are skipped silently. If composition produces an empty string (no naming clue revealed in any slot), the item shows "Unknown Item". This replaces the old category-prefixed label entirely. |
| `known_text` field location | Independent field on every `ClueData`, regardless of whether a naming entry is present. Serves dual purpose: reveal description and naming contribution. |
| Veil label format | Fixed string `"Unknown Item"` — removes category prefix. Both veiled items and unveiled items with no naming clues revealed show this same label. |
| Priority tie-breaking | Array order in `ItemData.clues` is the tiebreaker — the first clue in the array wins. This is deterministic and designer-controlled. |

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `data/definitions/clue_data.gd` | Small | Add `naming_slot` and `naming_priority` exported fields. |
| `common/gameplay/item_entry.gd` | Small | Add `display_name` computed property. |
| `dev/tools/tres_lib/entities/clue.py` | Small | Parse optional `naming:` block; validate slot values. |
| `dev/tools/yaml_to_tres.py` | Small | Write `naming_slot` / `naming_priority` to `.tres`. |
| `dev/tools/validate_yaml.py` | Medium | Add two new rules: three-word ceiling and composition match. |
| `dev/tools/prompts/yaml_generation/base.md` or `item.md` | Small | Document naming entry schema, slot/priority conventions, three-word ceiling. |

## Implementation Notes

**`data/definitions/clue_data.gd`**

Add two exported fields after the existing `known_text` declaration:

```
@export var naming_slot: String = ""
@export var naming_priority: int = 0
```

Valid `naming_slot` values: `""` (no naming participation), `"prefix"`, `"body"`, `"suffix"`. Runtime code treats any other value as `""`.

**`common/gameplay/item_entry.gd`**

Add a `display_name` computed property. Logic:

1. If `verified`: return `item_data.item_name` directly.
2. Build the **revealed clue pool**: the anchor clue (looked up from `item_data.clues` where `type == ANCHOR`) if `anchor_revealed` is true, plus all `ClueData` entries whose `clue_id` is in `revealed_clue_ids`.
3. For each slot (`"prefix"`, `"body"`, `"suffix"`): iterate the pool in `item_data.clues` array order (to ensure deterministic tie-breaking), keep the entry with `naming_slot == slot` that has the highest `naming_priority`. If multiple entries share the top priority, the one that appears first in the array wins.
4. Concatenate the `known_text` of the winning clues for each non-empty slot, separated by a single space.
5. If the result is an empty string: return `"Unknown Item"`.

There is no separate early-exit for `is_veiled()` — a veiled item naturally produces an empty pool and falls through to `"Unknown Item"`.

Helper needed: a small private method that returns all `ClueData` in `item_data.clues` whose `clue_id` is in `revealed_clue_ids`, plus the anchor clue if `anchor_revealed`. This lookup iterates `item_data.clues` once and returns a list of `ClueData` refs. No registry access.

**`dev/tools/tres_lib/entities/clue.py`**

Add optional `naming` block parsing. When present:

```yaml
naming:
  slot: body      # required if naming block present; must be "prefix", "body", or "suffix"
  priority: 5     # required if naming block present; integer
```

Map to flat Python fields `naming_slot: str` (default `""`) and `naming_priority: int` (default `0`). Validate that `slot` is one of the three allowed values; reject anything else.

**`dev/tools/yaml_to_tres.py`**

When writing clue `.tres` entries, emit `naming_slot` and `naming_priority` from the parsed clue entity. Both fields have safe defaults (`""` and `0`) if the naming block is absent.

**`dev/tools/validate_yaml.py`**

Add two new validation rules, run after existing clue and item checks:

*Rule — three-word ceiling:*
For every clue, split `known_text` on whitespace and assert `len(parts) <= 3`. Fail with the clue_id and the offending text.

*Rule — composition match:*
For every item, simulate full reveal: treat all clues on the item as revealed (anchor + all `clue_ids`). Run the same slot-resolution logic as the runtime (highest priority per slot, array-order tiebreak). Concatenate non-empty slots. Assert the result equals `item_name` exactly. A mismatch is a validation error listing the item_id, the composed string, and the authored `item_name`. Items with no naming entries on any clue are exempt from this check (they will always show "Unknown Item" until verified, and that is a valid authoring choice — just not recommended).

**`dev/tools/prompts/yaml_generation/`**

In the appropriate prompt file (`base.md` or `item.md`), document:

- `known_text` is required on every clue, three words or fewer. It appears when the clue is discovered and contributes to the display name when a naming entry is present.
- The optional `naming:` block with `slot` (`prefix`, `body`, or `suffix`) and `priority` (positive integer; higher wins).
- Convention: the anchor clue carries `slot: body` with a low priority (e.g., 1). Surface clues that identify maker, material, or style carry `slot: prefix` or `slot: suffix` with higher priorities. Hidden clues that identify origin or authentication carry the highest priorities and may override the anchor's body text.
- Together, all naming entries on an item must compose to exactly `item_name` under full reveal. The validator enforces this.
- Items with no naming entries on any clue are valid but will show "Unknown Item" until verified. Avoid this for standard items.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Veiled item (anchor not revealed) | Pool is empty → "Unknown Item". |
| Unveiled item, no clue has a naming entry | Pool contains the anchor but `naming_slot == ""` → composition empty → "Unknown Item". |
| Some naming clues revealed, body slot still empty | Prefix and/or suffix text assembles without a body word. Result may look incomplete — this is intentional and signals the player that identification is in progress. |
| Verified item | Returns `item_data.item_name` directly, bypasses composition entirely. |
| Multiple clues tie on priority for same slot | First in `item_data.clues` array order wins. |
| Item has no naming entries at all | Composition always returns "Unknown Item" until verified. Not a validation error (but validator will not run the composition-match check for this item). |
| Existing save data — `naming_slot` / `naming_priority` absent from `.tres` | GDScript default values (`""` / `0`) apply transparently on load. No migration code needed in `ItemEntry`. These items have no naming clues and show "Unknown Item" until verified. |
| `known_text` on a clue that has no naming entry | Still used for the reveal description in the inspection scene. Not validated for three-word ceiling? No — the three-word rule applies to **all** clues regardless of naming entry presence, because `known_text` is the canonical reveal text and its length affects UI space. |

## Acceptance Criteria

1. Every clue in the YAML corpus with `known_text` exceeding three words is rejected by the validator.
2. The YAML validator rejects any item whose full-reveal composition does not match `item_name` exactly (unless no clue on the item carries a naming entry).
3. An unveiled, unverified item's `display_name` assembles from prefix / body / suffix as naming clues are revealed, updating each time a new naming clue enters `revealed_clue_ids`.
4. Veiled items and unveiled items with no revealed naming clues both return `"Unknown Item"` — no category information leaks.
5. When multiple revealed clues compete for the same slot, only the highest-priority clue's `known_text` appears; ties resolve by array order.
6. Verified items always return `item_data.item_name` regardless of which clues have been revealed.
7. Existing save data loads without error; items missing naming field data fall back to `"Unknown Item"` until re-revealed.
8. The generation prompts specify the three-word ceiling, naming entry schema, and slot/priority conventions.
