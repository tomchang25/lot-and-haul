# Settings Overlay Standard

This document defines Lot & Haul's project-wide settings storage and overlay UI.

---

# 1. Ownership

`SettingsStore` owns user/device preferences and persists them to `user://settings.json`. These settings are global to the local user and must not be stored in gameplay save slots.

Settings-store data includes audio volumes, fullscreen, debug preference, tutorial skip preference, and locale. Gameplay save data includes cash, day/slot state, storage, run state, cars, knowledge, unlocks, and customer/session state.

---

# 2. Overlay Lifecycle

`game/shared/settings_overlay/settings_overlay.tscn` is instantiated only by `SettingsStore.toggle_overlay()`. The overlay pauses the tree while open, runs with `PROCESS_MODE_ALWAYS`, and emits `closed` when it should be removed.

Open settings with:

```gdscript
SettingsStore.toggle_overlay()
```

Gameplay screens that need a visible settings affordance should pre-place `game/shared/settings_button_overlay/settings_button_overlay.tscn` in their `.tscn` UI shell rather than constructing a button from script.

---

# 3. Setting Changes

Settings save immediately when changed. Signal handlers in `settings_overlay.gd` update `SettingsStore`, apply the effect, and call `SettingsStore.save_settings()`.

Examples:

- Volume sliders update linear values, call `SettingsStore.apply_audio()`, then save.
- Fullscreen updates `SettingsStore.fullscreen`, calls `SettingsStore.apply_display()`, then save.
- Debug mode calls `Debug.set_debug_mode(value)` so the effective `Debug.enabled` gate refreshes.
- Locale writes `SettingsStore.locale`, which updates `TranslationServer` through the setter.

---

# 4. Return To Main Menu

The overlay's Return to Main Menu button closes the overlay and calls `SceneRouter.go_to_start_page()`. It is hidden on the Start Page itself.

Returning to the Start Page is a navigation action, not a save-slot mutation. Any save flush needed for current game state must be handled by SceneRouter and SaveManager, not by the overlay button.

---

# 5. Adding Settings

When adding a setting:

- Add a field and default to `SettingsStore`.
- Add it to `save_settings()` and `load_settings()`.
- Add UI nodes to `settings_overlay.tscn` with `%UniqueName` references.
- Connect the control in `_ready()` and handle changes in `_on_*` signal handlers.
- Apply the setting immediately and persist it.
- Add localization keys for visible labels.

Do not put save-slot or run-specific options in the settings overlay unless they are genuinely global user preferences.
