# shop_session_store.gd
# Shop-session runtime store: in-flight state of the customer_sell scene -
# the active customer id, the items placed in that customer's car grid, and
# the boot-routing pointer that tells the start page to resume the shop
# scene on Load Game. Serializable state slice held by MetaManager.
#
# Owns the fields and their save payload. Fields are read-public via
# getters. Mutation goes through the owning Manager only.
class_name ShopSessionStore
extends StoreBase

const SCENE_CUSTOMER_SELL: String = "customer_sell"

var _active_customer_id: String = ""

## Per-item entries: {"item_id": int, "cell": {"x": int, "y": int}, "rotation": int}.
## Empty when no shop is in flight or the active customer has no placements.
var _placement: Array = []

## "customer_sell" while a shop is in flight, "" otherwise. Read by the boot
## router to decide whether to land in the shop scene after Load Game.
var _pending_scene: String = ""

## Customer id of the active customer, or "" when no shop is in flight.
## Read-only externally.
var active_customer_id: String:
    get:
        return _active_customer_id

## Shallow duplicate of the placement list. Read-only externally.
var placement: Array:
    get:
        return _placement.duplicate(true)

## "customer_sell" while a shop is in flight, "" otherwise. Read-only externally.
var pending_scene: String:
    get:
        return _pending_scene


## True when this store represents a resumeable shop session.
func has_session() -> bool:
    return _pending_scene == SCENE_CUSTOMER_SELL


## Returns the top-left cell stored for [param item_id], or Vector2i(-1, -1)
## when the item is not in the current placement. Read-only.
func cell_for_item(item_id: int) -> Vector2i:
    for p: Variant in _placement:
        if p is Dictionary and int(p.get("item_id", -1)) == item_id:
            var cell_dict: Dictionary = p.get("cell", { })
            return Vector2i(
                int(cell_dict.get("x", -1)),
                int(cell_dict.get("y", -1)),
            )
    return Vector2i(-1, -1)


## Returns the rotation stored for [param item_id], or 0 when the item is
## not in the current placement. Read-only.
func rotation_for_item(item_id: int) -> int:
    for p: Variant in _placement:
        if p is Dictionary and int(p.get("item_id", -1)) == item_id:
            return int(p.get("rotation", 0))
    return 0


## Section id for the shop_session save payload.
func section_id() -> String:
    return "shop_session"


## Serializes shop-session state to a save payload.
func to_dict() -> Dictionary:
    return {
        "_version": _store_version(),
        "active_customer_id": _active_customer_id,
        "placement": _placement.duplicate(true),
        "pending_scene": _pending_scene,
    }


## Restores shop-session state. Pre-feature saves (no shop_session section)
## load with no migration warning - the defensive reads default to empty.
func from_dict(data: Dictionary, _ctx: SaveLoadContext) -> void:
    var version: int = int(data.get("_version", 1))
    data = _apply_migrations(data, version, _ctx)
    _active_customer_id = str(data.get("active_customer_id", ""))
    _pending_scene = str(data.get("pending_scene", ""))
    _placement = []
    if data.has("placement") and data["placement"] is Array:
        for p: Variant in data["placement"]:
            if p is Dictionary:
                _placement.append(p.duplicate())

# ══ Mutators - called only from MetaManager wrappers ══════════════════════════


## Sets the active customer id. Pass "" to clear. Does not save.
func set_active_customer(customer_id: String) -> void:
    _active_customer_id = customer_id


## Replaces the placement list with a deep-duplicate of [param value].
## Does not save.
func set_placement(value: Array) -> void:
    _placement = value.duplicate(true)


## Sets the boot-routing pointer. Use [constant SCENE_CUSTOMER_SELL] for an
## open shop, "" for none. Does not save.
func set_pending_scene(value: String) -> void:
    _pending_scene = value


## Resets all fields to defaults. Does not save.
func clear() -> void:
    _active_customer_id = ""
    _placement = []
    _pending_scene = ""


func _store_version() -> int:
    return 1
