# location_entry_fixtures.gd
# Fixture methods for the location-entry → run-start testbed. Seeds enough
# game state that the full run flow (location_entry → lot_browse → inspection →
# auction → cargo) plays with real controls and real navigation.
extends RefCounted

class_name LocationEntryFixtures

## Seeds a location + car so LocationEntry finds an active run and proceeds
## normally. The first available location and the first registered car are used
## so the fixture is deterministic without hard-coding IDs.
static func seed_run_ready() -> void:
    var locations: Array[LocationData] = LocationRegistry.get_all_locations()
    if locations.is_empty():
        ToastManager.show_error("LocationEntryFixtures: LocationRegistry is empty")
        return

    var cars: Array[CarData] = CarRegistry.get_all_cars()
    if cars.is_empty():
        ToastManager.show_error("LocationEntryFixtures: CarRegistry is empty")
        return

    MetaSystem.roll_available_locations()
    var available: Array = MetaSystem.progress.available_locations
    var loc: LocationData = available[0] if not available.is_empty() else locations[0]
    var car: CarData = cars[0]

    MetaSystem.set_active_car(car)
    RunSystem.create_run_store(loc, car)
