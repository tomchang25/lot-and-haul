# Affix-Only Item Naming (Spec B)

Implements the naming half of `item_affix_generation.sketch.md`: the display name is composed purely from an item's affixes plus its anchor body, and the per-clue / per-anchor naming fields are removed entirely. Depends on Spec A (`item_affix_generation_core.spec.md`), which puts `affixes` on `ItemEntry` and gives each affix a `display_name` + `naming_slot`.

## Goal

Make an item's display name a function of its affix set and anchor only, so the name reveals exactly which affixes are attached (and thus the set of combinations the item could hold) and nothing else. Clues stop participating in naming; the old per-clue `naming_slot`/`naming_priority` override machinery is deleted.

## Relational Context

- `ItemEntryDisplayHelper.display_name()` (`item_entry_display_helper.gd:19-73`) is the sole naming composer. A `Grep` for `naming_slot`/`naming_priority` across all `.gd` returns only the two resource definitions and this helper (`:34`, `:37-38`) — no scene reads the fields. The ~10 call sites invoke `display_name()` / `sort_value(NAME)` (`:189-190`), not the fields, so **call sites do not change**; only the helper's internals and the pool it consumes change.
- `ItemEntry.get_naming_clue_pool()` (`item_entry.gd:123-132`) supplies the composer. Today it returns the anchor (when `unveiled`) plus revealed `ClueData`. After this spec it returns the anchor (body) plus the item's `affixes` (prefix/suffix), and no clues. Affixes are gated on `unveiled` exactly as the anchor is (`:127`), so veiled items still compose to nothing.
- `AnchorData.known_text` (`anchor_data.gd:11-12`) remains the body and the sole body source; with clues gone from naming there is no longer a body contest, so `AnchorData.naming_priority` (`:16`) is dead and is removed.
- `AffixData.naming_slot` + `display_name` (created in Spec A) are the only source of prefix/suffix text. The composer reads them directly instead of `ClueData.naming_slot`/`known_text`.
- Designer naming fields are written and parsed by the pipeline `EntitySpec`s — `clue.py` (naming_slot/naming_priority build+parse+validate) and `anchor_data.py:75,100` (naming_priority). Removing the runtime `@export`s requires removing the matching pipeline fields and the authored YAML values in lockstep, or `validate_yaml.py` / round-trip will diverge.

## Plan Friction

