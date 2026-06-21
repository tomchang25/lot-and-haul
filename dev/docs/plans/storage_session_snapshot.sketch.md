# Storage Session Snapshot

## Goal

Add Run-style save and resume to the hub Storage activity so quitting during a Storage session restores the player to Storage with the same activity state, selected item, and durable AP/action progress. Storage already persists owned items as part of the normal meta save, but it does not currently persist an active Storage session as an atomic resumable flow.

## Requirements

1. Quitting during an active Storage session and relaunching must route the player back into Storage instead of silently landing in the hub, because the player spent a day or night activity slot to enter that flow.
2. The active Storage session must restore atomically: if the session payload cannot be restored coherently, the player must land in a safe hub state with a visible warning rather than a half-open Storage flow.
3. Storage item changes, AP spending, selected item identity, and the session's resume scene must be saved together at checkpoint boundaries, because the activity slot and its in-session work should not diverge.
4. The Back button must intentionally close the Storage session, clear its resume pointer, flush the final Storage state, and route to the hub, because a normal exit is different from an interrupted session.
5. Storage session restore must not duplicate item objects. The selected item and action targets must resolve to the same owned item instances that the persistent storage list owns.
6. Resume starts from a stable scene state, not a mid-click state. No pressed button animation, tutorial popup timing, held drag state, transient hover, or modal confirmation is restored.
7. The checkpoint cadence should follow the Run-style contract: save on session start, save after each committed Storage AP action, save on session close, and rely on the existing quit-time flush for graceful application close.
8. Pre-feature saves with no active Storage session must load exactly as before and route to the hub unless another existing resume pointer takes priority.

## Design

Storage resume is modeled as an active-session snapshot, not as a replacement for the normal owned-item store. The normal meta save continues to own the player's durable Storage inventory and AP totals. The new session snapshot owns the resumable flow metadata: whether Storage is active, where to route on boot, which item was selected, and any future Storage-scene child state that must be restored together.

The active Storage snapshot follows the same aggregate idea as the Run snapshot: one owner writes one optional section, the section contains metadata plus participating store/session payloads, and restore either succeeds as a coherent session or clears the active session and warns. Unlike Run, Storage does not need to duplicate the entire owned inventory in the snapshot because owned items already persist in the Storage store. The snapshot references owned items by stable entry id, then resolves those ids against the restored storage list.

The selected item is session state. It should be restored when possible so the player lands on the same object they were working on. If the selected item no longer exists because the save is inconsistent or a later migration dropped that item, the session remains resumable only if a safe fallback exists. The preferred fallback is selecting the first available storage item and warning that the previous selection was lost; if the session requires an item-specific pending action in the future, that richer payload should be treated as atomic and discarded instead.

Boot routing should observe one scene-resume priority order. Active run remains highest priority because it is an economic transaction outside the hub. Customer sell remains next because it is an in-flight night session. Storage session then routes to Storage. If no resumable flow is active, boot lands in the hub.

## Sketch (non-normative)

Names and shapes below are implementation hints only. The codebase wins every disagreement.

### Save section shape

Proposed optional section:

```gdscript
{
    "storage_session_snapshot": {
        "_version": 1,
        "active": true,
        "resume_target": "storage",
        "selected_entry_id": 42,
        "stores": {
            "session": {
                "selected_entry_id": 42,
                "browser_mode": "table",
                "sort_key": "name",
                "scroll_ratio": 0.37,
            },
        },
    },
}
```

The minimal implementation can keep only `active`, `resume_target`, and `selected_entry_id`. `browser_mode`, `sort_key`, and `scroll_ratio` are examples of future UI state; omit them unless the current item browser has a stable public API for them.

### New store or session object

Proposed runtime owner:

