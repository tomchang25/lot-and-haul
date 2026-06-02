# Autoloads

Autoloads, save system, registries, hub navigation, and data pipeline shared across all blocks.

---

## Autoloads

Listed in `project.godot` load order. `RegistryCoordinator` orchestrates boot: each registry calls `RegistryCoordinator.register(self)` in `_ready()`, then `GameManager._ready()` runs `run_migrations()` and `run_validation()` after `SaveManager.load()`.

| Autoload                | File                                                    | Role                                                                                                                                     |
| ----------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `EventBus`              | `global/autoload/event_bus.gd`                          | Cross-scene signal bus (placeholder — currently empty).                                                                                  |
| `AudioManager`          | `global/autoload/audio_manager/`                        | Event-driven audio bus wrappers and event types.                                                                                         |
| `RegistryCoordinator`   | `global/autoload/registry_coordinator.gd`               | Drives `migrate()` / `validate()` across every registry that opts in via `register(self)`.                                               |
| `ClueRegistry`          | `global/autoload/registries/clue_registry.gd`           | Loads all `ClueData` `.tres` from `data/tres/clues/`. Source of the demand-tag vocabulary for the customer sell system.                  |
| `ItemRegistry`          | `global/autoload/registries/item_registry.gd`           | Loads all `ItemData` `.tres`. `get_item_by_id`, `get_items(rarity, category_id)`, `get_all_items`, `size`, `validate`.                   |
| `RunManager`            | `global/autoload/run_manager.gd`                        | Holds `run_record: RunRecord`. Null between runs.                                                                                        |
| `CarRegistry`           | `global/autoload/registries/car_registry.gd`            | Loads all `CarData` `.tres`. Owns the starter-van migration.                                                                             |
| `LocationRegistry`      | `global/autoload/registries/location_registry.gd`       | Loads all `LocationData` `.tres`.                                                                                                        |
| `CategoryRegistry`      | `global/autoload/registries/category_registry.gd`       | Loads all `CategoryData` `.tres`; owns `get_super_category_for`.                                                                         |
| `SuperCategoryRegistry` | `global/autoload/registries/super_category_registry.gd` | Loads all `SuperCategoryData` `.tres`; builds the `super_category → Array[CategoryData]` index. Asserts `CategoryRegistry` loaded first. |
| `KnowledgeManager`      | `global/autoload/knowledge_manager.gd`                  | Owns `category_points`, `attribute_levels`, and `unlocked_perks`; provides the `knowledge` save section. Category mastery, attribute upgrades, and perk management. |
| `SaveManager`           | `global/autoload/save_manager.gd`                       | Thin persistence coordinator: file IO, schema handling, schema-1→2 knowledge migration, legacy flat-save dispatch, and calls to registered section providers. Holds no gameplay state.                     |
| `MetaManager`           | `global/autoload/meta_manager.gd`                       | Hub-phase transactional authority. Owns all meta-progression runtime state (cash, garage, storage, slot, progress, customers) and registers six save section providers with SaveManager.                  |
| `GameManager`           | `global/autoload/game_manager/`                         | Scene transitions only. `go_to_*()` methods; runs `RegistryCoordinator` migrations/validation at boot.                                   |

### Constants (accessed by `class_name`, not autoloads)

| Class       | File                             | Role                                                                                                                        |
| ----------- | -------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `Economy`   | `global/constants/economy.gd`    | `DAILY_BASE_COST`, `LOCATION_SAMPLE_SIZE`, storage AP costs, auction AP cap + reserve, and `RESEARCH_DAYS` (legacy rarity→days table, kept only for save migration). |
| `DataPaths` | `global/constants/data_paths.gd` | `res://data/tres/` directory strings: items, clues, categories, super_categories, perks, attributes, locations, lots, cars. |

---

## RegistryCoordinator

Thin coordinator owning cross-cutting lifecycle hooks. Each registry calls `register(self)` at the end of `_ready()`; `GameManager._ready()` then drives two optional phases over every registered registry: a `migrate()` pass (idempotent repair of save-state vs. data drift) and a `validate()` pass (boot-time audit that every save-persisted id still resolves, erroring per problem and failing boot validation on any miss). Both are opt-in — a registry that implements neither is skipped. Signatures in `registry_coordinator.gd`.

---

## ResourceDirLoader (`global/autoload/resource_dir_loader.gd`)

Static helper that loads every `.tres` in a directory into an `{ id → Resource }` dictionary, keyed by a caller-supplied id getter. Every registry's load step goes through it.

---

## SaveManager

