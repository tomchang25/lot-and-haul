# Autoloads

Cross-cutting boot, persistence, and hub-navigation infrastructure shared across all blocks. The autoload roster (names, file paths, per-autoload role) is readable from `project.godot` and each file's header — it is not duplicated here.

---

## Boot Orchestration

`SaveManager` owns the cross-cutting boot fan-out. All save providers — domain managers (`MetaManager`, `KnowledgeManager`) and their owned stores — call `SaveManager.register_provider(self)` in `_ready()`. After all providers register, `GameManager._ready()` calls:

1. **`SaveManager.load()`** — reads the latest counter-based save file and dispatches `from_dict()` to every registered provider; per-store versioned migrations run inside each `from_dict()` via `_apply_migrations()`, so there is no top-level migration fan-out.
2. **`SaveManager.run_validation()`** — fans out `validate()` to every registered provider; boot-time audit that every save-persisted id still resolves. Any miss logs an error and fails boot validation.

Both phases are opt-in (a provider that skips `validate()` is skipped). Because `load()` runs before validation, `validate()` always sees loaded and migrated state.

---

## SaveManager

Thin persistence coordinator (`global/autoloads/save_manager.gd`). Writes counter-based save files per player slot (`user://save_slots/slot_N/save_C.json`); a manifest tracks slot summary metadata and the active counter, and up to 10 files are retained per slot. The counter-rotation rationale lives in `dev/docs/archived/save_slots.md`. It holds **no gameplay state** — state lives on the systems that own and mutate it.

Systems register as section providers in their own `_ready()`. Two-tier save strategy:

- **Transaction Save** — `SaveManager.save()` called exactly once per irreversible cross-domain commit point (`resolve_run`, `end_day`, `resolve_customer_sale`, `begin_auction`, `begin_open_shop`, `buy_car`, `upgrade_attribute`). Writes to disk immediately and clears the dirty flag.
- **Deferred Save** — `SaveManager.mark_dirty()` called by recoverable micro-actions (`repair_item`, `restore_item`, `research_item`, `set_active_car`, `unlock_perk`, `begin_storage_slot`, `register_storage_items`). Sets a dirty flag; `_process` flushes at most once per `THROTTLE_SEC` (5 s). `SceneRouter._navigate()` flushes before every scene transition; `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` flushes on quit.

No helper method inside a transaction calls `save()` independently.

---

## MetaManager

Hub-phase transactional authority (`global/autoloads/meta_manager.gd`). Holds six domain stores (`EconomyStore`, `GarageStore`, `StorageStore`, `SlotStore`, `ProgressStore`, `CustomersStore`) as plain public fields; each store owns its domain's live fields, save payload, and the mutators that guard its invariants. Scenes read state directly via `MetaManager.<store>.<field>` — no proxy layer.

Cross-domain transactions (`resolve_run`, `resolve_customer_sale`, `end_day`, `buy_car`, `set_active_car`, `register_storage_items`, `begin_storage_slot`, `begin_auction`, `begin_open_shop`) save exactly once at their commit point. Store methods and domain invariants live in the store `.gd` files; the slot/AP rules are in `day_slot_economy.md`.

---

## Hub Navigation

```
Hub (slot tray: Day / Night)
 ├── Activity chooser (cancellable per-slot activity popup)
 │    ├── Auction (Day only) → run loop (location_entry → lot_browse → … → run_review) → Night
 │    ├── Storage (spend slot-scaled storage AP: Repair / Restore / Research)
 │    └── Open Shop (Day/Night-scaled customer-sell scene)
 ├── Vehicle Hub (Garage car select + Car Shop)
 ├── Knowledge Hub (Mastery, Attributes, Perks)
 └── Day end (after Night activity) → DaySummaryScene
```

Scene-transition wiring lives in `SceneRouter`; hub-specific slot/AP flow is in `day_slot_economy.md`.

---

## Tutorial Orchestration

Tutorial presentation and tutorial triggering are split across two autoloads: `Director` owns overlay presentation, scene anchor registration, step playback, and Help/offer UI; `ScriptDirector` listens to Director signals and decides when a tutorial should start based on game progress. The split rationale lives in `dev/docs/archived/director_split_and_testing_taxonomy.sketch.md`.