```gdscript
# common/gameplay/store/storage_session_store.gd
class_name StorageSessionStore
extends StoreBase

const SCENE_STORAGE := "storage"

var _active: bool = false
var _resume_target: String = ""
var _selected_entry_id: int = -1

var active: bool:
    get: return _active

var resume_target: String:
    get: return _resume_target

var selected_entry_id: int:
    get: return _selected_entry_id

func begin(selected_entry_id: int = -1) -> void:
    _active = true
    _resume_target = SCENE_STORAGE
    _selected_entry_id = selected_entry_id

func set_selected_entry(entry: ItemEntry) -> void:
    _selected_entry_id = entry.id if entry != null else -1

func clear() -> void:
    _active = false
    _resume_target = ""
    _selected_entry_id = -1
```

This can be either a normal save Store under the meta aggregate or a small session object encoded by `MetaManager`. The Run-style direction is stronger if `MetaManager` owns one optional aggregate section and the session Store exposes `encode_snapshot` / `restore_snapshot` rather than provider-facing `to_dict` / `from_dict` directly.

### Aggregate provider shape

If implemented as a Run-style aggregate, `MetaManager` can write the optional snapshot section only when Storage is active:

```gdscript
func to_dict() -> Dictionary:
    var sections := _meta_sections_to_dict()
    if storage_session.active:
        sections["storage_session_snapshot"] = _encode_storage_session_snapshot()
    return sections

func _encode_storage_session_snapshot() -> Dictionary:
    return {
        "_version": STORAGE_SESSION_SNAPSHOT_VERSION,
        "active": true,
        "resume_target": storage_session.resume_target,
        "selected_entry_id": storage_session.selected_entry_id,
        "stores": {
            "session": storage_session.encode_snapshot(),
        },
    }
```

Restore resolves session references after normal StorageStore restore has already materialized the owned item list:

```gdscript
func _restore_storage_session_snapshot(sections: Dictionary, save_ctx: SaveLoadContext) -> void:
    var snapshot: Dictionary = sections.get("storage_session_snapshot", { })
    if snapshot.is_empty():
        storage_session.clear()
        return

    var migrated := _migrate_storage_session_snapshot(snapshot, save_ctx)
    if str(migrated.get("resume_target", "")) != StorageSessionStore.SCENE_STORAGE:
        _discard_storage_session(save_ctx, "unknown resume target")
        return

    var selected_id := int(migrated.get("selected_entry_id", -1))
    if selected_id >= 0 and _find_storage_entry(selected_id) == null:
        save_ctx.warn("Storage session: selected item was not restored; selecting the first available item")
        selected_id = _first_storage_entry_id_or_default()

    if not storage_session.restore_snapshot(migrated.get("stores", { }).get("session", { }), selected_id, save_ctx):
        _discard_storage_session(save_ctx, "session payload could not be restored")
```

### Storage session lifecycle

Proposed transaction boundaries:

```gdscript
func begin_storage_slot() -> void:
    _validate_day_or_night_slot()
    _advance_slot()
    slot.set_storage_ap(_storage_ap_for_current_slot())
    storage_session.begin(_first_storage_entry_id_or_default())
    SaveManager.save()

func update_storage_selection(entry: ItemEntry) -> void:
    if not storage_session.active:
        return
    storage_session.set_selected_entry(entry)
    SaveManager.mark_dirty()

func research_item(entry: ItemEntry) -> bool:
    if not _can_research(entry):
        return false
    _apply_research(entry)
    slot.charge_ap(RESEARCH_AP_COST)
    storage_session.set_selected_entry(entry)
    SaveManager.save()
    return true

func close_storage_session() -> void:
    storage_session.clear()
    SaveManager.save()
```

Repair and Restore follow the same pattern as Research: guard, mutate, charge AP, keep the selected entry id aligned, then save synchronously. This is more aggressive than the existing 5-second dirty throttle, but it matches the user's request for full Run-style durability and keeps AP spending from diverging from item state.

### Scene integration

The Storage scene should restore its selected item from the session once the browser is populated:

