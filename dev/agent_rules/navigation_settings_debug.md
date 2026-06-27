# Navigation, Settings, And Debug Rule

Read this before changing scene navigation, the Start Page, settings UI/storage, or debug-only behavior.

## Required References

- Scene navigation: read `dev/standards/scene_routing_standard.md` and use `dev/skills/scene_router_usage.md`.
- Start Page: read `dev/standards/start_page_standard.md`.
- Settings: read `dev/standards/settings_overlay_standard.md` and use `dev/skills/settings_overlay_usage.md`.
- Debug code: read `dev/standards/debug_standard.md` and use `dev/skills/debug_mode_usage.md`.

## Hard Rules

- Do not put scene routing back into `GameManager`.
- Do not bypass `SceneRouter` from production gameplay/meta screens.
- Do not add route wrappers that bypass `SceneRouter._navigate()` unless the scene is debug/stage infrastructure and intentionally outside production flow.
- Do not store user/device preferences in gameplay saves or save slots; `SettingsStore` owns `user://settings.json`.
- Do not add debug behavior outside `Debug.enabled`.
- Keep Start Page code limited to title-screen, slot-selection, settings, quit, and debug-only testbed entry flow.

## Lot & Haul Specifics

- `SceneRouter._navigate()` flushes deferred saves before scene changes; preserving that route path is part of save safety.
- `SceneRouter.go_to_loaded_save_entry()` and `SceneRouter.go_to_run_resume()` centralize load/resume routing. Do not duplicate resume branching in Start Page or individual scenes.
- The testbed launcher may bypass production routing because it is stage/debug infrastructure.