Thin persistence coordinator. Persists to `user://save.json`. Holds no gameplay state — state lives on the systems that own and mutate it. Responsibilities: file read/write, schema version detection, schema-1→2 knowledge key relocation, legacy flat-save dispatch (pre-sections format), and iterating registered section providers. Systems register as section providers via `register_section(provider)` in their own `_ready()`; `GameManager._ready()` calls `SaveManager.load()` after all autoloads are ready. The slot/AP model is described in `day_slot_economy.md`.

Save-file schema:
- Schema 1 — sectioned format; `category_points`, `attribute_levels`, `unlocked_perks` nested inside the `economy` section.
- Schema 2 — `economy` holds cash only; `knowledge` is a standalone section owned by `KnowledgeManager`.

### Migrations on load

- Schema 1 → 2: coordinator relocates knowledge keys from `economy` into `knowledge` before dispatch; no data loss.
- `skill_levels` (old) → `KnowledgeManager.from_dict` discards and starts fresh.
- `super_cat_means` / `category_factors_today` (removed MarketManager) → silently ignored.
- `research_slots` (old day-ticker) → `MetaManager._StorageSection` converts `research_days_spent` into per-clue `ItemEntry.research_progress` so partial work isn't lost.
- Legacy merchant keys (`merchant_negotiations_used_today`, `merchant_orders`, `next_order_id`) → silently ignored.

---

## MetaManager

Hub-phase transactional authority. Owns six domain objects (`EconomyOwner`, `GarageOwner`, `StorageOwner`, `SlotOwner`, `ProgressOwner`, `CustomersOwner`) held in `global/autoload/meta_manager/`. Each owner owns its domain's live fields, its save payload (registered directly with `SaveManager` in `_ready()`), and the no-save mutator methods that protect its invariants. `MetaManager` itself is a thin coordinator: it exposes getter-only proxy properties for scenes, holds cross-domain transactions that call owner methods and commit exactly one `SaveManager.save()` at the transaction's tail, and contains no raw field arithmetic.

Domain owners and their invariants:

| Owner | Fields | Key invariants |
|---|---|---|
| `EconomyOwner` | `cash` | `spend()` refuses to go negative; `apply_delta()` for allowed-negative ops (daily cost, run losses) |
| `GarageOwner` | `active_car`, `owned_cars` | `add_car()` is idempotent; `set_active()` owns the swap |
| `StorageOwner` | `storage_items`, `next_entry_id` | `register_entry()` assigns monotonic id + auto-verifies; `remove_entries()` returns removed ids |
| `SlotOwner` | `current_slot`, `storage_ap`, `selling_slots_today`, `pending_run` | `charge_ap()` called only after effect lands; `stash_pending_run()` builds the economics dict |
| `ProgressOwner` | `current_day`, `available_locations` | `advance_day()` increments; `set_locations()` / `clear_locations()` own the sample |
| `CustomersOwner` | `nightly_customers`, `customer_sales_today` | `record_sale()` appends ledger; `clear_sales()` resets it |

Proxy properties for reference-type collections (`storage_items`, `owned_cars`, `nightly_customers`, `customer_sales_today`, `available_locations`) return shallow duplicates so callers cannot mutate live storage through the returned array. Value-type properties (`cash`, `current_slot`, etc.) return the scalar directly. No proxy has a setter — `MetaManager.<field> = x` is a compile error by design.

Cross-domain transactions in `MetaManager`: `resolve_run`, `resolve_customer_sale`, `end_day`, `buy_car`, `set_active_car`, `register_storage_items`, `begin_storage_slot`, `begin_auction`, `begin_open_shop`. Each saves exactly once at its commit point; no helper method inside a transaction calls `SaveManager.save()`. `spend_cash(amount)` is a no-save sub-operation for `KnowledgeManager.upgrade_attribute` (a cross-autoload transaction that manages its own save). Slot/AP rules in `day_slot_economy.md`.

### Storage AP actions

Each storage action follows guard → apply → charge, charging AP only after the effect lands. The condition math lives in the static `ResearchSlot` helpers; Research advances deterministic per-clue progress on `ItemEntry`. Costs, the AP pool, and guards are in `day_slot_economy.md`.

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

---

## Data Pipeline

YAML source → `dev/tools/yaml_to_tres.py` → `.tres`. Reverse: `tres_to_yaml.py`. Validate: `validate_yaml.py` (standalone and invoked from the converter). `yaml_stats.py` prints per-category stats. Deterministic UIDs via SHA-256; script UIDs read from `.gd.uid` sidecars. No database layer.
