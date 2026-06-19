# lot_store.gd
# Session-scoped Store for a single lot visit. Holds per-lot mutable state
# (active entry, AP, and win result). Lifetime: created in RunManager.set_lot(),
# replaced by the next call to set_lot(), and readable through reveal.
# Serialized as part of the run_snapshot save section when a lot is active.
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

# ══ Serialization ═════════════════════════════════════════════════════════════


## Encodes local scalar fields into a dictionary for the run snapshot. The caller
## (encode_snapshot) appends item-key arrays on top.
func _encode_fields() -> Dictionary:
    return {
        "_version": _store_version(),
        "lot_id": _lot_entry.lot_data.lot_id if _lot_entry != null and _lot_entry.lot_data != null else "",
        "aggressive_factor": _lot_entry.aggressive_factor if _lot_entry != null else 0.5,
        "price_variance": _lot_entry.price_variance if _lot_entry != null else 1.0,
        "npc_estimate": _lot_entry.npc_estimate if _lot_entry != null else 0,
        "actions_remaining": _actions_remaining,
        "won_price": _won_price,
    }


## Restores local scalar fields from [param data]. Returns false when the lot
## reference cannot be resolved from the aggregate browse pool.
func _restore_fields(data: Dictionary, snapshot_ctx: RunSnapshotContext, ctx: SaveLoadContext) -> bool:
    _actions_remaining = int(data.get("actions_remaining", 0))
    _won_price = int(data.get("won_price", 0))

    var lid: String = str(data.get("lot_id", ""))
    var lot_data := snapshot_ctx.resolve_browse_lot(lid, ctx)
    if lot_data == null:
        return false

    var entry := LotEntry.new()
    entry.lot_data = lot_data
    entry.aggressive_factor = float(data.get("aggressive_factor", 0.5))
    entry.price_variance = float(data.get("price_variance", 1.0))
    entry.npc_estimate = int(data.get("npc_estimate", 0))
    _lot_entry = entry
    return true


## Encodes this LotStore into the owning run snapshot. Item collections are
## stored as indexes into [param snapshot_ctx] so they share identity with
## RunStore collections.
func encode_snapshot(snapshot_ctx: RefCounted) -> Dictionary:
    var run_snapshot_ctx := snapshot_ctx as RunSnapshotContext
    if run_snapshot_ctx == null:
        ToastManager.show_dev_error("LotStore.encode_snapshot requires RunSnapshotContext")
        return _encode_fields()
    var d := _encode_fields()
    d["item_keys"] = []
    d["won_item_keys"] = run_snapshot_ctx.item_keys_for(_won_items)
    if _lot_entry != null:
        for entry: ItemEntry in _lot_entry.item_entries:
            d["item_keys"].append(run_snapshot_ctx.item_key_for(entry))
    return d


## Restores this LotStore from the owning run snapshot. Uses [param snapshot_ctx]
## to resolve aggregate-local references. Returns true on success, false when
## the lot reference cannot be resolved.
func restore_snapshot(
        data: Dictionary,
        snapshot_ctx: RefCounted,
        ctx: SaveLoadContext,
) -> bool:
    var run_snapshot_ctx := snapshot_ctx as RunSnapshotContext
    if run_snapshot_ctx == null:
        ctx.info("LotStore restore requires RunSnapshotContext")
        return false
    var version: int = int(data.get("_version", 1))
    # No migrations yet — pass through for future use.
    data = _apply_migrations(data, version, ctx)

    if not _restore_fields(data, run_snapshot_ctx, ctx):
        return false

    var restored_lot_items: Array[ItemEntry] = []
    if not run_snapshot_ctx.restore_item_refs_into(restored_lot_items, data.get("item_keys", []), ctx, "lot_items"):
        return false
    _lot_entry.item_entries = restored_lot_items

    if not run_snapshot_ctx.restore_item_refs_into(_won_items, data.get("won_item_keys", []), ctx, "lot_won_items"):
        return false

    return true


## Override required by StoreBase. Bump when the dict shape changes.
func _store_version() -> int:
    return 1
