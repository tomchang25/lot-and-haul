# registry_coordinator.gd
# Autoload that owns cross-cutting lifecycle hooks for registry autoloads.
# Each registry calls `RegistryCoordinator.register(self)` at the end of its
# own `_ready()` to opt in. The coordinator then drives the optional
# `migrate()` and `validate()` methods from a single entry point, so adding
# or removing a registry does not require changes to central audit/migration
# code.
#
# Load-order note: autoloaded before all registries in `project.godot`.
extends Node

var _registries: Array[Node] = []


func register(registry: Node) -> void:
    _registries.append(registry)


# Calls `migrate()` on every registered registry that implements it.
# Safe to call more than once — individual registries are expected to make
# their migrations idempotent.
func run_migrations() -> void:
    for registry: Node in _registries:
        if registry.has_method("migrate"):
            registry.migrate()


# Calls `validate() -> bool` on every registered registry that implements it,
# accumulates failures, and returns true only if every registry passed.
func run_validation() -> bool:
    var ok := true
    for registry: Node in _registries:
        if registry.has_method("validate"):
            if not registry.validate():
                ok = false
    return ok
