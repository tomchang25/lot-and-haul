# script_director.gd
# Orchestrates tutorial triggers and scripted-run state based on game progress.
# Connects to Director (presentation) signals to decide when tutorials and
# offers appear. Owns the injection skeleton for scripted runs (currently empty
# — filled by the Phase 1 Injection Skeleton draft).
extends Node

## True during any scripted sequence (tutorial or future scripted run).
var active: bool = false

## Current scripted-run phase, empty when inactive.
var phase: StringName = &""


func _ready() -> void:
    Director.scene_registered.connect(_on_scene_registered)
    Director.offer_accepted.connect(_on_offer_accepted)
    Director.offer_skipped.connect(_on_offer_skipped)
    Director.script_completed.connect(_on_script_completed)

# ══ Scene registration — decide what to trigger ══════════════════════════════


## Checks game-progress flags and tells Director to auto-start a tutorial,
## show an offer prompt, or activate the Help button.
func _on_scene_registered(scene_id: String) -> void:
    match scene_id:
        "hub":
            _on_hub_registered()
        "storage":
            _on_storage_registered()
        _:
            pass


func _on_hub_registered() -> void:
    if MetaManager.progress.tutorial_seen.has("hub"):
        return
    Director.start_script("hub")


func _on_storage_registered() -> void:
    if MetaManager.progress.tutorial_seen.has("storage"):
        Director.show_help_button("storage")
        return
    if MetaManager.storage.storage_items.is_empty():
        # Workshop tutorial is meaningless with nothing to work on.
        return

    Director.show_offer_prompt(
        "storage",
        "Welcome to the Workshop!\n\nWould you like a quick tour of the features?",
        "Yes, show me around!",
    )

# ══ Offer responses ══════════════════════════════════════════════════════════


func _on_offer_accepted(script_id: String) -> void:
    Director.start_script(script_id)


func _on_offer_skipped(_script_id: String) -> void:
    pass


func _on_script_completed(_script_id: String) -> void:
    pass