```gdscript
func _ready() -> void:
    _populate_browser()
    var selected := _find_entry_by_id(MetaManager.storage_session.selected_entry_id)
    if selected == null:
        selected = _first_entry_or_null()
    _item_browser.set_selected(selected)
    _refresh_detail()
```

Selection changes should update the session, but not synchronously save every hover or incidental UI event:

```gdscript
func _on_entry_pressed(entry: ItemEntry) -> void:
    MetaManager.update_storage_selection(entry)
    _refresh_detail()
```

Back closes the session intentionally:

```gdscript
func _on_back_pressed() -> void:
    MetaManager.close_storage_session()
    SceneRouter.go_to_hub()
```

### Boot routing

Boot or Load Game routing should treat active Storage as a resumable target after higher-priority flows:

```gdscript
func route_after_load() -> void:
    if RunManager.has_active_run():
        SceneRouter.go_to_run_resume_target()
    elif MetaManager.shop_session.pending_scene == "customer_sell":
        SceneRouter.go_to_customer_sell()
    elif MetaManager.storage_session.resume_target == "storage":
        SceneRouter.go_to_storage()
    else:
        SceneRouter.go_to_hub()
```

If routing continues to live in the start page, keep this as a small helper so New Game and Load Game do not grow separate resume priority rules.

### Migration and discard policy

Suggested version policy:

1. Version 1 introduces the optional session section.
2. Missing section means inactive session with no warning.
3. Unknown resume target discards only the session snapshot and warns.
4. Missing selected item falls back to the first storage item and warns, unless future session payload includes item-specific pending work that cannot be safely retargeted.
5. Invalid required payload clears the session snapshot, leaves normal Storage inventory intact, warns, and routes to hub.

### Test seams

Suggested tests:

1. Round-trip active Storage session with selected item id.
2. Load save with no Storage session section and verify no resume target.
3. Load active Storage session whose selected item id is missing and verify safe fallback plus warning.
4. Begin Storage session, perform Research, save, reload, and verify AP plus research progress plus selected item restore.
5. Close Storage through Back, reload, and verify boot routes to hub rather than Storage.
6. Corrupt the session snapshot only, reload, and verify inventory remains intact while the active session is discarded.

## Non-Goals

1. Do not replace normal StorageStore inventory persistence. The session snapshot is a resumable-flow layer over the existing owned-item state.
2. Do not persist transient UI interaction state such as hover, button animations, tooltip timing, tutorial popup timing, or mouse-held objects.
3. Do not add manual save slots, quick-save UI, or a new save rotation policy.
4. Do not make SaveManager understand Storage internals. The owning gameplay layer remains responsible for aggregate snapshot shape and restore policy.
5. Do not attempt to resume into a partially applied Storage action. Each Repair, Restore, or Research action is either committed and saved or absent after reload.

## Acceptance Criteria

1. Start a Storage activity, quit gracefully from the Storage scene, relaunch, and load the save: the player lands directly in Storage with the same remaining AP and selected item.
2. Start a Storage activity, perform Research on an item, quit immediately after the action save completes, relaunch, and load the save: the player lands in Storage, the same item is selected, the AP is reduced, and the research progress or reveal result is present.
3. Start a Storage activity, perform Repair or Restore, relaunch, and load the save: the same item condition state and AP cost are restored together.
4. Start a Storage activity and click Back: the player lands in the hub, the Storage resume pointer is cleared, and a later load does not reopen Storage.
5. Load an old save that has no active Storage session: the player lands wherever the existing resume rules would have landed before this feature, with no Storage warning.
6. Load a save with a corrupt Storage session snapshot but intact owned Storage inventory: the player lands in the hub, sees a warning, and the owned items remain available.
7. Load a save whose active Storage session selected item no longer exists after migration: the player still resumes Storage if other items exist, sees a warning, and selection falls back to a safe item.
8. New Game never routes into Storage unless the player explicitly starts a Storage activity.