- Settled: the codebase naming system is clue-driven, contradicting the sketch's affix-only design. `display_name()` (`item_entry_display_helper.gd:19-73`) runs a prefix/body/suffix priority contest across anchor + revealed clues. It is rewritten to concatenate affix `display_name`s around the anchor body with no priority contest. The "best priority wins per slot" logic (`:21-56`) is deleted.
- Settled: `ClueData` carries `naming_slot` (`clue_data.gd:21`) and `naming_priority` (`:24`); `AnchorData` carries `naming_priority` (`anchor_data.gd:16`). All three `@export`s are removed. Their only reader is the helper (verified by `Grep`), so removal is self-contained on the runtime side.
- Settled: the pipeline writes these fields — `clue.py` build/parse plus a `naming.slot ∈ {prefix,body,suffix}` format check, and `anchor_data.py:75` (write) / `:100` (parse) for `naming_priority`. All are removed, and the authored values are stripped from `data/yaml/clues.yaml` (30+ clue entries and every anchor's `naming_priority`).
- Settled: the `TODO.md` Chore "[data] Display name of clues need more diversity of priority…" is obsoleted by this spec (clues no longer have naming priority) and is deleted from `TODO.md` as part of this work.
- No further friction found between the sketch and the codebase for naming.

## Design Gaps

- **Plain-item display.** With no affix and no clue naming, a plain item's pool is just the anchor body. `display_name()` already handles a body with no qualifier by returning `"Unknown " + body` (`item_entry_display_helper.gd:69-71`). Resolution: keep that fallback verbatim — a plain item reads e.g. "Unknown Bag", which correctly signals an unremarkable/unidentified item and matches the sketch's "plain = mediocre" intent.
- **Multi-affix ordering.** Spec A allows more than one prefix/suffix in the data model. Resolution: the composer concatenates prefixes in `affixes` list order, then the body, then suffixes in list order — no priority field, order is draw/list order. For the current 0–1-per-slot draw policy this is at most one of each.
- **Veiled items.** Resolution: include affixes in the naming pool only when `unveiled`, mirroring the anchor gate (`item_entry.gd:127`); a veiled item composes to "Unknown Item" (`item_entry_display_helper.gd:66-67`) unchanged. Reading the name to inform bidding therefore applies to unveiled items, consistent with existing veil semantics.

## Scope

### Included

- Rewrite `display_name()` to compose from affixes + anchor body only.
- Update `get_naming_clue_pool()` to return anchor + affixes (unveil-gated), no clues.
- Remove `naming_slot`/`naming_priority` from `ClueData`, `naming_priority` from `AnchorData`.
- Remove the matching pipeline fields/validation and strip the authored values from `clues.yaml`.
- Delete the obsoleted naming-priority Chore from `TODO.md`.

### Excluded

- Affix/combination generation and `AffixData`/`AffixCombinationData` (Spec A).
- Combination-specific or "preferred" names — names live on affixes only (settled in the sketch).
- The knowledge dictionary and any name-collection UI (deferred Spec C).
- Naming-group pools for leftover single clues (removed from the design — see sketch).

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `game/shared/item_display/item_entry_display_helper.gd` | Medium | Rewrite `display_name()`: concatenate affix `display_name`s (by slot, list order) around the anchor body; drop the priority contest; keep the no-qualifier fallback. |
| `common/gameplay/instance/item_entry.gd` | Small | `get_naming_clue_pool()` returns anchor + affixes (unveil-gated), no clues. |
| `data/definitions/clue_data.gd` | Small | Remove `naming_slot` and `naming_priority`. |
| `data/definitions/anchor_data.gd` | Small | Remove `naming_priority`. |
| `dev/tools/tres_lib/entities/clue.py` | Medium | Remove naming_slot/naming_priority build, parse, and the slot format validation. |
| `dev/tools/tres_lib/entities/anchor_data.py` | Small | Remove `naming_priority` build (`:75`) and parse (`:100`). |
| `data/yaml/clues.yaml` | Medium | Strip `naming_slot`/`naming_priority` from all clue entries and `naming_priority` from all anchors. |
| `TODO.md` | Small | Delete the obsoleted naming-priority Chore. |

## Implementation Notes

- **Composer shape.** Read each affix's `naming_slot` and `display_name`; bucket into prefixes/suffixes preserving list order; body is `anchor.known_text`. Result: `prefixes + [body] + suffixes` joined by spaces. Retain the existing empty-pool → "Unknown Item" and no-qualifier → "Unknown {body}" branches (`item_entry_display_helper.gd:66-71`) so plain and veiled items are unchanged in shape.
- **Pipeline parity.** Remove the YAML fields and the pipeline read/write in the same change, then run `validate_yaml.py` and a `yaml_to_tres` → `tres_to_yaml` round-trip to confirm no field drift. Generated `.tres` are gitignored and rebuilt — do not hand-edit them (`CLAUDE.md`).
- **Do not touch rarity-colored naming.** `display_name_color()` (`item_entry_display_helper.gd:166-182`) keys off `rarity`/`verified`, not naming fields — leave it alone.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Plain item (no affix) | "Unknown {body}", e.g. "Unknown Bag". |
| Veiled item | "Unknown Item" — affixes excluded from the pool until unveiled. |
| Two prefixes (future multi-affix policy) | Concatenated in list order; no priority arbitration. |
| Item with affixes but unveiled state false | Composes as veiled until unveiled, same as the anchor gate. |

## Acceptance Criteria

1. An item's displayed name is composed only from its attached affixes and anchor body; no clue affects the name.
2. Two items with the same affix set display the same name regardless of which combination (and thus which clues) they hold.
3. A plain item displays a name derived solely from its anchor; a veiled item displays "Unknown Item".
4. `naming_slot` and `naming_priority` no longer exist in the runtime resources, the YAML source, or the pipeline, and the YAML build/validation still passes.
5. Existing scenes render item names with no call-site changes.
