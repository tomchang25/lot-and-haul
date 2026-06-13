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
        var surface_clues := _sample_clues(ClueData.ClueType.SURFACE, 2, rng)
        var hidden_clues := _sample_clues(ClueData.ClueType.HIDDEN, 1, rng)
        var entry := ItemEntry.from_generation(anchor, surface_clues, hidden_clues, anchor.category_data, rng)
        entry.unveiled = true
        entry.auto_reveal_all_surface()
        entries.append(entry)

    if not entries.is_empty():
        entries[0].condition = 0.5

    MetaManager.register_storage_items(entries)
    MetaManager.begin_storage_slot()


## Returns up to [param max_count] clues of the given [param clue_type].
static func _sample_clues(clue_type: ClueData.ClueType, max_count: int, rng: RandomNumberGenerator) -> Array[ClueData]:
    var pool: Array[ClueData] = []
    for clue: ClueData in ClueRegistry.get_all_clues():
        if clue.type == clue_type:
            pool.append(clue)
    RandomUtils.shuffle(pool, rng)
    var n := mini(max_count, pool.size())
    var result: Array[ClueData] = []
    for j in n:
        result.append(pool[j])
    return result
