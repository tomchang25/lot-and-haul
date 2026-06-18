# event_bus.gd
# Project-wide signal hub. Autoloaded first so all other autoloads can connect.
# Signals are grouped by the phase that emits them.
extends Node

@warning_ignore_start("unused_signal")

# ── Hub-phase business events ─────────────────────────────────────────────────
# Emitted by MetaManager after each transactional commit point.
# KnowledgeManager subscribes to award mastery XP without a direct import.

## Emitted after a customer sale is fully committed (cash added, items removed).
## [param entry] — the sold ItemEntry.
signal sale_resolved(entry: ItemEntry)

## Emitted after one Repair AP-action is applied and saved.
## [param entry] — the repaired ItemEntry.
signal item_repaired(entry: ItemEntry)

## Emitted after one Restore AP-action is applied and saved.
## [param entry] — the restored ItemEntry.
signal item_restored(entry: ItemEntry)

# ── Run-phase business events ─────────────────────────────────────────────────
# Emitted by MetaManager after run resolution is fully committed.

## Emitted after a completed run is resolved: cash applied, cargo registered,
## run state cleared. [param result] — the RunResult snapshot that was consumed.
signal run_resolved(result: RunResult)

# ── Save lifecycle events ────────────────────────────────────────────────────

## Emitted after SaveManager resets persistent providers for a new slot, loaded
## slot, or test slot. Runtime-only systems use this to discard stale state.
signal save_runtime_reset

# ── Reveal-type business events ────────────────────────────────────────────────
# Emitted by the owning Manager after a successful reveal-during-play mutation.
# KnowledgeManager subscribes to award mastery XP without a direct import.

## Emitted after an item's veil is lifted (first reveal during inspection or
## lot reveal). [param entry] — the ItemEntry that was unveiled.
signal item_unveiled(entry: ItemEntry)

## Emitted after a surface or hidden clue is revealed through play during a
## run. [param entry] — the ItemEntry whose clue was revealed.
signal item_revealed(entry: ItemEntry)

# ── Tutorial events ──────────────────────────────────────────────────────────
# Generic signal for semantic tutorial milestones. Gameplay emits; flow layer
# subscribes. No gameplay system references tutorial copy or step order.

## Emitted when a semantic gameplay milestone occurs. [param event_id] matches
## TutorialEvents constants; [param payload] is reserved for future use.
signal tutorial_event(event_id: StringName, payload: Dictionary)

@warning_ignore_restore("unused_signal")
