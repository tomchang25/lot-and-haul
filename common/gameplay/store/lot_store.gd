# lot_store.gd
# Session-scoped Store for a single lot visit. Holds per-lot mutable state
# (active entry, AP, and win result). Lifetime: created in RunManager.set_lot(),
# replaced by the next call to set_lot(), and readable through reveal.
# Carries no save payload.
class_name LotStore
extends StoreBase

# ── Backing variables ──────────────────────────────────────────────────────────

var _lot_entry: LotEntry
var _actions_remaining: int = 0
var _won_items: Array[ItemEntry] = []
var _won_price: int = 0

# ── Getters (read-public) ──────────────────────────────────────────────────────

var lot_entry: LotEntry:
    get:
        return _lot_entry

## Shallow duplicate of the active lot's items (ItemEntry refs shared).
## Derived from lot_entry.item_entries. Empty when no lot is active.
var lot_items: Array[ItemEntry]:
    get:
        return _lot_entry.item_entries.duplicate() if _lot_entry else [] as Array[ItemEntry]

## Current spendable AP for this lot.
var actions_remaining: int:
    get:
        return _actions_remaining

## Shallow duplicate of items won at auction for this lot.
## Empty when the auction was lost or not yet resolved.
var won_items: Array[ItemEntry]:
    get:
        return _won_items.duplicate()

## Price paid at auction for this lot. 0 when auction was lost.
var won_price: int:
    get:
        return _won_price

# ══ Construction ══════════════════════════════════════════════════════════════


## Initializes this LotStore for [param p_entry] with [param p_initial_ap]
## spendable AP. Called once by RunManager immediately after LotStore.new().
func initialize(p_entry: LotEntry, p_initial_ap: int) -> void:
    _lot_entry = p_entry
    _actions_remaining = p_initial_ap

# ══ Mutations ══════════════════════════════════════════════════════════════════


## Deducts [param cost] AP from the inspection pool for this lot.
## Clamped at 0 — AP never goes negative.
func deduct_ap(cost: int) -> void:
    _actions_remaining = maxi(_actions_remaining - cost, 0)


## Records a won auction: saves [param items] and [param price] as this lot's
## win result. Called by RunManager.commit_lot_win() on player victory.
func record_win(items: Array[ItemEntry], price: int) -> void:
    _won_items = items.duplicate()
    _won_price = price
