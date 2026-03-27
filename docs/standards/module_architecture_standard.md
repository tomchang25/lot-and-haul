# Arise Module Architecture Standard

This document defines the structural rules used by gameplay modules in the **Arise** project.

Goals of this standard:

* Maintain consistent module architecture
* Reduce coupling between actors and gameplay systems
* Improve maintainability and debugging
* Allow modules to be reused across different actors
* Keep gameplay logic separated from low-level systems

Modules that follow this standard include (but are not limited to):

* AnimationModule
* MovementModule
* CombatModule
* DetectionModule
* DamageReceiverModule
* PlacementModule
* HealthBarModule

---

# Scope

This standard applies to gameplay modules located under:

```
common/gameplay/*
```

These modules provide reusable gameplay functionality that can be attached to actors such as:

* Player
* Enemies
* NPCs
* Summons
* World objects

This document does **not** apply to:

* UI scripts
* Editor tools
* Standalone gameplay systems
* Global managers

---

# 1. Module Structure

Every module should follow a consistent code layout order.

Example structure:

```gdscript
# -------------------------
# Lifecycle
# -------------------------

func _enter_tree()
func _ready()


# -------------------------
# Runtime State
# -------------------------

func _init_runtime_state()
func _stop_runtime_state()
func _refresh_runtime_state()


# -------------------------
# Common API
# -------------------------

func reset()
func set_enabled()
func is_enabled()


# -------------------------
# Feature APIs
# -------------------------

func do_feature_a()
func do_feature_b()


# -------------------------
# Internal Helpers
# -------------------------

func _cache_handles()


# -------------------------
# Signals / Callbacks
# -------------------------

func _on_xxx()
```

### Runtime State section

The **Runtime State** section owns all private runtime variables and the three functions that manage them.

All private runtime variables must be declared together at the top of the file (below exports).

| Function                   | Purpose                                                                              |
| -------------------------- | ------------------------------------------------------------------------------------ |
| `_init_runtime_state()`    | Set all runtime variables to their initial values. Called by `_ready()` and `reset()`. |
| `_stop_runtime_state()`    | Emergency stop — clear only what is actively running. Called by `set_enabled(false)`. |
| `_refresh_runtime_state()` | Sync external behaviour (physics process, visuals) to the current state. Called after state changes. |

Example:

```gdscript
var _enabled: bool = true

var _is_active: bool
var _current_target: Node
var _elapsed: float


func _init_runtime_state() -> void:
    _is_active = false
    _current_target = null
    _elapsed = 0.0


func _stop_runtime_state() -> void:
    _is_active = false


func _refresh_runtime_state() -> void:
    set_process(_enabled and _is_active)
```

Rules:

* All private runtime variables must be initialized inside `_init_runtime_state()`, not inline at declaration.
* `_ready()` and `reset()` both call `_init_runtime_state()` — never duplicate initialization logic between them.
* `_stop_runtime_state()` clears active state only — it does not reset everything. Use `_init_runtime_state()` for a full reset.
* `_enabled` is the only runtime variable initialized at declaration, as it must be valid before `_ready()` runs.

### Domain-specific headers

The **Feature APIs** section may use a domain-specific header when clearer.

Examples:

```gdscript
# -------------------------
# State Travel
# -------------------------
```

```gdscript
# -------------------------
# Navigation Control
# -------------------------
```

```gdscript
# -------------------------
# Knockback
# -------------------------
```

Do not rename meaningful domain headers only to match generic labels.

The standard enforces **layout order**, not header wording.

---

# 2. Lifecycle API

Every module must implement the following three functions as its public lifecycle contract:

```gdscript
func reset() -> void
func set_enabled(value: bool) -> void
func is_enabled() -> bool
```

These are required. They are the interface used by `NodeRegistry` and by parent modules or actors that own this module.

### Enabled Switch Pattern

`@export var enabled` acts as an inspector proxy only. It must always delegate to `set_enabled()`:

```gdscript
@export var enabled: bool = true:
    set(value):
        set_enabled(value)

var _enabled: bool = true


func set_enabled(value: bool) -> void:
    if _enabled == value:
        return
    _enabled = value
    if not _enabled:
        _stop_runtime_state()


func is_enabled() -> bool:
    return _enabled
```

Rules:

* `_enabled` is private. Never read or write it directly from outside the module.
* `set_enabled(false)` always triggers `_stop_runtime_state()`.
* Do not bypass `set_enabled()` by writing to `_enabled` directly.

### reset()

`reset()` restores all runtime state to its initial values, as if `_ready()` just ran.

```gdscript
func reset() -> void:
    _init_runtime_state()
    set_enabled(true)
```

