# tutorial_events.gd
# StringName constants for semantic tutorial events.
# Gameplay systems emit these; the flow layer subscribes.
class_name TutorialEvents

const LOCATION_SELECTED: StringName = &"location_selected"
const LOT_SELECTED: StringName = &"lot_selected"
const INSPECTION_PERFORMED: StringName = &"inspection_performed"
const AUCTION_WON: StringName = &"auction_won"
const CARGO_LOADED: StringName = &"cargo_loaded"
const RUN_REVIEWED: StringName = &"run_reviewed"
const SALE_COMPLETED: StringName = &"sale_completed"
const ACTIVITY_CHOSEN: StringName = &"activity_chosen"
const CHOOSER_OPENED: StringName = &"chooser_opened"
const AUCTION_RESOLVED: StringName = &"auction_resolved"
