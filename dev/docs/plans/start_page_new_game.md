# Start Page — Separate New Game and Continue Paths

## Goal

Split the start page's single Play button into distinct New Game and Continue actions so a player can begin a fresh game without manually deleting save files. Today both paths execute the same transition, making New Game unreachable whenever any save data exists on disk.

## Requirements

1. The start page presents two buttons — Continue and New Game — instead of a single Play button whose label toggles. Continue is visible only when save data exists; New Game is always visible. This removes the ambiguity of a single button that claims to do one thing but does another.
2. Selecting New Game when save data exists triggers a confirmation dialog ("Start a new game? Current progress will be lost.") before any state is wiped. Selecting New Game when no save data exists proceeds directly — no dialog needed for a no-op confirmation.
3. Starting a new game wipes all existing save files from disk, resets every persistent gameplay store to its initial state, writes a fresh save, and navigates to the hub. The old save files are removed rather than retained as stale counter slots, because keeping them would leave orphaned data and confuse the save-rotation counter.
4. The Continue path is unchanged from today: load the existing save (already done at boot) and navigate to the hub. No additional loading or state manipulation.
5. Session-scoped state (active run, active lot) is cleared before the new-game save is written, so a fresh save never carries stale run data.
6. Rename the save system's internal "slot" terminology to backup/counter naming. Today "slot" means the rotating backup counter, which collides with both the storage slot economy and the upcoming player-facing save slots (see the save-slots plan); freeing the word now means the slot plan starts from clean vocabulary. The rename is internal plus one manifest field: on-disk backup filenames are unchanged, and the manifest field that records the newest backup is renamed with a read-side fallback that still accepts the old field name, so existing manifests keep working without migration.

## Design

The boot sequence already loads save data unconditionally via the game manager autoload. The start page reads whether a save exists and uses that to decide button visibility. The new-game path adds a reset step between the player's confirmation and the hub transition:

- **Wipe**: delete all counter-based save files and the manifest from disk.
- **Reset providers**: the persistence coordinator iterates its registered providers and calls a reset method on any that implement it. Each provider re-instantiates its stores to defaults — identical to its own initialization body. Non-persistent state (static registries, signal connections) is left untouched.
- **Clear session state**: the run-phase manager clears its active run and lot references, since it is not a registered save provider and would otherwise be missed by the provider iteration.
- **Save**: write a fresh save file (slot 1) so the next boot finds valid data and does not show a "starting fresh" warning.

The confirmation dialog follows the existing codebase pattern: a ConfirmationDialog node declared in the scene file, grabbed by the script, configured with dialog text, and shown via popup_centered. The confirmed signal triggers the new-game sequence.

## Non-Goals

1. Do not add a save-slot selection screen or multiple save slots here. The game has a single save in this plan; new game replaces it. Real save slots are the follow-up save-slots plan, which reuses this plan's provider-reset machinery as its slot-switching core.
2. Do not add a "return to title" flow from within gameplay. The start page is the boot scene only; there is no in-game path back to it.
3. Do not change the boot sequence or the game manager's unconditional load. The start page handles the new-game decision after boot completes.
4. Do not add a reset method to the store base class. Only the two managers that own persistent stores need reset; individual stores are re-instantiated by their owning manager.

## Acceptance Criteria

1. With no save file present, the start page shows only the New Game button (Continue is hidden). Pressing New Game navigates to the hub with all stores at default state.
2. With a save file present, the start page shows both Continue and New Game. Pressing Continue navigates to the hub with the existing save data intact.
3. Pressing New Game with a save file present shows a confirmation dialog. Confirming wipes all save files, resets all persistent state, writes a fresh save, and navigates to the hub. Canceling returns to the start page with no state changes.
4. After a new game, the hub reflects default state: zero cash, no storage items, no owned cars, day 0, no knowledge progression.
5. After a new game, the start page (if returned to via quit and relaunch) shows only New Game (no save existed before the fresh save was written, but the fresh save now exists — so Continue appears, and New Game again triggers confirmation).
6. A save directory written by the previous build (old manifest field name) still loads correctly after the terminology rename, with no warning and no data loss.
