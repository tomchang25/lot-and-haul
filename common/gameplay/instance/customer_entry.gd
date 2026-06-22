# customer_entry.gd
# Runtime value object representing a single nightly customer visit.
# Each customer arrives with demand tags (clue ids they want to buy) and a car
# grid (how much cargo space they have). Holds a live CustomerData reference
# for persona attributes; the reference is serialised as customer_data_id and
# re-resolved on load.
class_name CustomerEntry
extends RefCounted

# ── State ──────────────────────────────────────────────────────────────────────

## Runtime session id (e.g. "cust_abc123"). Used for shop session tracking and
## sale ledger records. Distinct from CustomerData.customer_id (the authored
## persona id such as "repair_hobbyist").
var session_id: String = ""

## The authored persona definition. May be null only for generator fallback when
## customer data is missing.
var customer_data: CustomerData = null

## Human-readable name derived from the template's display_name_key.
var display_name: String:
    get:
        if customer_data != null:
            return TranslationServer.translate(customer_data.display_name_key)

        ToastManager.show_warning("CustomerEntry.display_name: no customer data")
        return ""

var grid_columns: int = 2
var grid_rows: int = 2

## Clue ids (tags) the customer is looking to buy. A clue's id IS its tag
## an item fits when its revealed clue ids intersect these.
var demand_tags: Array[String] = []

## Surface-negative (mul < 1.0) clue ids this customer visit values.
## Copied from CustomerData.valued_negative_tags at generation time.
## Empty when the persona has no valued-negative preferences.
var valued_negative_tags: Array[String] = []

# ══ Serialisation ══════════════════════════════════════════════════════════════


## Serializes this entry to a save payload. The customer_data reference is
## written as customer_data_id (the authored persona id) and re-resolved on
## load via CustomerRegistry.
func to_dict() -> Dictionary:
    return {
        "session_id": session_id,
        "customer_data_id": customer_data.customer_id if customer_data != null else "",
        "grid_columns": grid_columns,
        "grid_rows": grid_rows,
        "demand_tags": demand_tags.duplicate(),
        "valued_negative_tags": valued_negative_tags.duplicate(),
    }


## Restores an entry from a save payload and re-resolves the customer_data
## reference via CustomerRegistry when a customer_data_id is present.
static func from_dict(d: Dictionary) -> CustomerEntry:
    var c := CustomerEntry.new()
    c.session_id = str(d.get("session_id", ""))
    c.grid_columns = int(d.get("grid_columns", 2))
    c.grid_rows = int(d.get("grid_rows", 2))
    var raw: Array = d.get("demand_tags", [])
    c.demand_tags.assign(raw.duplicate())
    var raw_vnt: Array = d.get("valued_negative_tags", [])
    c.valued_negative_tags.assign(raw_vnt.duplicate())

    var data_id: String = str(d.get("customer_data_id", ""))
    if not data_id.is_empty():
        c.customer_data = CustomerRegistry.get_customer_by_id(data_id)
    return c


## Factory. Creates a new entry from an authored CustomerData template, a
## runtime session id, a rolled grid shape, and drawn demand tags.
static func create(data: CustomerData, sid: String, grid_size: Vector2i, tags: Array[String]) -> CustomerEntry:
    var c := CustomerEntry.new()
    c.customer_data = data
    c.session_id = sid
    c.grid_columns = grid_size.x
    c.grid_rows = grid_size.y
    c.demand_tags = tags.duplicate()
    c.valued_negative_tags = data.valued_negative_tags.duplicate() if data != null else []
    return c
