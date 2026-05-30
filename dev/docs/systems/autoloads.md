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
| `KnowledgeManager`      | `global/autoload/knowledge_manager.gd`                  | Category mastery (passive XP via `add_category_points`), attribute values (`get_attribute_value`), and perks. Replaces the skill pillar. |
| `SaveManager`           | `global/autoload/save_manager.gd`                       | Persistent cross-run data; serialization only. Holds no day-advance logic.                                                               |
| `MetaManager`           | `global/autoload/meta_manager.gd`                       | Hub-phase transactional authority: day advance, storage registration, research slots, customer sales, car purchases.                     |
| `GameManager`           | `global/autoload/game_manager/`                         | Scene transitions only. `go_to_*()` methods; runs `RegistryCoordinator` migrations/validation at boot.                                   |

### Constants (accessed by `class_name`, not autoloads)

| Class       | File                             | Role                                                                                                                        |
| ----------- | -------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `Economy`   | `global/constants/economy.gd`    | `DAILY_BASE_COST`, `LOCATION_SAMPLE_SIZE`, `RESEARCH_DAYS` (rarity → days to verify), and other economy constants.          |
| `DataPaths` | `global/constants/data_paths.gd` | `res://data/tres/` directory strings: items, clues, categories, super_categories, perks, attributes, locations, lots, cars. |

---

## RegistryCoordinator

Thin coordinator owning cross-cutting lifecycle hooks. Each registry calls `register(self)` at the end of `_ready()`; `GameManager._ready()` then drives two optional phases over every registered registry: a `migrate()` pass (idempotent repair of save-state vs. data drift) and a `validate()` pass (boot-time audit that every save-persisted id still resolves, erroring per problem and failing boot validation on any miss). Both are opt-in — a registry that implements neither is skipped. Signatures in `registry_coordinator.gd`.

---

## ResourceDirLoader (`global/autoload/resource_dir_loader.gd`)

Static helper that loads every `.tres` in a directory into an `{ id → Resource }` dictionary, keyed by a caller-supplied id getter. Every registry's load step goes through it.

---

## SaveManager

Persists to `user://save.json`. **Serialization only** — it holds no day-advance or transaction logic (that's `MetaManager`). It persists the cross-run state: progression (category points, attribute levels, unlocked perks), economy (cash, owned/active car), storage items, research slots, available locations, the current day and monotonic entry id, and the current night's customers + sale ledger. Field list in `save_manager.gd`.

### Migrations on load

- `skill_levels` (old) → discarded; `attribute_levels` starts fresh.
- `super_cat_means` / `category_factors_today` (removed MarketManager) → silently ignored.
- Orphaned `unlock` research slots (identity-layer era) → cleared.
- `ResearchSlot.purge_orphaned` drops slots whose item is gone.
- Legacy merchant save keys (`merchant_negotiations_used_today`, `merchant_orders`, `next_order_id`) → silently ignored on load.

Storage registration, location rolling, day advance, research-slot assignment, and all trade operations live on `MetaManager` (below); `SaveManager` itself only exposes save and load.

---

## MetaManager

Hub-phase transactional authority. Mutates `SaveManager` state and saves; delegates computation to value objects / pure helpers. It owns: storage registration (assigning ids; auto-verify items reveal hidden clues on entry), rolling available locations, the day advance (deduct living cost → tick research slots → clear locations → generate nightly customers → save, returning a `DaySummary`), committing customer sales, research-slot assign/remove, car purchase + active swap, and run settlement (cash, surface auto-reveal, cargo storage, travel days). Signatures in `meta_manager.gd`.

### Research slot ticking

The day-tick dispatches per slot on the research action:

| Action   | Per day-tick                        | Completes when                                                          |
| -------- | ----------------------------------- | ----------------------------------------------------------------------- |
| Repair   | raises condition toward the 0.5 cap | condition reaches 0.5                                                   |
| Restore  | raises condition toward 1.0         | condition reaches 1.0                                                   |
| Research | accrues one research day            | rarity-based day threshold → reveals all hidden clues, slot auto-clears |

Completions are reported back in the day summary. Tuning constants and the exact formulas live in `research_slot.gd`.

---

## Hub Navigation

```
Hub
 ├── Location Select → run loop (location_entry → lot_browse → … → run_review)
 ├── Storage (manage items, assign research slots: Repair / Restore / Research)
 ├── Sell (nightly customer-sell scene)
 ├── Vehicle Hub (Garage car select + Car Shop)
 ├── Knowledge Hub (Mastery, Attributes, Perks)
 └── Day Pass → DaySummaryScene
```

---

## Data Pipeline

YAML source → `dev/tools/yaml_to_tres.py` → `.tres`. Reverse: `tres_to_yaml.py`. Validate: `validate_yaml.py` (standalone and invoked from the converter). `yaml_stats.py` prints per-category stats. Deterministic UIDs via SHA-256; script UIDs read from `.gd.uid` sidecars. No database layer.
