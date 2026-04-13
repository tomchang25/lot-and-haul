class_name RegistryAudit
extends RefCounted

# ══ Registry Audit ═══════════════════════════════════════════════════════════
# Static-only utility that verifies registry autoloads loaded successfully,
# scene exports are wired up, and save data references entities that still
# exist. Runs once at game startup from GameManager._ready().

# Runs all checks. Emits push_error for each problem found.
# Returns true if all checks pass, false otherwise.
static func run(scene_registry: SceneRegistry) -> bool:
    var ok := true

    if not _check_registry_sizes():
        ok = false
    if not _check_scene_registry(scene_registry):
        ok = false
    if not _check_save_car_refs():
        ok = false
    if not _check_save_perks():
        ok = false

    return ok

# ══ Registry non-emptiness ═══════════════════════════════════════════════════


static func _check_registry_sizes() -> bool:
    var ok := true

    if ItemRegistry.size() == 0:
        push_error("RegistryAudit: ItemRegistry is empty")
        ok = false
    if CarRegistry.size() == 0:
        push_error("RegistryAudit: CarRegistry is empty")
        ok = false
    if LocationRegistry.size() == 0:
        push_error("RegistryAudit: LocationRegistry is empty")
        ok = false
    if KnowledgeManager.perk_count() == 0:
        push_error("RegistryAudit: KnowledgeManager perk registry is empty")
        ok = false
    if KnowledgeManager.skill_count() == 0:
        push_error("RegistryAudit: KnowledgeManager skill registry is empty")
        ok = false
    if MerchantRegistry.size() == 0:
        push_error("RegistryAudit: MerchantRegistry is empty")
        ok = false

    return ok

# ══ SceneRegistry wiring ════════════════════════════════════════════════════


static func _check_scene_registry(scene_registry: SceneRegistry) -> bool:
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

# ══ Save data car references ════════════════════════════════════════════════


static func _check_save_car_refs() -> bool:
    var ok := true

    if CarRegistry.get_car(SaveManager.active_car_id) == null:
        push_error(
            "RegistryAudit: SaveManager.active_car_id '%s' not found in CarRegistry"
            % SaveManager.active_car_id,
        )
        ok = false

    for car_id: String in SaveManager.owned_car_ids:
        if CarRegistry.get_car(car_id) == null:
            push_error(
                "RegistryAudit: SaveManager.owned_car_ids '%s' not found in CarRegistry"
                % car_id,
            )
            ok = false

    return ok

# ══ Save data perk references ═══════════════════════════════════════════════


static func _check_save_perks() -> bool:
    var ok := true

    for perk_id: String in SaveManager.unlocked_perks:
        if KnowledgeManager.get_perk(perk_id) == null:
            push_error(
                "RegistryAudit: SaveManager.unlocked_perks '%s' not found in KnowledgeManager"
                % perk_id,
            )
            ok = false

    return ok
