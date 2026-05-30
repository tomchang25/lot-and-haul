## Goal

Regenerate all existing clue and item YAML content to conform to Phase 8's naming system. Current clue known_text values are full sentences; they must be replaced with three-word-or-fewer descriptive phrases, and each clue must be evaluated for a naming entry assignment. This is a bulk content pass that depends on the generation rules and runtime system from Phase 8 being finalized first.

## Requirements

1. Clue text rewrite — every existing clue in the project has its known_text replaced with a phrase of three words or fewer that captures the same observation in shorthand form.
2. Naming entry assignment — every clue is evaluated for whether it should carry a naming entry. Clues that contribute to the item's progressive display name receive a slot (prefix, body, or suffix) and a priority value. Clues that are purely mechanical (price-only) receive no naming entry.
3. Item name reconciliation — after clue rewrites and naming entry assignments, each item's authored item_name is adjusted if necessary so that the fully-resolved composition (all naming entries applied) produces an exact match.
4. Validation pass — the updated YAML validator is run against the full dataset. Every item must pass the naming-match check and every clue must pass the three-word limit check with zero errors before the content pass is considered complete.

## Non-Goals

1. Adding new items or clues — this pass rewrites existing content only.
2. Changing price effects — effect_op and effect_amount values are not modified.
3. Schema or runtime changes — those belong to Phase 8 proper.

## Acceptance Criteria

1. Every clue in the project has known_text of three words or fewer.
2. Every clue that participates in naming carries a valid naming entry with slot and priority.
3. The YAML validator reports zero naming-match errors across all items.
4. The YAML validator reports zero known_text length violations across all clues.
5. No item's price behavior changes — effect_op and effect_amount values are identical before and after the content pass.
