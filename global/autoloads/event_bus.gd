# event_bus.gd
# Project-wide signal hub. Autoloaded first so all other autoloads can connect.
# Signals are grouped by the phase that emits them.
extends Node

@warning_ignore_start("unused_signal")

# ── Hub-phase business events ─────────────────────────────────────────────────
# Emitted by MetaManager after each transactional commit point.
# KnowledgeManager subscribes to award mastery XP without a direct import.

## Emitted after a customer sale is fully committed (cash added, items removed).
## [param category] — CategoryData of the sold item.
## [param rarity] — rarity of the sold item.
signal sale_resolved(category: CategoryData, rarity: ItemData.Rarity)

## Emitted after one Repair AP-action is applied and saved.
## [param category] — CategoryData of the repaired item.
## [param rarity] — rarity of the repaired item.
signal item_repaired(category: CategoryData, rarity: ItemData.Rarity)

## Emitted after one Restore AP-action is applied and saved.
## [param category] — CategoryData of the restored item.
## [param rarity] — rarity of the restored item.
signal item_restored(category: CategoryData, rarity: ItemData.Rarity)

@warning_ignore_restore("unused_signal")
