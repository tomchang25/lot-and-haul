# customer_registry.gd
# Autoload that loads all CustomerData resources at startup and provides query
# access. Access globally via CustomerRegistry.get_customer_by_id(customer_id) /
# CustomerRegistry.get_all_customers().
extends ResourceRegistry

func _dir_path() -> String:
    return DataPaths.CUSTOMERS_DIR


func _id_of(r: Resource) -> String:
    return (r as CustomerData).customer_id if r is CustomerData else ""


## Returns the CustomerData with the given customer_id, or null if not found.
func get_customer_by_id(customer_id: String) -> CustomerData:
    return get_by_id(customer_id) as CustomerData


func get_all_customers() -> Array[CustomerData]:
    var result: Array[CustomerData] = []
    for c: CustomerData in get_all():
        result.append(c)
    return result


## Returns customers whose appears_in_timeslot matches the given slot or is "any".
func get_customers_for_timeslot(timeslot: String) -> Array[CustomerData]:
    var result: Array[CustomerData] = []
    for c: CustomerData in get_all():
        if c.appears_in_timeslot == timeslot or c.appears_in_timeslot == "any":
            result.append(c)
    return result
