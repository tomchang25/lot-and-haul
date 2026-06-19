# Run Snapshot Serialization Standardization

## Goal

Normalize aggregate snapshot serialization for active run state so cross-Store saves have a standard shape instead of one-off item-table methods. The immediate target is the active run snapshot, where multiple Stores share Entry identity and must restore atomically.

## Requirements

1. The owning gameplay System remains the only save provider for cross-Store runtime state, because SaveManager should not understand relationships between Stores.
2. Shared Entries are serialized once per aggregate snapshot and referenced by keys from each Store payload, because the same live Entry must not restore into duplicate objects.
3. Store snapshot methods separate local field persistence from aggregate reference wiring, because scalar Store state and cross-Store identity tables have different responsibilities.
4. Restore remains atomic for the aggregate, because a partial active run with one missing Store or missing Entry reference would be more corrupt than discarding the active run snapshot.
5. The standard should support future active-run child Stores without changing the conceptual model.

## Design

Cross-Store serialization is a System aggregate snapshot. The System owns one save section, creates a snapshot context, asks each participating Store for a payload, stores shared Entry tables once, and restores in dependency order. SaveManager continues to dispatch providers without knowing what Stores or Entries exist inside the section.

The snapshot context owns shared identity tables. Stores do not serialize full shared Entries into their own payloads; they ask the context for keys and later restore references from keys. This preserves object identity across run-level collections, active-lot collections, cargo collections, and any future run-phase child Store.

Store snapshot methods should have explicit aggregate names. Provider-facing `to_dict` and `from_dict` keep their SaveManager meaning, while session-scoped aggregate Stores use `encode_snapshot` and `restore_snapshot` so readers can tell they require a System-level context.

Local Store fields can be factored into private helpers if useful, but shared Entry table work stays in the snapshot layer. The important split is local fields versus aggregate references, not forcing every Store to expose provider-style methods.

## Sketch (non-normative)

Proposed aggregate shape:

```gdscript
{
    "run_snapshot": {
        "_version": 1,
        "resume_target": "inspection",
        "entries": {
            "items": [
                { ... },
            ],
        },
        "stores": {
            "run": {
                "location_id": "...",
                "car_id": "...",
                "won_item_keys": [0, 1],
                "cargo_item_keys": [],
                "trailer_item_keys": [],
            },
            "lot": {
                "lot_id": "...",
                "item_keys": [0, 1, 2],
                "won_item_keys": [],
            },
        },
    },
}
```

Proposed call flow:

```gdscript
func to_dict() -> Dictionary:
    if run == null:
        return { }
    var snapshot_ctx := RunSnapshotContext.new()
    var stores := {
        "run": run.encode_snapshot(snapshot_ctx),
    }
    if lot != null:
        stores["lot"] = lot.encode_snapshot(snapshot_ctx)
    return {
        SAVE_SECTION: {
            "_version": RUN_SNAPSHOT_VERSION,
            "resume_target": get_resume_target(),
            "entries": snapshot_ctx.encode_entries(),
            "stores": stores,
        },
    }
```

Proposed restore flow:

```gdscript
func from_dict(data: Dictionary, save_ctx: SaveLoadContext) -> void:
    var snapshot := data.get(SAVE_SECTION, { })
    if snapshot.is_empty():
        return
    clear_run_state()
    var snapshot_ctx := RunSnapshotContext.new()
    if not snapshot_ctx.restore_entries(snapshot.get("entries", { }), save_ctx):
        discard_active_run(save_ctx)
        return
    var stores := snapshot.get("stores", { })
    var restored_run := RunStore.new()
    if not restored_run.restore_snapshot(stores.get("run", { }), snapshot_ctx, save_ctx):
        discard_active_run(save_ctx)
        return
    run = restored_run
    if stores.has("lot"):
        var restored_lot := LotStore.new()
        if not restored_lot.restore_snapshot(stores["lot"], snapshot_ctx, save_ctx, run):
            discard_active_run(save_ctx)
            return
        lot = restored_lot
```

Proposed Store-side split:

```gdscript
func encode_snapshot(snapshot_ctx: RunSnapshotContext) -> Dictionary:
    var d := _encode_fields()
    d["won_item_keys"] = snapshot_ctx.item_keys_for(_won_items)
    d["cargo_item_keys"] = snapshot_ctx.item_keys_for(_cargo_items)
    return d

func restore_snapshot(data: Dictionary, snapshot_ctx: RunSnapshotContext, save_ctx: SaveLoadContext) -> bool:
    if not _restore_fields(data, save_ctx):
        return false
    if not snapshot_ctx.restore_item_refs_into(_won_items, data.get("won_item_keys", []), save_ctx, "won_items"):
        return false
    return true
```

Suggested naming direction:

```text
RunItemTable -> RunSnapshotContext or RunEntryTable
encode_with_item_table -> encode_snapshot
restore_with_item_table -> restore_snapshot
item_table parameter -> snapshot_ctx
```

Suggested restore policy:

1. Migrate aggregate root payload.
2. Restore shared Entry tables.
3. Restore required root Store.
4. Restore optional child Stores.
5. If any required reference is missing or invalid, clear the active aggregate and warn through the save-load context.

Suggested placement of resume metadata:

```text
resume_target belongs in aggregate metadata if it is a navigation/checkpoint hint.
domain flags that protect mutation idempotency remain in the owning Store.
```

## Non-Goals

1. Do not change save file IO, slot rotation, or SaveManager provider dispatch.
2. Do not make SaveManager aware of individual Stores inside the run snapshot.
3. Do not persist duplicate full Entry payloads inside Store payloads.
4. Do not redesign run gameplay, checkpoint timing, or migration policy beyond the aggregate snapshot shape.

## Acceptance Criteria

1. The active run save section has one aggregate owner and one shared Entry table for all participating Store payloads.
2. Store snapshot methods use standard aggregate naming and no longer expose item-table-specific method names.
3. Shared Entry references restore as shared objects across run, lot, cargo, trailer, and won-item collections.
4. Invalid aggregate snapshots are discarded as one unit with a save-load warning instead of leaving partial active run state.
5. Existing active-run save/load behavior remains functionally equivalent after the serialization cleanup.
