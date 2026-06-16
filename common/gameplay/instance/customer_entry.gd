# customer_entry.gd
# Runtime value object representing a single nightly customer visit.
# Each customer arrives with demand tags (clue ids they want to buy) and a car
# grid (how much cargo space they have).
class_name CustomerEntry
extends RefCounted

# ── State ──────────────────────────────────────────────────────────────────────

var customer_id: String = ""
var display_name: String = ""
var grid_columns: int = 2
var grid_rows: int = 2

## Clue ids (tags) the customer is looking to buy. A clue's id IS its tag
## an item fits when its revealed clue ids intersect these.
var demand_tags: Array[String] = []

# ══ Serialisation ══════════════════════════════════════════════════════════════


func to_dict() -> Dictionary:
    return {
        "customer_id": customer_id,
        "display_name": display_name,
        "grid_columns": grid_columns,
        "grid_rows": grid_rows,
        "demand_tags": demand_tags.duplicate(),
    }


static func from_dict(d: Dictionary) -> CustomerEntry:
    var c := CustomerEntry.new()
    c.customer_id = str(d.get("customer_id", ""))
    c.display_name = str(d.get("display_name", ""))
    c.grid_columns = int(d.get("grid_columns", 2))
    c.grid_rows = int(d.get("grid_rows", 2))
    var raw: Array = d.get("demand_tags", [])
    c.demand_tags.assign(raw.duplicate())
    return c


static func create(id: String, name: String, grid_size: Vector2i, tags: Array[String]) -> CustomerEntry:
    var customer := CustomerEntry.new()
    customer.customer_id = id
    customer.display_name = name
    customer.grid_columns = grid_size.x
    customer.grid_rows = grid_size.y
    customer.demand_tags = tags.duplicate()
    return customer
