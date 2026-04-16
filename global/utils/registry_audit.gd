class_name RegistryAudit
extends RefCounted

# ══ Registry Audit ═══════════════════════════════════════════════════════════
# Static-only utility for checks that do not belong to any single registry.
# Per-registry size and save-reference checks now live in the registries
# themselves (driven by `RegistryCoordinator.run_validation()`); this file
# is only responsible for verifying scene-level wiring.

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
            push_error("RegistryAudit: SceneRegistry.%s is null" % prop["name"])
            ok = false

    return ok
