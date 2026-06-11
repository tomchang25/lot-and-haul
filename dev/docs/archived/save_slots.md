# Save Slots — Three Independent Player-Facing Saves

## Goal

Add three player-facing save slots so multiple playthroughs can coexist — today the game has exactly one save, and starting a new game destroys all existing progress. This builds directly on the start-page New Game plan: that plan's provider-reset machinery is the core of slot switching, and its terminology rename frees the word "slot" for this feature.

## Requirements

1. The game has exactly three save slots, each fully independent: its own backup rotation, its own manifest, no shared state. Fixed at three (not configurable, not unlimited) so the picker stays a simple static list and the UI never needs scrolling or slot management chrome.
2. The start page presents New Game and Load Game. New Game is always visible and opens the slot picker over all three slots: picking an occupied slot asks an overwrite confirmation before anything is wiped; picking an empty slot proceeds directly. Load Game is visible only when at least one slot holds data and opens the picker with only occupied slots selectable: picking one loads it and navigates to the hub with no further confirmation.
3. The slot picker shows a per-slot summary — in-game day, cash, and last-played timestamp — and labels empty slots as empty, so the player can tell playthroughs apart without loading them.
4. Boot remains automatic and unconditional: the game loads the last-active slot at startup, exactly as it loads the single save today, so the boot sequence and its validation pass are untouched. Choosing a slot at the start page resets all persistent state and loads (or initializes) the chosen slot using the new-game plan's reset machinery.
5. Existing single-save data migrates into slot 1 on first launch after the update, and the last-active pointer is set to slot 1, so an updating player boots straight into their current progress with nothing visible changed.

## Design

### Disk layout

Each slot keeps its own backup rotation and manifest inside its own per-slot directory, preserving the existing crash-safe write-new-then-update-manifest behavior per slot. A single top-level pointer records the last-active slot. Migration moves the current save directory's contents into slot 1's directory — the same one-time, best-effort pattern as the existing legacy-save migration.

### Boot

The boot sequence is unchanged: load runs unconditionally against the last-active slot. If the pointer is missing or invalid, fall back to the slot containing the newest save; if no slot has data, boot proceeds fresh and the start page shows only New Game.

### Slot selection flow

The picker is one screen with two modes, differing only in which slots are selectable and what picking does:

- **New-game mode** (from New Game): all slots selectable. Occupied slot → overwrite confirmation ("Start a new game in slot N? Its progress will be lost.") → on confirm: wipe that slot's directory, reset all persistent providers, clear session state, set the last-active pointer, write a fresh save, navigate to the hub. Empty slot → same sequence without the confirmation or the wipe.
- **Load mode** (from Load Game): only occupied slots selectable. Picking one: reset all persistent providers, load that slot, set the last-active pointer, navigate to the hub. The reset-then-load runs even when the picked slot is the one boot already loaded — one uniform code path, and reloading the already-loaded slot is harmless.

Both modes funnel through the same reset machinery the start-page plan introduces; the only variable is whether the slot's state comes from defaults or from disk.

### Slot summary metadata

Each slot's manifest carries a summary block — in-game day, cash, last-played timestamp — refreshed on every save, so the picker renders from three small manifest reads without parsing full save payloads. When the summary is absent (a slot migrated from the pre-summary format), the picker parses that slot's newest save file once as a fallback and shows the values it finds.

## Non-Goals

1. No standalone delete-slot action in the picker. Overwriting via New Game is the only destructive operation — it already carries a confirmation, and a separate delete adds a second destructive flow for marginal benefit. Can be added later if wanted.
2. No slot copy or duplicate.
3. No in-game slot switching or return-to-title flow — the start page remains the boot scene only, so slot choice happens only at launch.
4. No change to the per-slot backup rotation behavior: rotation count, crash-safety, and corrupt-file fallback work per slot exactly as they work for the single save today.

## Acceptance Criteria

1. Fresh install: the start page shows New Game only. New Game opens a picker with three empty slots; picking any one navigates to the hub with all stores at default state, and that slot becomes the last-active slot.
2. With data in slot 1 only: Load Game is visible; its picker allows selecting only slot 1; picking it loads that progress and navigates to the hub.
3. New Game on an occupied slot shows the overwrite confirmation. Canceling returns to the picker with no state changed. Confirming wipes only that slot — the other slots' data is untouched — and starts fresh in it.
4. Updating from a single-save build: the previous progress appears as slot 1 with a correct summary, the game boots straight into it, and no warning is shown.
5. After playing in slot 2 and quitting, relaunching boots into slot 2 automatically.
6. The picker shows day, cash, and last-played timestamp for every occupied slot, including a slot freshly migrated from the pre-summary format.
