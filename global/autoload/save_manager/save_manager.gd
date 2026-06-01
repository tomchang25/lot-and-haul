# save_manager.gd
# Persistence layer: section-based JSON save/load.
#
# State fields remain on SaveManager (call sites use SaveManager.<field>), but
# serialization is delegated to registered save sections. Each section
# implements section_id() -> String, to_dict() -> Dictionary, and
# from_dict(Dictionary), reading/writing the relevant SaveManager fields.
#
# To add a new save section: create a section object that implements the three
# methods above and register it in _register_default_sections() (or via
# register_section() from elsewhere before load() runs).
#
# On-disk format: { "schema_version": int, "sections": { <id>: <payload> } }.
# Legacy flat saves (no "sections" key) are read by handing each section the
# whole flat dict — section payload keys do not collide across sections.
extends Node

const SAVE_PATH := "user://save.json"
const SCHEMA_VERSION := 1

# Per-category points store. Keys are category IDs (String), values are int.
var category_points: Dictionary = { }
var cash: int = 0
var active_car: CarData = null
var owned_cars: Array[CarData] = []

# Array of Dictionary on disk; deserialized to Array[ItemEntry] on load.
var storage_items: Array = []

var current_day: int = 0
var next_entry_id: int = 0 # monotonically increasing; never reset
var available_locations: Array[LocationData] = []
var unlocked_perks: Array[String] = []
var attribute_levels: Dictionary = { } # attribute_id (String) → int

# ── Slot economy state ────────────────────────────────────────────────────────

## Current slot index within the active day (1 = Morning, 2 = Afternoon,
## 3 = Evening). > 3 means the day is ending — hub auto-calls end_day on entry.
var current_slot: int = 1

## AP remaining in the current storage slot. Refreshed to Economy.STORAGE_AP_MAX
## at the start of each Storage slot; leftover is discarded when the slot ends.
var storage_ap: int = 0

## Selling slots committed to Open Shop this day. Set by begin_open_shop(),
## consumed by end_day() to populate the DaySummary customer count.
var selling_slots_today: int = 0

## Run economics awaiting fold-in by end_day(). Populated by resolve_run() after
## an auction; consumed and cleared by end_day(). Persisted so quitting during
## the evening slot doesn't drop the run breakdown from the day summary. Empty
## when no run is pending. Keys (all int): onsite_proceeds, paid_price,
## entry_fee, fuel_cost, cargo_count.
var pending_run: Dictionary = {}

# ── Nightly customers ─────────────────────────────────────────────────────────

## Customers generated for the current night. Array of Customer dicts on disk.
var nightly_customers: Array[Customer] = []

## Customer sales resolved during the current night, in order. Each entry is a
## plain Dictionary (day, customer_id/name, strategy, item_count, item_ids,
## sale_price). Reset when Open Shop begins (before customer generation).
var customer_sales_today: Array[Dictionary] = []

## Registered save sections, in registration order. Each implements
## section_id() / to_dict() / from_dict(Dictionary).
var _sections: Array = []


func _ready() -> void:
    _register_default_sections()


## Instantiates and registers the built-in save sections. Order is the order
## sections are written to / read from disk.
func _register_default_sections() -> void:
    register_section(EconomySaveSection.new())
    register_section(GarageSaveSection.new())
    register_section(StorageSaveSection.new())
    register_section(ProgressSaveSection.new())
    register_section(SlotSaveSection.new())
    register_section(CustomersSaveSection.new())


## Registers a save section. Must implement section_id() -> String,
## to_dict() -> Dictionary, and from_dict(Dictionary).
func register_section(section: Object) -> void:
    _sections.append(section)


func save() -> void:
    var sections_out: Dictionary = { }
    for section: Object in _sections:
        sections_out[section.section_id()] = section.to_dict()
    var data := {
        "schema_version": SCHEMA_VERSION,
        "sections": sections_out,
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("SaveManager: failed to open %s for writing" % SAVE_PATH)
        return
    file.store_string(JSON.stringify(data))


func load() -> void:
    _read_save_file()


func _read_save_file() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        push_error("SaveManager: failed to open %s for reading" % SAVE_PATH)
        return
    var text := file.get_as_text()
    var parsed: Variant = JSON.parse_string(text)
    if parsed == null or not parsed is Dictionary:
        push_error("SaveManager: invalid save data in %s" % SAVE_PATH)
        return

    # Modern saves nest each section's payload under "sections". Legacy flat
    # saves have no "sections" key — their top-level keys ARE the section
    # payloads, and those keys don't collide across sections, so each section
    # can read its own keys straight from the flat dict.
    var is_sectioned: bool = parsed.has("sections") and parsed["sections"] is Dictionary
    var sections_data: Dictionary = parsed["sections"] if is_sectioned else { }
    for section: Object in _sections:
        var sub: Dictionary = sections_data.get(section.section_id(), { }) if is_sectioned else parsed
        section.from_dict(sub)

    # Old saves may also contain keys from now-removed systems (MarketManager,
    # MerchantRegistry, max_research_slots, skill_levels, etc.) — sections that
    # care handle their own legacy keys; anything else is silently ignored.
