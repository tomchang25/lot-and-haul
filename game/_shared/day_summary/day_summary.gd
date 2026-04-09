# day_summary.gd
# Value object returned by SaveManager.advance_days().
class_name DaySummary
extends RefCounted

var start_day: int
var end_day: int
var days_elapsed: int

# Run-specific (zero/empty for hub day-pass)
var onsite_proceeds: int = 0
var paid_price: int = 0
var entry_fee: int = 0
var fuel_cost: int = 0

# Universal
var living_cost: int = 0
var completed_actions: Array[Dictionary] = []

var net_change: int:
    get:
        return onsite_proceeds - paid_price - entry_fee - fuel_cost - living_cost


func has_run_data() -> bool:
    return onsite_proceeds != 0 or paid_price != 0 or entry_fee != 0 or fuel_cost != 0
