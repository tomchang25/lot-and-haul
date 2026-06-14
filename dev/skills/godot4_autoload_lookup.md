# Godot 4 Autoload Lookup

## Overview

Godot project autoloads are often called "singletons", but they are not the same thing as `Engine` singletons. Do not use `Engine.has_singleton()` or `Engine.get_singleton()` to check whether a `project.godot` autoload exists.

This is especially important for boot audits, registry checks, and fatal-error guards: a real autoload can be present and usable through its global name while `Engine.has_singleton("Name")` still returns `false`.

---

## The trap

```ini
[autoload]
ClueRegistry="*res://global/autoloads/registries/clue_registry.gd"
```

This creates a node at:

```text
/root/ClueRegistry
```

It does **not** register an Engine singleton named `ClueRegistry`.

So this is wrong for project autoload checks:

```gdscript
# Wrong for project.godot autoloads
if not Engine.has_singleton(&"ClueRegistry"):
    push_error("ClueRegistry autoload not found")
```

`Engine.has_singleton()` checks Engine-level singletons, such as built-in engine services or objects registered through `Engine.register_singleton()`. It does not inspect `/root` autoload nodes.

---

## The fix

When checking a project autoload from normal node code, look under the scene tree root:

```gdscript
# Project autoload node lookup
var clue_registry := get_tree().root.get_node_or_null("ClueRegistry")
if clue_registry == null:
    push_error("ClueRegistry autoload not found")
```

When checking from a static helper that cannot call `get_tree()`, resolve the active `SceneTree` first:

```gdscript
# Static helper variant
static func _resolve_autoload(autoload_name: StringName) -> Node:
    var tree := Engine.get_main_loop() as SceneTree
    if tree == null:
        return null
    return tree.root.get_node_or_null(String(autoload_name))
```

If the autoload has an expected base type, cast after lookup:

```gdscript
static func _resolve_registry(autoload_name: StringName) -> ResourceRegistry:
    var tree := Engine.get_main_loop() as SceneTree
    if tree == null:
        return null
    var instance := tree.root.get_node_or_null(String(autoload_name))
    return instance as ResourceRegistry
```

---

## When direct access is better

If the code is not doing optional existence checks, prefer direct autoload access and let Godot fail loudly on wiring mistakes:

```gdscript
if ClueRegistry.size() <= 0:
    ToastManager.show_error("ClueRegistry is empty")
```

Use `/root` lookup only when the code genuinely needs to collect or report missing-autoload errors without crashing immediately.

---

## Rule of thumb

Use this distinction:

| Thing | Lookup |
| --- | --- |
| Project autoload from `project.godot` | `get_tree().root.get_node_or_null("Name")` |
| Project autoload from static code | `(Engine.get_main_loop() as SceneTree).root.get_node_or_null("Name")` after null guard |
| Engine-level singleton | `Engine.has_singleton("Name")` / `Engine.get_singleton("Name")` |

If the autoload appears in `project.godot`, assume it is a `/root` node, not an Engine singleton.

---

## In this project

Registry autoloads such as `ClueRegistry`, `AnchorRegistry`, `AffixRegistry`, `CarRegistry`, `LocationRegistry`, `CategoryRegistry`, and `SuperCategoryRegistry` are `ResourceRegistry` nodes registered in `project.godot`.

Boot checks for those registries should resolve them through the scene tree root and then cast to `ResourceRegistry`. Using `Engine.has_singleton()` here produces false "autoload not found" failures and can send the game to the fatal-error screen even when the autoload order is correct.