Rules:

* Always call `_init_runtime_state()` first, then `set_enabled(true)`.
* Do not call `_apply_data()` or `_bind_modules()` inside `reset()`.
* Modules that own child modules must call `reset()` on them too.

### set_enabled() on child modules

Modules that own child modules must propagate `set_enabled()` to them:

```gdscript
func set_enabled(value: bool) -> void:
    if _enabled == value:
        return
    _enabled = value
    if not _enabled:
        _stop_runtime_state()
    child_module_a.set_enabled(value)
    child_module_b.set_enabled(value)
```

### Purpose of each function

| Function                | Purpose                                                                |
| ----------------------- | ---------------------------------------------------------------------- |
| `_init_runtime_state()` | Initialize all runtime variables — called by `_ready()` and `reset()` |
| `reset()`               | Restore to initial state — called by NodeRegistry on acquire           |
| `set_enabled()`         | Enable or disable — called by NodeRegistry on release and by actors    |
| `is_enabled()`          | Read current enabled state                                             |

---

# 3. Dependency Assignment Pattern

Gameplay modules must **not auto-wire dependencies**.

All dependencies must be assigned by the **entity that owns the modules**.

Examples of entities:

* Player
* Enemy
* NPC
* Summon
* World object

Dependencies may include:

* actor references
* cross-module references
* gameplay nodes (AnimationTree, Hitbox, Hurtbox)
* navigation agents
* stats resources

Modules should only **use the references they are given**.

### Responsibility

```
Entity
  └ creating or owning scene components

Module
  └ receives references and executes behavior
```

### Correct Example

Entity script:

```gdscript
func _wire_modules() -> void:
    navigation_module.character = self
    navigation_module.movement = movement_module
    navigation_module.navigation_agent = navigation_agent

    animation_module.animation_tree = animation_tree
    combat_module.hitbox = hitbox
    damage_receiver.stats = stats
```

Module script:

```gdscript
@export var character: CharacterBody2D
@export var movement: MovementModule
@export var navigation_agent: NavigationAgent2D
```

Modules must **never search the scene tree for dependencies**.

---

# 4. Handle Caching Pattern

Modules may cache derived runtime handles or expensive lookups.

Examples:

* AnimationTree playback objects
* NodePath resolutions
* search results

Typical helper:

```
func _cache_handles() -> void
```

Example:

```gdscript
_playback = animation_tree.get(state_machine_path)
```

Rule:

* Cache **derived runtime handles**
* Do **not cache exported node references**

Example of what **not** to cache:

```gdscript
@export var character: CharacterBody2D
```

Exported references are already direct pointers.

---

# 5. Public API Rules

Module public APIs should follow these principles:

* Small surface area
* Clear verb-based names
* No gameplay decision logic

Examples of good APIs:

```
travel(state)
set_blend_position()
set_time_scale()
stop()
scan()
attack()
```

Examples of bad APIs:

```
decide_attack_target()
handle_combat_logic()
choose_state_transition()
```

Modules should act as **tools**, not **decision makers**.

### Safety Guard

Public functions should guard against invalid states.

Example:

```gdscript
if not _enabled:
    return

if animation_tree == null:
    return
```

This prevents runtime crashes and allows modules to be safely called without strict ordering.

---

# 6. Modules Should Not Own Gameplay Logic

Modules must not contain gameplay decision logic.

| Module    | Allowed              | Not Allowed            |
| --------- | -------------------- | ---------------------- |
| Animation | play animation state | decide animation state |
| Movement  | move actor body      | read player input      |
| Combat    | execute attack       | decide when to attack  |
| Detection | detect targets       | choose attack target   |

Gameplay decisions should exist in:

```
Player
Enemy
StateMachine
AI
```

Modules only **execute behavior**.

---

# 7. Export Groups

Use export groups to organize inspector properties.

Example:

```gdscript
@export_group("AnimationTree Paths")
@export var state_machine_path

@export_group("Behavior")
@export var reset_time_scale_on_disable
```

Benefits:

* Cleaner inspector layout
* Easier configuration
* Consistent editor experience

---

# 8. Signal Bridging

Modules may expose signals from internal systems.

Example:

```gdscript
signal animation_finished
```

Internally:

```gdscript
animation_tree.animation_finished.connect(_on_animation_finished)
```

This allows actors to respond to module events without depending on internal nodes.

---

# Module Layout Summary

A typical module follows this structure:

```
enabled switch
export configuration
private runtime variables

Lifecycle
Runtime State
Common API
Feature APIs
Internal Helpers
Signals / Callbacks
```

Following this structure ensures modules remain:

* predictable
* maintainable
* reusable
* consistent across the project

---