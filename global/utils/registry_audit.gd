class_name RegistryAudit
extends RefCounted

# ══ Registry Audit ═══════════════════════════════════════════════════════════
# Static-only utility for checks that do not belong to any single registry.
# Per-registry size and save-reference checks now live in the registries
# themselves (driven by `SaveManager.run_validation()`); this file
# is only responsible for verifying scene-level wiring and boot-time
# registry validation.

# Names of every ResourceRegistry-based autoload that must have data for
# normal gameplay. If any registers zero resources after _ready(), the boot
# should refuse to continue.
const _CORE_REGISTRY_NAMES: Array[StringName] = [
    &"ClueRegistry",
    &"AnchorRegistry",
    &"AffixRegistry",
    &"CarRegistry",
    &"LocationRegistry",
    &"CategoryRegistry",
    &"SuperCategoryRegistry",
]


## Checks every known ResourceRegistry autoload and returns a list of
## boot-blocking error messages. Returns an empty array when all registries
## have data and further validation is left to SaveManager.run_validation().
## Call after all autoloads have initialized but before save loading.
static func collect_boot_errors() -> Array[String]:
    var errors: Array[String] = []
    for name: StringName in _CORE_REGISTRY_NAMES:
        var registry := _resolve_registry(name)
        if registry == null:
            errors.append("%s autoload not found — check project.godot load order" % name)
            continue
        if registry.size() <= 0:
            errors.append("%s registry is empty — generated .tres files may be missing. Run the YAML→tres pipeline first." % name)
    return errors


## Resolves a Godot autoload by name. Returns null when the autoload does not
## exist or is not a ResourceRegistry.
static func _resolve_registry(autoload_name: StringName) -> ResourceRegistry:
    var tree := Engine.get_main_loop() as SceneTree
    if tree == null:
        return null
    var instance := tree.root.get_node_or_null(String(autoload_name))
    return instance as ResourceRegistry


# Verifies every PackedScene export on the SceneRegistry is populated.
# Emits push_error for each null slot and returns true only if all pass.
static func check_scene_registry(scene_registry: SceneRegistry) -> bool:
    var ok := true

    for prop: Dictionary in scene_registry.get_property_list():
        if prop["type"] != TYPE_OBJECT:
            continue
        if prop["hint"] != PROPERTY_HINT_RESOURCE_TYPE:
            continue
        if prop["hint_string"] != "PackedScene":
            continue
        var value: Variant = scene_registry.get(prop["name"])
        if value == null:
            ToastManager.show_dev_error("RegistryAudit: SceneRegistry.%s is null" % prop["name"])
            ok = false

    return ok
