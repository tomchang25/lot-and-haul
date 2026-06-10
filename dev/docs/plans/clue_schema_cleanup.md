# Clue Schema Cleanup — Anchor Extraction, Base/Override Split, Three-Way Item Lists

Successor to `../archived/clue_schema_content_standard.md` (+ its spec). The code that landed from that overhaul (anchor-sourced physical data, global add-then-mul with override branch, rarity == hidden count, validator suite, verified bonus ×1.05) is the foundation; this plan corrects the schema's remaining structural problems. The content side (generation standard, prompts, reference tables, full regeneration) is split into `clue_content_standard_regen.md` and runs after this plan ships.

## Goal

Correct the clue schema's structure: anchors leave the clue type and become their own designer resource, base value separates from price modifiers, item clue lists split by kind, the half-built surface-draw affinity fields are removed, and the existing content is mechanically converted so the game runs unchanged on the new schema. Creative content work is deliberately excluded — it follows in the successor content plan.

## Requirements

1. Anchor extraction: anchors become their own designer resource type carrying known text, category scope, base value, cargo shape, sprite reference, weight in kg, value tier (1–5), and a naming priority. They carry no discovery attribute/DC, no effect op, and no exclusive group. The clue type domain reduces to surface/hidden. Why: after the base split, none of the clue machinery (discovery rolls, price modifiers) applies to anchors — one schema holding two half-empty halves repeats the "flat" double-meaning problem at type level, and today's per-type conditional pipeline writes plus "anchor must have / others must not have" validators are its running cost.
2. Base/modifier separation: the anchor's value is a dedicated base-value field, not an effect. Clue effect ops become `add | mul | override`, where `override` (rename of hidden "flat") is hidden-only base replacement. At most one override per item, enforced as a standalone validator limit independent of exclusive groups.
3. Item composition splits into three fields: one anchor reference, a surface clue list, and a hidden clue list. The exactly-one-anchor, hidden-after-surface ordering, and per-kind field validators become by-construction guarantees and are deleted. A new check replaces them: each list may only reference clues of its declared type.
4. Naming behavior is preserved: the anchor always contributes the body slot at its stored priority (a hidden body-naming clue still displaces it at higher priority); same-priority ties resolve anchor → surface list order → hidden list order, matching today's array-order rule.
5. Item-level veiled state replaces anchor-reveal tracking: with anchors no longer being clues, "revealing the anchor" stops being a meaningful concept — the item-level flag's semantics become `unveiled`. A veiled item is a fully unknown covered object: its cargo shape (and weight, for packing systems) remains observable, identity data (display name, value, sprite) stays masked exactly as today; unveiling reveals which anchor variant the item is. Anchor ids leave the revealed-clue-id list, the stale-anchor-id re-add special casing in save loading is deleted, and loading accepts the legacy persisted keys (the old anchor-revealed flag and the older `inspected` field) unchanged.
6. The surface draw affinity fields (affinity tags + per-tag weights) are dropped from schema and pipeline as part of the rewrite. Why: the fields are half-wired (written to generated resources but never parsed back — a yaml→tres→yaml round trip silently drops them — undocumented in the generation prompt, unvalidated, and with no runtime consumer), and the underlying draw design is unsettled. The design question (anchor-conditioned surface drawing) lives in its own Draft; prompt and content consequences belong to the successor content plan.
7. Existing YAML content is mechanically converted to the new schema — anchor clues become anchor resources, each item's clue list splits into anchor/surface/hidden fields, hidden "flat" renames to "override" — with no content redesign: ids, values, and naming data are preserved so the behavior-equivalence criteria below can actually be checked against today's game.

## Design

### Anchor resource

| Field | Meaning |
| --- | --- |
| anchor id | unique id, referenced by items |
| known text | display text; always the default body naming slot |
| naming priority | compared against hidden body-naming clues for displacement |
| category scope | the category this variant belongs to (pool scope for the future generator) |
| base value | the item's starting value — the base term of the price pipeline |
| shape id / sprite / weight kg | physical identity (cargo grid, rendering, weight limits) |
| tier (1–5) | value tier consumed by future lot/location tier weight curves |

Anchors are authored in their own YAML section. Items reference `anchor_id`, `surface_ids`, `hidden_ids`; rarity must still equal the hidden list length.

### Price resolution (same math, corrected terms)

```
appraised = (anchor.base_value + Σ revealed surface adds) × Π revealed surface muls
verified  = ((override.amount | anchor.base_value) + Σ surface adds + Σ hidden adds)
            × Π surface muls × Π hidden muls
```

Global add-then-mul as already landed; the only change is that the base term reads a dedicated field instead of an anchor "flat" effect, and the override branch matches on the `override` op instead of type-filtered "flat".

### Validator delta

Deleted (now structural): exactly one anchor; anchor occupies body slot; hidden-after-surface ordering; anchor-must-have physical fields; physical fields forbidden on clues; flat forbidden on surface. Kept or re-keyed: at most one override per item; exclusive-group uniqueness; hidden count == rarity; non-zero effect amounts on clues; structural naming (body + at least one qualifier, non-empty composition); known-text word cap; anchor physical-field validity (now on the anchor resource). New: list/type agreement (surface list references surface clues, hidden list hidden clues); override op only on hidden clues.

### Save and content compatibility

Existing load behavior covers everything: stale clue ids (including old anchor ids in revealed lists) are stripped, entries for removed item ids are dropped with a warning, and the veiled flag is already persisted (loading keeps accepting the legacy key names). No new migration machinery. The mechanical YAML conversion preserves all ids, so pre-conversion saves still resolve their items and clues.

## Non-Goals

1. No pool generator runtime, tier curves, or rarity frequency tables.
2. No anchor-conditioned surface drawing — deferred to its Draft until the model (who declares tags, how weights derive) is settled.
3. No combination naming rules; no conditional clues (already rejected in the superseded plan).
4. No item-entry layer split or manager-mediated mutation refactor — separate pending flow.
5. No changes to rarity semantics, knowledge XP, or the verified sell bonus beyond what already landed.
6. No generation-prompt rewrite, reference tables, draw-rule documentation, or creative content regeneration — all of it belongs to `clue_content_standard_regen.md`, which runs once this schema is stable.

## Acceptance Criteria

1. No clue iteration anywhere branches on an anchor type; the clue type domain is surface/hidden only; the pipeline contains no per-type conditional field writing for anchors.
2. The effect op domain is add/mul/override; override appears only on hidden clues and at most once per item; an item's base value comes only from its anchor's base-value field.
3. Item definitions carry anchor/surface/hidden as three fields, and a yaml→tres→yaml round trip is lossless on every authored field (this is the check the affinity fields failed).
4. For an identical reveal state, display names and resolved prices match the pre-split implementation exactly; a veiled item exposes shape (and weight to packing systems) and nothing else, matching today's masking.
5. No affinity tag or tag weight field remains in schema, pipeline, or generated data.
6. The mechanically converted content set passes validation and the game plays identically on it — same items, names, values, reveal behavior.
7. Pre-overhaul saves load without crashing; veiled/unveiled state survives via the flag (legacy keys accepted); stale ids strip silently.
