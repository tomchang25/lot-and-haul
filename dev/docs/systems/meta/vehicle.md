# Vehicle System

Meta block in `game/meta/` — multiple car configs with different stamina caps, cargo grid sizes, fuel efficiency, and extra slot counts; player buys and selects cars at the Hub.

## Goal

Make the vehicle a meaningful cross-run investment: which car you drive should change how you run a warehouse, not just its stat sheet. Success is a progression arc from starter van to specialised rigs where each step changes packing strategy, action budget, and travel economics in felt ways.

## Reads

- `SaveManager.active_car` — currently selected `CarData`
- `SaveManager.owned_cars` — `Array[CarData]` of owned vehicles
- `SaveManager.cash` — shop purchases
- `CarRegistry.get_all_cars()` / `get_car_by_id()` — vehicle lookup and shop inventory
- `CarData` instances under `data/tres/cars/*.tres` — all selectable and purchasable vehicles

## Writes

- `SaveManager.active_car` — set by `MetaManager.set_active_car()` (from the Garage)
- `SaveManager.owned_cars` — appended by `MetaManager.buy_car()` on purchase
- `SaveManager.cash` — debited by `MetaManager.buy_car()`

On select: returns to `hub`. On purchase: stays in shop, refreshes owned/active state.

> Mutation lives on `MetaManager`, not `SaveManager`: `MetaManager.buy_car(car)` (debit cash, append to `owned_cars`, save) and `MetaManager.set_active_car(car)`. `owned_cars` / `active_car` are `Array[CarData]` / `CarData` at runtime; only their `car_id`s are serialized (`owned_car_ids` / `active_car_id`) in the save file.

## Feature Intro

### Data Definitions

`CarData` (the cargo grid, weight cap, stamina pool, fuel cost, trailer slots + damage risk, shop price, icon) is described in `../shared/data_model.md`; field-level detail lives in `data/definitions/car_data.gd`. It's consumed by `RunRecord` (stamina, fuel, trailer slots) and the cargo scene (grid, weight, trailer slots).

The save layer holds the active car and owned cars as `CarData` refs at runtime, but serializes only their `car_id`s, rehydrating via `CarRegistry` on load. All vehicle mutation (purchase, active-car swap) goes through `MetaManager`, never `SaveManager` directly — purchase checks affordability + dedupe, debits cash, appends, and saves.

### Vehicle Hub

`game/meta/vehicle/vehicle_hub.gd` + `.tscn` — navigation menu with Garage, Car Shop, and Back buttons. Mirrors the Knowledge Hub pattern. Back returns to Hub via `GameManager.go_to_hub()`.

### Car Selection Screen (Garage)

`game/meta/vehicle/car_select/car_select_scene.gd` + `.tscn` — lists `SaveManager.owned_cars` as `CarRow` components. The active car shows a green "ACTIVE" label; others show a "Select" button, which calls `MetaManager.set_active_car(car)` and swaps the active state in place via `_refresh_active_state()` — no row rebuild, no navigation away. Back returns to Vehicle Hub.

`CarRow` (`game/meta/vehicle/car_select/car_row/car_row.gd` + `.tscn`) — `class_name CarRow`, extends `PanelContainer`. Follows the `setup()` / `_apply()` pattern with `is_node_ready()` guard. Displays icon, name, `car.stats_line()`, and toggles between `ActiveLabel` and `SelectButton` based on `is_active`. Emits `select_pressed(car)`.

### Car Shop

`game/meta/vehicle/car_shop/car_shop_scene.gd` + `.tscn` — lists all unowned cars as `CarCard` components. Inventory is "all cars in `CarRegistry.get_all_cars()` not already in `SaveManager.owned_cars`". Balance shown at top. Buy disabled when cash < price; purchase goes through `MetaManager.buy_car(car)`. On purchase: card removed, balance refreshed, remaining Buy buttons re-evaluated. Empty-state label shown when all cars owned.

`CarCard` (`game/meta/vehicle/car_shop/car_card/car_card.gd` + `.tscn`) — `class_name CarCard`, extends `PanelContainer`. Displays icon, name, `car.stats_line()`, price, and a Buy button. Emits `buy_pressed(car)`. Follows the standard `setup()` / `_apply()` / `is_node_ready()` pattern.

### Starter Car Authoring

3–5 `CarData` `.tres` files under `data/tres/cars/` spanning a clear progression — starter van → box truck → semi, or similar — varying cargo grid dimensions, `stamina_cap`, `fuel_cost_per_day`, `extra_slot_count`, and `max_weight`. The progression curve is the primary design lever; individual number tuning comes after the shop exists.

## Notes

### Location system ships first

The pre-run cost preview built during Location work will already be wired for `fuel_cost_per_day × travel_days` against the current single active car. When the vehicle shop lands, fuel variety slots into the existing cost card without rework — as long as the selection screen lands before (or alongside) the shop so the "active car" plumbing exists.

### Related

The separate collectible **vehicle restoration** subsystem (auction parts → assemble → sell at car shop, with select models becoming drivable) is a future plan, documented in `../../plans/vehicle_restoration.md` and tracked in `ROADMAP.md`. It is distinct from the work-vehicle loop covered here and is not yet scheduled.
