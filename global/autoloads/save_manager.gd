# save_manager.gd
# Persistence coordinator: file IO, schema handling, and registered section dispatch.
# Holds no gameplay state. Systems that own gameplay state register themselves as
# section providers via register_section() before GameManager calls load().
# Domain managers (MetaManager, KnowledgeManager) register via register_manager()
# so GameManager can fan out run_migrations() and run_validation() after load().
#
# On-disk format: { "schema_version": int, "sections": { <id>: <payload> } }.
# Legacy flat saves (no "sections" key) are dispatched in full to each provider —
# section payload keys do not collide across sections so each reads its own keys.
#
# Schema version history:
#   1 — original sectioned format; knowledge keys nested inside "economy" section.
#   2 — "economy" holds cash only; "knowledge" is a separate section.
extends Node

const SAVE_PATH := "user://save.json"
const SCHEMA_VERSION := 2

## Registered save section providers, in registration order. Each must implement
## to_dict() -> Dictionary and from_dict(Dictionary). to_dict() returns a flat
## multi-key dict (all section keys merged into sections_out); from_dict() receives
## the full sections dict and reads only its own keys.
var _sections: Array = []

## Domain managers that own migrate() / validate() fan-out. Registered before
## GameManager calls run_migrations() / run_validation().
var _managers: Array = []


func _ready() -> void:
    pass # Sections and managers are registered by owning systems before GameManager runs.


## Registers a save section provider. Call before load() runs (i.e. in _ready()
## of the owning autoload). The provider must implement to_dict() -> Dictionary
## and from_dict(Dictionary).
func register_section(section: Object) -> void:
    assert(section.has_method("to_dict"), "register_section: %s missing to_dict()" % section)
    assert(section.has_method("from_dict"), "register_section: %s missing from_dict()" % section)
    _sections.append(section)


## Registers several section providers in order. Convenience over register_section.
func register_sections(sections: Array) -> void:
    for s: Object in sections:
        register_section(s)


## Registers a domain manager for migration and validation fan-out. Call in
## _ready() of the owning manager. The manager must implement migrate() and
## validate() -> bool.
func register_manager(manager: Object) -> void:
    assert(manager.has_method("migrate"), "register_manager: %s missing migrate()" % manager)
    assert(manager.has_method("validate"), "register_manager: %s missing validate()" % manager)
    _managers.append(manager)


## Calls migrate() on every registered manager. Idempotent — managers are
## expected to make their migrations idempotent.
func run_migrations() -> void:
    for manager: Object in _managers:
        manager.migrate()


## Calls validate() on every registered manager, accumulates failures, and
## returns true only if every manager passed.
func run_validation() -> bool:
    var ok := true
    for manager: Object in _managers:
        if not manager.validate():
            ok = false
    return ok


func save() -> void:
    var sections_out: Dictionary = { }
    for section: Object in _sections:
        sections_out.merge(section.to_dict())
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

    # Legacy flat saves have no "sections" key — dispatch the whole dict to
    # every provider (keys don't collide across sections).
    var is_sectioned: bool = parsed.has("sections") and parsed["sections"] is Dictionary
    if not is_sectioned:
        for section: Object in _sections:
            section.from_dict(parsed)
        return

    var schema_version: int = int(parsed.get("schema_version", 1))
    var sections_data: Dictionary = parsed["sections"].duplicate(true)

    # Schema 1→2 migration: in schema 1, category_points / attribute_levels /
    # unlocked_perks are nested inside the "economy" section. Relocate them into
    # the "knowledge" section before dispatching so each provider sees only its
    # own keys. No data is lost; the economy provider sees cash only.
    if schema_version < 2:
        var econ: Dictionary = sections_data.get("economy", { })
        var knowledge: Dictionary = { }
        for key: String in ["category_points", "attribute_levels", "unlocked_perks"]:
            if econ.has(key):
                knowledge[key] = econ[key]
                econ.erase(key)
        sections_data["economy"] = econ
        sections_data["knowledge"] = knowledge

    for section: Object in _sections:
        section.from_dict(sections_data)

    # Old saves may contain keys from removed systems (MarketManager,
    # MerchantRegistry, max_research_slots, etc.) — providers that care handle
    # their own legacy keys; everything else is silently ignored.
