# customers_owner.gd
# Customers domain owner: nightly customers and the day's sale ledger. Owns the
# fields, their save payload, and the operations that mutate them. Held by
# MetaManager; not a global singleton.
class_name CustomersOwner
extends RefCounted

## Customers generated for the current night.
var nightly_customers: Array[Customer] = []

## Customer sales resolved during the current night, in order. Each entry is a
## plain Dictionary (day, customer_id/name, strategy, item_count, item_ids,
## sale_price). Reset when Open Shop begins.
var customer_sales_today: Array[Dictionary] = []


## Replaces the nightly customer list. Does not save.
func set_customers(customers: Array[Customer]) -> void:
    nightly_customers = customers


## Removes [param customer] from the nightly set. No-op if not present.
## Does not save.
func remove_customer(customer: Customer) -> void:
    nightly_customers.erase(customer)


## Appends a sale record to the daily ledger. Does not save.
func record_sale(
        day: int,
        customer: Customer,
        strategy: String,
        sold_ids: Array,
        sale_price: int,
) -> void:
    customer_sales_today.append(
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
    customer_sales_today.clear()


## Section id for the customers save payload.
func section_id() -> String:
    return "customers"


## Serializes customer state to a save payload.
func to_dict() -> Dictionary:
    var serialized_customers: Array = []
    for c: Customer in nightly_customers:
        serialized_customers.append(c.to_dict())
    return {
        "nightly_customers": serialized_customers,
        "customer_sales_today": customer_sales_today,
    }


## Restores customer state. Unrecognised keys are silently ignored.
func from_dict(data: Dictionary) -> void:
    nightly_customers = []
    if data.has("nightly_customers") and data["nightly_customers"] is Array:
        for d: Variant in data["nightly_customers"]:
            if d is Dictionary:
                nightly_customers.append(Customer.from_dict(d))
    customer_sales_today = []
    if data.has("customer_sales_today") and data["customer_sales_today"] is Array:
        for rec: Variant in data["customer_sales_today"]:
            if not rec is Dictionary:
                continue
            rec = rec.duplicate()
            if rec.has("item_ids") and rec["item_ids"] is Array:
                rec["item_ids"] = _intify_array(rec["item_ids"])
            customer_sales_today.append(rec)


static func _intify_array(arr: Array) -> Array:
    var result: Array = []
    for v: Variant in arr:
        if v is float:
            result.append(int(v))
        else:
            result.append(v)
    return result
