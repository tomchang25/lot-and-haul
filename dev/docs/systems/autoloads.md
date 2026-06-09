# Autoloads

Cross-cutting boot, persistence, and hub-navigation infrastructure shared across all blocks. The autoload roster (names, file paths, per-autoload role) is readable from `project.godot` and each file's header — it is not duplicated here.

---

## Boot Orchestration

`SaveManager` owns the cross-cutting boot fan-out. Domain managers (`MetaManager`, `KnowledgeManager`) call `SaveManager.register_manager(self)` in `_ready()`; registries and stores call `SaveManager.register_section(self)`. After `SaveManager.load()` completes, `GameManager._ready()` calls:

1. **`SaveManager.run_migrations()`** — fans out `migrate()` to every registered manager; idempotent repair of save-state vs. data drift (e.g. dropped clue ids, renamed keys).
2. **`SaveManager.run_validation()`** — fans out `validate()` to every registered manager; boot-time audit that every save-persisted id still resolves. Any miss logs an error and fails boot validation.

Both phases are opt-in; a manager that implements neither is skipped. Because `load()` runs before either fan-out, migrate/validate always see the loaded save state.

---

## SaveManager

Thin persistence coordinator (`global/autoloads/save_manager.gd`). Responsibilities: file read/write, schema version detection, schema-1→2 knowledge key relocation, legacy flat-save dispatch, and iterating registered section providers. It holds **no gameplay state** — state lives on the systems that own and mutate it.

Systems register as section providers in their own `_ready()`. Two-tier save strategy:

- **Transaction Save** — `SaveManager.save()` called exactly once per irreversible cross-domain commit point (`resolve_run`, `end_day`, `resolve_customer_sale`, `begin_auction`, `begin_open_shop`, `buy_car`, `upgrade_attribute`). Writes to disk immediately and clears the dirty flag.
- **Deferred Save** — `SaveManager.mark_dirty()` called by recoverable micro-actions (`repair_item`, `restore_item`, `research_item`, `set_active_car`, `unlock_perk`, `begin_storage_slot`, `register_storage_items`). Sets a dirty flag; `_process` flushes at most once per `THROTTLE_SEC` (2 s). `SceneRouter._navigate()` flushes before every scene transition; `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` flushes on quit.

No helper method inside a transaction calls `save()` independently.

---

## MetaManager

Hub-phase transactional authority (`global/autoloads/meta_manager.gd`). Holds six domain stores (`EconomyStore`, `GarageStore`, `StorageStore`, `SlotStore`, `ProgressStore`, `CustomersStore`) as plain public fields; each store owns its domain's live fields, save payload, and the mutators that guard its invariants. Scenes read state directly via `MetaManager.<store>.<field>` — no proxy layer.

Cross-domain transactions (`resolve_run`, `resolve_customer_sale`, `end_day`, `buy_car`, `set_active_car`, `register_storage_items`, `begin_storage_slot`, `begin_auction`, `begin_open_shop`) save exactly once at their commit point. Store methods and domain invariants live in the store `.gd` files; the slot/AP rules are in `day_slot_economy.md`.

---

## Hub Navigation

```
Hub (slot tray: Morning / Afternoon / Evening)
 ├── Auction (slot 1; consumes slots 1+2) → run loop (location_entry → lot_browse → … → run_review)
 ├── Storage (spend storage AP: Repair / Restore / Research)
 ├── Open Shop (slot-scaled nightly customer-sell scene) → ends day
 ├── Vehicle Hub (Garage car select + Car Shop)
 ├── Knowledge Hub (Mastery, Attributes, Perks)
 └── Day end (Open Shop or all slots spent) → DaySummaryScene
```

Scene-transition wiring lives in `GameManager`; hub-specific slot/AP flow is in `day_slot_economy.md`.
