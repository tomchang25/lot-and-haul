# customers_store.gd
# Customers runtime store: nightly customers and the day's sale ledger.
# Serializable state slice held by MetaManager. Owns the fields, their save
# payload, and the operations that mutate them.
#
# Fields are read-public via getters. Mutation goes through the owning Manager only.
class_name CustomersStore
extends StoreBase

var _nightly_customers: Array[CustomerEntry] = []
var _customer_sales_today: Array[Dictionary] = []

## Shallow duplicate of the nightly customer list (CustomerEntry refs shared).
## Read-only externally. Returns a duplicate for iteration stability.
var nightly_customers: Array[CustomerEntry]:
    get:
        return _nightly_customers.duplicate()

## Shallow duplicate of today's sales ledger (Dictionary entries are shared).
## Read-only externally. Returns a duplicate for iteration stability.
var customer_sales_today: Array[Dictionary]:
    get:
        return _customer_sales_today.duplicate()


## Replaces the nightly customer list. Does not save.
func set_customers(customers: Array[CustomerEntry]) -> void:
    _nightly_customers = customers


## Removes [param customer] from the nightly set. No-op if not present.
## Does not save.
func remove_customer(customer: CustomerEntry) -> void:
    _nightly_customers.erase(customer)


## Appends a sale record to the daily ledger. Does not save.
func record_sale(
        day: int,
        customer: CustomerEntry,
        strategy: String,
        sold_ids: Array,
        sale_price: int,
) -> void:
    _customer_sales_today.append(
        {
            "day": day,
            "customer_id": customer.customer_id if customer != null else "",
            "customer_name": customer.display_name if customer != null else "",
            "strategy": strategy,
            "item_count": sold_ids.size(),
            "item_ids": sold_ids,
            "sale_price": sale_price,
        },
    )


## Clears the daily sales ledger. Does not save.
func clear_sales() -> void:
    _customer_sales_today.clear()


## Section id for the customers save payload.
func section_id() -> String:
    return "customers"


## Serializes customer state to a save payload.
func to_dict() -> Dictionary:
    var serialized_customers: Array = []
    for c: CustomerEntry in _nightly_customers:
        serialized_customers.append(c.to_dict())
    return {
        "_version": _store_version(),
        "nightly_customers": serialized_customers,
        "customer_sales_today": _customer_sales_today,
    }


## Restores customer state. Unrecognised keys are silently ignored.
func from_dict(data: Dictionary, _ctx: SaveLoadContext) -> void:
    var version: int = int(data.get("_version", 1))
    data = _apply_migrations(data, version, _ctx)
    _nightly_customers = []
    if data.has("nightly_customers") and data["nightly_customers"] is Array:
        for d: Variant in data["nightly_customers"]:
            if d is Dictionary:
                _nightly_customers.append(CustomerEntry.from_dict(d))
    _customer_sales_today = []
    if data.has("customer_sales_today") and data["customer_sales_today"] is Array:
        for rec: Variant in data["customer_sales_today"]:
            if not rec is Dictionary:
                continue
            rec = rec.duplicate()
            if rec.has("item_ids") and rec["item_ids"] is Array:
                rec["item_ids"] = _intify_array(rec["item_ids"])
            _customer_sales_today.append(rec)


static func _intify_array(arr: Array) -> Array:
    var result: Array = []
    for v: Variant in arr:
        if v is float:
            result.append(int(v))
        else:
            result.append(v)
    return result
