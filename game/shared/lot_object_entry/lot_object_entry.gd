# lot_object_entry.gd
# Shared runtime display surface for objects that can appear inside a lot.
class_name LotObjectEntry
extends RefCounted

const UNKNOWN_TEXT := "???"

const COLUMN_NAME := 0
const COLUMN_CONDITION := 1
const COLUMN_ESTIMATED_VALUE := 2
const COLUMN_BASE_VALUE := 3
const COLUMN_MERCHANT_OFFER := 4
const COLUMN_SPECIAL_ORDER := 5
const COLUMN_RARITY := 6
const COLUMN_WEIGHT := 7
const COLUMN_GRID := 8
const COLUMN_MARKET_FACTOR := 9
const COLUMN_RESEARCH_STATUS := 10
const COLUMN_INSPECTION := 11
const COLUMN_UNLOCK := 12


func is_known() -> bool:
    return false


func display_name_text() -> String:
    return "Unknown Item"


func condition_text() -> String:
    return UNKNOWN_TEXT


func condition_detail_text() -> String:
    return ""


func condition_secondary_text() -> String:
    return ""


func estimated_value_text(_ctx: ItemViewContext) -> String:
    return UNKNOWN_TEXT


func base_value_text() -> String:
    return UNKNOWN_TEXT


func merchant_offer_text(_merchant: MerchantData) -> String:
    return "-"


func special_order_text(_order: SpecialOrder) -> String:
    return "-"


func rarity_text() -> String:
    return UNKNOWN_TEXT


func weight_text() -> String:
    return UNKNOWN_TEXT


func grid_text() -> String:
    return UNKNOWN_TEXT


func market_factor_text() -> String:
    return "-"


func research_status_text() -> String:
    return ""


func inspection_text() -> String:
    return UNKNOWN_TEXT


func unlock_text() -> String:
    return "-"


func price_display_color() -> Color:
    return Color(0.6, 0.6, 0.6)


func condition_display_color() -> Color:
    return Color.WHITE


func category_data() -> CategoryData:
    return null


func super_category_text() -> String:
    var category := category_data()
    if category == null or category.super_category == null:
        return ""
    return category.super_category.display_name


func category_text() -> String:
    var category := category_data()
    return category.display_name if category != null else ""


func can_inspect() -> bool:
    return false


func can_appraise() -> bool:
    return false


func can_advance() -> bool:
    return false


func perform_inspect() -> StringName:
    return &""


func perform_appraise() -> bool:
    return false


func sort_value(_column: int, _ctx: ItemViewContext) -> Variant:
    return 0
