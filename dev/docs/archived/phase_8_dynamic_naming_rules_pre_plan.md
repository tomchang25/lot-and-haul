## Goal

Replace the current binary display name (generic anchor text vs. full verified name) with a priority-based affix composition system. Each clue carries short descriptive text and an optional naming slot, so the item's visible name assembles progressively as clues are revealed — prefix, body, suffix — giving the player a tangible sense of identification progress.

## Requirements

1. Short clue text constraint — the YAML generation rules and validator enforce that all clue known_text is three words or fewer. This text serves double duty as the clue's reveal description and its contribution to the display name when the clue has a naming slot.
2. Naming entry on clues — each clue carries an optional naming entry that declares a slot (prefix, body, or suffix) and an integer priority. Clues without a naming entry do not participate in name composition.
3. Priority-based slot resolution — when multiple revealed clues target the same slot, the highest-priority clue wins that slot. Only one value per slot appears in the final name.
4. Display name composition — the runtime item entry assembles its display name by concatenating the winning prefix, body, and suffix from revealed clues. Veiled items continue to show the category-prefixed generic label. Verified items bypass composition and show the authored item name directly.
5. Naming-match validation — the YAML validator simulates full reveal (all clues present) and checks that the composed name matches the authored item name. A mismatch is a validation error.
6. Generation rule updates — the YAML generation prompts are updated to document the three-word constraint, naming entry authoring rules, and slot/priority conventions. The YAML-to-TRES converter handles the new naming entry fields. Actual content regeneration is a separate effort.

## Non-Goals

1. Combination-based naming rules — clue interaction effects on naming (e.g. two clues combining into a different word) are deferred to a future phase.
2. Pool-based or procedural item generation.
3. Changes to the price pipeline — naming entries are purely cosmetic and do not affect value computation.
4. UI layout or widget changes — display name consumers already read a single computed property; no new UI work is in scope.
5. Regenerating existing YAML content — updating all existing clue and item data to conform to the new rules is handled as a separate content pass.

## Acceptance Criteria

1. The YAML generation prompts specify the three-word known_text limit, naming entry schema, and slot/priority conventions.
2. The YAML validator rejects any clue whose known_text exceeds three words.
3. An unveiled, unverified item's display name updates each time a clue with a naming entry is revealed, assembling from prefix, body, and suffix slots based on priority.
4. When all clues on an item are revealed, the composed display name matches the authored item name exactly.
5. Verified items always show the authored item name, regardless of which clues have been revealed.
6. Veiled items continue to show the category-prefixed generic label with no information leakage from unrevealed naming entries.
7. When multiple revealed clues compete for the same slot, only the highest-priority clue's text appears.
8. The YAML validator rejects any item whose fully-resolved composition does not match its authored item name.
9. Existing save data loads without error; items missing naming entry data fall back to category label until re-revealed.
