# customers_save_section.gd
# Save section: nightly customer state — the customers generated for the current
# night and the customer sales resolved during it. Both reset to empty on load
# and repopulate from the save payload. Registered as the "customers" section.
class_name CustomersSaveSection
extends RefCounted


## Unique key for this section in the JSON save file.
func section_id() -> String:
    return "customers"


func to_dict() -> Dictionary:
    var serialized_customers: Array = []
    for c: Customer in SaveManager.nightly_customers:
        serialized_customers.append(c.to_dict())
    return {
        "nightly_customers": serialized_customers,
        "customer_sales_today": SaveManager.customer_sales_today,
    }


func from_dict(data: Dictionary) -> void:
    SaveManager.nightly_customers = []
    if data.has("nightly_customers") and data["nightly_customers"] is Array:
        for d: Variant in data["nightly_customers"]:
            if d is Dictionary:
                SaveManager.nightly_customers.append(Customer.from_dict(d))

    SaveManager.customer_sales_today = []
    if data.has("customer_sales_today") and data["customer_sales_today"] is Array:
        for rec: Variant in data["customer_sales_today"]:
            if rec is Dictionary:
                rec = rec.duplicate()
                if rec.has("item_ids") and rec["item_ids"] is Array:
                    rec["item_ids"] = _intify_array(rec["item_ids"])
                SaveManager.customer_sales_today.append(rec)


static func _intify_array(arr: Array) -> Array:
    var result: Array = []
    for v: Variant in arr:
        if v is float:
            result.append(int(v))
        else:
            result.append(v)
    return result
