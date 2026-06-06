# save_manager.gd
# Persistence coordinator: file IO, schema handling, and registered provider dispatch.
# Holds no gameplay state. Systems that own gameplay state register themselves via
# register_provider() before GameManager calls load(). Each provider implements the
# full StoreBase interface: to_dict(), from_dict(), migrate(), validate().
#
# On-disk format: { "schema_version": int, "sections": { <id>: <payload> } }.
# schema_version is always SCHEMA_VERSION (2) on new saves; load() requires the
# "sections" key to be present (push_error otherwise).
extends Node

const SAVE_PATH := "user://save.json"
const SCHEMA_VERSION := 2

## Registered providers, in registration order. Each must implement to_dict(),
## from_dict(), migrate(), and validate(). to_dict() returns a flat multi-key dict
## (all section keys merged into sections_out); from_dict() receives the full
## sections dict and reads only its own keys.
var _providers: Array = []


func _ready() -> void:
    pass # Providers are registered by owning systems before GameManager runs.


## Registers a save provider. Call before load() runs (i.e. in _ready() of the
## owning autoload). The provider must implement to_dict() -> Dictionary,
## from_dict(Dictionary), migrate(), and validate() -> bool.
func register_provider(provider: Object) -> void:
    assert(provider.has_method("to_dict"), "register_provider: %s missing to_dict()" % provider)
    assert(provider.has_method("from_dict"), "register_provider: %s missing from_dict()" % provider)
    assert(provider.has_method("migrate"), "register_provider: %s missing migrate()" % provider)
    assert(provider.has_method("validate"), "register_provider: %s missing validate()" % provider)
    _providers.append(provider)


## Calls migrate() on every registered provider. Idempotent — providers are
## expected to make their migrations idempotent.
func run_migrations() -> void:
    for provider: Object in _providers:
        provider.migrate()


## Calls validate() on every registered provider, accumulates failures, and
## returns true only if every provider passed.
func run_validation() -> bool:
    var ok := true
    for provider: Object in _providers:
        if not provider.validate():
            ok = false
    return ok


func save() -> void:
    var sections_out: Dictionary = { }
    for provider: Object in _providers:
        sections_out.merge(provider.to_dict())
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

    if not (parsed.has("sections") and parsed["sections"] is Dictionary):
        push_error("SaveManager: save missing 'sections' key in %s" % SAVE_PATH)
        return

    var sections_data: Dictionary = parsed["sections"].duplicate(true)
    for provider: Object in _providers:
        provider.from_dict(sections_data)
