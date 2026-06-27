# Scene Routing Standard

This document defines how Lot & Haul scene transitions are owned, registered, and called.

---

# 1. Ownership

`SceneRouter` owns all normal scene transitions. `GameManager` owns boot orchestration only: boot mode detection, save loading, validation, and fatal boot fallback. Do not add navigation methods or scene tables back to `GameManager`.

All gameplay and meta scenes call the named `SceneRouter.go_to_*()` methods. The router is responsible for flushing deferred saves before crossing scene boundaries, emitting `scene_changed`, and carrying one-shot transition payloads such as day-summary and fatal-error data.

---

# 2. Scene Registration

Scene references are wired in `global/autoloads/scene_router/scene_router.tscn` through a `SceneRegistry` resource. The `SceneRegistry` script currently lives under `global/autoloads/game_manager/scene_registry.gd` because it began as boot infrastructure, but the resource is part of the routing system and should be treated as SceneRouter-owned.

When adding a navigable scene:

- Add the scene as an `ext_resource` in `scene_router.tscn`.
- Add an exported field to `SceneRegistry` only when a new named route is needed.
- Add a narrow `SceneRouter.go_to_<scene>()` wrapper that calls `_navigate(scenes.<scene>)`.
- Prefer explicit route methods over string route keys in gameplay code.

---

# 3. Navigation Calls

Use the most specific router method available:

```gdscript
SceneRouter.go_to_hub()
SceneRouter.go_to_location_select()
SceneRouter.go_to_run_resume(RunSystem.get_resume_target())
SceneRouter.go_to_day_summary(summary)
SceneRouter.go_to_start_page()
```

Do not call `get_tree().change_scene_to_file()` or `get_tree().change_scene_to_packed()` from normal game scenes. The debug-only testbed launcher is the exception because it intentionally enters stage/testbed content outside the production flow.

---

# 4. Payloads

Payloads must be explicit and one-shot.

- Day summary uses `go_to_day_summary(summary)` and `consume_pending_day_summary()`.
- Fatal boot errors use `go_to_fatal_error(title, errors)` and `consume_pending_fatal()`.

Do not use payloads as save state. Durable state belongs in `RunSystem`, `MetaSystem`, `KnowledgeSystem`, or another save provider.

---

# 5. Save Safety

Every production route must pass through `_navigate()`, because `_navigate()` calls `SaveManager.flush()` before changing scenes. A failed flush warns through `ToastManager` but does not block navigation.

If you add a new route wrapper and bypass `_navigate()`, you are creating a save-loss bug.

---

# 6. Review Checklist

- New scene is registered in `scene_router.tscn` and `SceneRegistry`.
- Call sites use `SceneRouter.go_to_*()`, not `GameManager` or direct tree scene changes.
- Save-bearing transitions go through `_navigate()`.
- One-shot payloads are consumed once and cleared.
- Resume routing remains centralized in `go_to_loaded_save_entry()` / `go_to_run_resume()`.
