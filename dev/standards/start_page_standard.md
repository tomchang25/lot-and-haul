# Start Page Standard

This document defines the Lot & Haul Start Page / Main Menu behavior.

---

# 1. Role

The Start Page is the project entry scene and lives at `game/meta/start/start_page_scene.tscn`. `project.godot` points `run/main_scene` to this scene.

The Start Page owns only title-screen flow: New Game, Load Game, Settings, Quit, save-slot selection, overwrite confirmation, and debug-only testbed entry. It must not contain hub, run, storage, vehicle, customer, or tutorial gameplay rules.

---

# 2. Required Actions

- New Game opens the slot picker in New Game mode.
- Load Game opens the slot picker in Load mode and is hidden when no slots exist.
- Settings calls `SettingsStore.toggle_overlay()`.
- Quit calls `get_tree().quit()`.
- Selecting a new-game slot calls `SaveManager.init_slot(slot)`, clears run state, and routes to hub.
- Selecting a load slot calls `SaveManager.switch_to_slot(slot)` and then `SceneRouter.go_to_loaded_save_entry()`.

---

# 3. Slot Picker

The slot picker is Start Page UI, not a global save manager UI. It reads slot summaries from `SaveManager.get_slot_summaries()` and formats player-facing summary text locally.

Overwrite confirmation is required before starting a new game in an occupied slot. Load mode must disable empty slots.

---

# 4. Debug Entry

The Testbeds button exists only when `Debug.enabled` is true. It is created/destroyed reactively from `Debug.toggled` and marked with `# node-src: debug` when added to the scene tree.

The testbed launcher is allowed to bypass `SceneRouter` because it is stage/debug infrastructure, not production navigation.

---

# 5. Extension Rule

Add Start Page features only when they belong to pre-game choice or save-slot flow. If a button changes live game state, starts a run, mutates storage, unlocks content, or advances time, that action belongs in the relevant game scene or system and should be reached through normal routing after load/new-game selection.
