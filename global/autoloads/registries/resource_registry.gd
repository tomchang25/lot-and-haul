# resource_registry.gd
# Base class for data-driven registry autoloads: loads every .tres under a
# directory keyed by an id getter, and exposes generic lookup + lifecycle hooks.
# Subclasses override _dir_path() and _id_of() to specialise for their resource
# type; they keep their own typed wrappers (get_<singular>_by_id / get_all_<plural>)
# and may override migrate()/validate() for cross-registry checks.
class_name ResourceRegistry
extends Node

var _by_id: Dictionary = { } # id (String) -> Resource


## Override: return the res:// directory path holding this registry's .tres files.
func _dir_path() -> String:
    return ""


## Override: return the entity id for a resource instance (return "" to skip it).
func _id_of(_r: Resource) -> String:
    return ""


func _ready() -> void:
    _by_id = ResourceDirLoader.load_by_id(
        _dir_path(),
        func(r: Resource) -> String:
            return _id_of(r)
    )
    assert(size() > 0, "%s registry is empty after load" % name)


## Returns the resource with the given id, or null if not found.
func get_by_id(id: String) -> Resource:
    return _by_id.get(id, null)


## Returns all resources in this registry (untyped). Prefer the typed subclass
## wrapper (get_all_<plural>()) at call sites.
func get_all() -> Array:
    return _by_id.values()


## Returns the number of resources loaded.
func size() -> int:
    return _by_id.size()
