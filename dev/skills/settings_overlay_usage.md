# Settings Overlay Usage

Use this when adding settings or settings entry points.

## Open settings

```gdscript
SettingsStore.toggle_overlay()
```

For gameplay screens that need a visible button, pre-place `game/shared/settings_button_overlay/settings_button_overlay.tscn` in the screen `.tscn`.

## Add a setting

1. Add a field/default in `global/autoloads/settings_store.gd`.
2. Read/write it in `load_settings()` and `save_settings()`.
3. Add controls to `game/shared/settings_overlay/settings_overlay.tscn`.
4. Add `%UniqueName` `@onready` references in `settings_overlay.gd`.
5. Connect signals in `_ready()`.
6. Apply immediately and call `SettingsStore.save_settings()`.
7. Add localization keys for all visible labels.

Use `user://settings.json` for user/device preferences. Use gameplay save providers for slot-specific state.

## Debug checkbox

Use `Debug.set_debug_mode(pressed)`, not `SettingsStore.debug_mode = pressed`, so persistence and `Debug.toggled` stay centralized.
