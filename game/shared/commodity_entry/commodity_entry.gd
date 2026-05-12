# commodity_entry.gd
# Runtime wrapper for one CommodityData instance in a generated lot.
class_name CommodityEntry
extends LotObjectEntry

var commodity_data: CommodityData = null
var condition: float = 1.0
var inspected: bool = false
var sold: bool = false

var display_name: String:
    get:
        return commodity_data.display_name if commodity_data else "Unknown Commodity"


func compute_sale_price() -> int:
    if commodity_data == null:
        return 0
    return maxi(0, roundi(commodity_data.base_value * condition))


func mark_sold() -> int:
    if sold:
        return 0
    sold = true
    return compute_sale_price()


func reveal() -> void:
    inspected = true

# ── LotObjectEntry display API ───────────────────────────────────────────────


func is_known() -> bool:
    return inspected


func display_name_text() -> String:
    return display_name if inspected else "Unknown Item"


func condition_text() -> String:
    return "%d%%" % roundi(condition * 100.0) if inspected else LotObjectEntry.UNKNOWN_TEXT


func condition_detail_text() -> String:
    return "Condition:  %d%%" % roundi(condition * 100.0) if inspected else ""


func estimated_value_text(_ctx: ItemViewContext) -> String:
    return "$%d" % compute_sale_price() if inspected else LotObjectEntry.UNKNOWN_TEXT


func base_value_text() -> String:
    if not inspected:
        return LotObjectEntry.UNKNOWN_TEXT
    return "$%d" % commodity_data.base_value if commodity_data != null else "$0"


func merchant_offer_text(_merchant: MerchantData) -> String:
    return "-"


func special_order_text(_order: SpecialOrder) -> String:
    return "-"


func rarity_text() -> String:
    return "Commodity" if inspected else LotObjectEntry.UNKNOWN_TEXT


func weight_text() -> String:
    var category := category_data()
    if not inspected or category == null:
        return LotObjectEntry.UNKNOWN_TEXT
    return "%.1f kg" % category.weight


func grid_text() -> String:
    var category := category_data()
    if not inspected or category == null:
        return LotObjectEntry.UNKNOWN_TEXT
    return "%d  %s" % [category.get_cells().size(), category.shape_id]


func market_factor_text() -> String:
    return "-" if inspected else LotObjectEntry.UNKNOWN_TEXT


func research_status_text() -> String:
    return ""


func inspection_text() -> String:
    return "Done" if inspected else LotObjectEntry.UNKNOWN_TEXT


func unlock_text() -> String:
    return "-"


func price_display_color() -> Color:
    return Color(0.4, 1.0, 0.5) if inspected else Color(0.6, 0.6, 0.6)


func condition_display_color() -> Color:
    return Color(0.5, 0.5, 0.5)


func category_data() -> CategoryData:
    return commodity_data.category_data if commodity_data != null else null


func can_inspect() -> bool:
    return not inspected


func can_appraise() -> bool:
    return false


func perform_inspect() -> StringName:
    reveal()
    return &"commodity"


func sort_value(column: int, _ctx: ItemViewContext) -> Variant:
    match column:
        LotObjectEntry.COLUMN_NAME:
            return display_name if inspected else "Unknown Item"
        LotObjectEntry.COLUMN_CONDITION:
            return condition if inspected else 0.0
        LotObjectEntry.COLUMN_ESTIMATED_VALUE, LotObjectEntry.COLUMN_BASE_VALUE:
            return compute_sale_price() if inspected else 0
        LotObjectEntry.COLUMN_RARITY:
            return -1 if inspected else -2
        LotObjectEntry.COLUMN_WEIGHT:
            var weight_category := category_data()
            if not inspected or weight_category == null:
                return 0.0
            return weight_category.weight
        LotObjectEntry.COLUMN_GRID:
            var grid_category := category_data()
            if not inspected or grid_category == null:
                return 0
            return grid_category.get_cells().size()
        LotObjectEntry.COLUMN_INSPECTION:
            return 1.0 if inspected else 0.0
        _:
            return 0


static func create(data: CommodityData) -> CommodityEntry:
    var entry := CommodityEntry.new()
    entry.commodity_data = data
    entry.condition = randf()
    return entry
