# Arise Naming Conventions

This document defines the naming conventions used in the Arise project.

The goal is to keep the project:

- consistent
- readable
- easy to search
- aligned with Godot conventions

---

# 1. File Naming

All files use **snake_case**.

Examples:

```
movement_module.gd
animation_module.gd
damage_receiver_module.gd
spawn_point.gd
player_state_idle.gd
```

Scene files should match their script names when possible.

Example:

```
player.tscn
player.gd
```

---

# 2. Class Names

Classes use **PascalCase**.

Examples:

```
Player
Enemy
MovementModule
AnimationModule
DetectionModule
DamageReceiverModule
```

This follows the common Godot style.

---

# 3. Variables

Variables use **snake_case**.

Examples:

```
current_target
attack_range
movement_speed
animation_tree
hitbox_node
```

Avoid abbreviations unless they are very common.

Bad:

```
atk_rng
spd
```

Good:

```
attack_range
movement_speed
```

---

# 4. Functions

Functions use **snake_case**.

Examples:

```
apply_damage()
set_enabled()
travel()
set_blend_position()
clear_targets()
```

Internal/private helper functions use a leading underscore.

Examples:

```
_auto_wire()
_cache_handles()
_stop_runtime_state()
_on_animation_finished()
```

---

# 5. Signals

Signals use **snake_case**.

Examples:

```
animation_finished
health_changed
target_detected
attack_started
```

---

# 6. Constants

Constants use **UPPER_SNAKE_CASE**.

Examples:

```
MAX_HEALTH
DEFAULT_ATTACK_RANGE
DASH_DURATION
```

---

# 7. Enums

Enums use **PascalCase** for the enum name and **UPPER_SNAKE_CASE** for values.

Example:

```gdscript
enum AttackType {
    MELEE,
    PROJECTILE,
    AREA
}
```

---

# 8. Node Names

Node names in scenes use **PascalCase**.

Examples:

```
AnimationTree
Sprite2D
Hitbox
Hurtbox
HealthBar
DetectionArea
```

---

# 9. Module Naming

Gameplay modules follow this pattern:

```
<feature>_module.gd
```

Examples:

```
movement_module.gd
animation_module.gd
combat_module.gd
detection_module.gd
```

Classes use:

```
<Feature>Module
```

Examples:

```
MovementModule
AnimationModule
CombatModule
DetectionModule
```

---

# 10. Controller Naming

Standalone runtime nodes that make ongoing decisions follow this pattern:

```
<feature>_controller.gd
```

Examples:

```
encounter_controller.gd
open_map_encounter_controller.gd
despawn_controller.gd
```

Classes use:

```
<Feature>Controller
```

Examples:

```
EncounterController
OpenMapEncounterController
DespawnController
```

Use **Controller** when the node:
- Has its own lifecycle (starts, ticks, stops)
- Makes active decisions each frame or in response to events
- Coordinates one or more systems without being attached to a specific actor

Do **not** use Controller for:
- Modules attached to actors → use `<Feature>Module`
- Passive data containers or registries → use a descriptive noun (`SpawnRegistry`, `EventBus`)
- Global autoloads → use `<Feature>Manager` or a descriptive noun

---

# 11. Actor Naming

Actors use the actor name as the folder name.

Example:

```
game/actors/player/
game/actors/enemies/
game/actors/summons/
```

Typical actor structure:

```
player/
├ player.gd
├ player.tscn
├ state/
├ data/
└ art/
```

---

# Summary

| Type | Style | Example |
|---|---|---|
| Files | snake_case | `movement_module.gd` |
| Classes | PascalCase | `MovementModule` |
| Variables | snake_case | `attack_range` |
| Functions | snake_case | `apply_damage()` |
| Signals | snake_case | `health_changed` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH` |
| Enums | PascalCase + UPPER_SNAKE_CASE | `AttackType.MELEE` |
| Nodes | PascalCase | `HealthBar` |
| Modules | `<feature>_module` | `MovementModule` |
| Controllers | `<feature>_controller` | `EncounterController` |