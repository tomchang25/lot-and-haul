# Scene Router Usage

Use this when adding or changing Lot & Haul scene navigation.

## Add a production route

1. Add an exported `PackedScene` field to `global/autoloads/game_manager/scene_registry.gd` if the scene has no route field yet.
2. Add the target scene as an `ext_resource` in `global/autoloads/scene_router/scene_router.tscn`.
3. Assign that resource to the embedded `SceneRegistry` sub-resource.
4. Add `SceneRouter.go_to_<scene>()` and call `_navigate(scenes.<scene>)` inside it.
5. Use the new `SceneRouter.go_to_<scene>()` method from callers.

## Pass transition data

Prefer a typed one-shot pair when data is not already stored in a system:

```gdscript
SceneRouter.go_to_day_summary(summary)
```

The arriving scene consumes once:

```gdscript
var summary := SceneRouter.consume_pending_day_summary()
```

Do not use payloads for durable gameplay state. Store durable state in the owning system/store and save provider.

## Avoid

- `GameManager.go_to(...)`
- Direct `get_tree().change_scene_*()` from production scenes
- Per-scene preloads for navigable scene transitions
- New route wrappers that bypass `_navigate()` and therefore skip `SaveManager.flush()`
