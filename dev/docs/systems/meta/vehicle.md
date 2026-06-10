# Vehicle System

Meta block in `game/meta/vehicle/` — multiple car configs with different stamina caps, cargo grid sizes, fuel efficiency, and extra slot counts; player buys and selects cars at the Hub.

## Goal

Make the vehicle a meaningful cross-run investment: which car you drive should change how you run a warehouse, not just its stat sheet. The progression arc from starter van to specialised rigs should change packing strategy, action budget, and travel economics in felt ways.

## Cross-Run Flow

Vehicle selection and purchase happen in the Hub's Vehicle Hub (Garage + Car Shop). The active car drives: cargo grid dimensions, weight cap, stamina cap, fuel cost per day, and extra (trailer) slot count. All vehicle mutation — purchase and active-car swap — goes through `MetaManager` (`buy_car`, `set_active_car`), never `SaveManager` directly. On select: returns to Hub. On purchase: stays in shop, refreshes state.

`CarData` is authored in `data/tres/cars/`; `CarRegistry` owns lookup. The save layer serializes only car ids, rehydrating via `CarRegistry` on load. Scene and component detail lives in `vehicle_hub.gd`, `car_select_scene.gd`, `car_shop_scene.gd`, and their component `.gd` files.

## Notes

The collectible **vehicle restoration** subsystem (auction parts → assemble → sell at car shop, with select models becoming drivable) is a separate future plan, documented in `../../plans/vehicle_restoration.md`. It is distinct from the work-vehicle loop covered here.
