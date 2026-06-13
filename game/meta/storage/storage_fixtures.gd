# storage_fixtures.gd
# Per-scene fixture methods for the screenshot harness and testbed launcher.
# Each function seeds stores with deterministic state needed for visual captures
# and testbed runs of the storage scene. Kept next to the scene it fixtures.
extends RefCounted

class_name StorageFixtures

## Seeds MetaManager.storage with 3 deterministic items so the storage scene's
## detail rail, repair/restore/research buttons, and tutorial anchors all
## resolve. First item is repair-complete (condition = 0.5) so the restore
## button is visible.
static func seed_storage_state() -> void:
    var anchors := AnchorRegistry.get_all_anchors()
    if anchors.is_empty():
        ToastManager.show_error("StorageFixtures: AnchorRegistry is empty — cannot seed storage")
        return

    var rng := RandomNumberGenerator.new()
    rng.seed = 42

    var count := mini(3, anchors.size())
    var entries: Array[ItemEntry] = []

    for i in count:
        var anchor: AnchorData = anchors[i]
        var cat := anchor.category_data
        if cat == null:
            continue
        var entry := ItemGenerator.draw(cat, { }, 2, 4, rng)
        if entry == null:
            continue
        entry.unveiled = true
        entry.auto_reveal_all_surface()
        entries.append(entry)

    if not entries.is_empty():
        entries[0].condition = 0.5

    MetaManager.register_storage_items(entries)
    MetaManager.begin_storage_slot()
