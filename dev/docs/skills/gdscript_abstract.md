# GDScript Abstract Classes & Methods (Godot 4.5+)

## Overview

Godot 4.5 introduced the `@abstract` annotation for classes and methods.
Use it to define a common interface that child classes must implement.

---

## Abstract Class

```gdscript
@abstract
class_name Shape
extends Node
```

- Cannot be instantiated directly — attempting to do so causes a runtime error.
- Cannot be attached to a Node in the editor (engine will print an error on run).
- Works with both `class_name` scripts and inner classes.
- `@abstract` must be placed before `extends`.

---

## Abstract Method

```gdscript
@abstract func draw() -> void
```

- No body — just the signature followed by a newline or semicolon.
- Every **concrete** (non-abstract) subclass **must** implement all abstract methods.
- If a subclass doesn't implement all abstract methods, it must also be marked `@abstract`.
- A class with at least one abstract method must be marked `@abstract`.
- The reverse is not required: an abstract class may have zero abstract methods.

---

## Optional Override Pattern

If a method should be **overridable but not required**, use a normal method with a default (empty) implementation instead:

```gdscript
@abstract
class_name AttackModule
extends Node2D

var enabled: bool = true

# Every subclass MUST answer this
@abstract func can_attack() -> bool

# Subclasses override only what they need
func execute_attack(target_position: Vector2, data: AttackData) -> void:
    pass

func end_attack() -> void:
    pass

func activate_attack(data: AttackData) -> void:
    pass

func deactivate_attack() -> void:
    pass
```

This way subclasses only override the 2–3 methods relevant to them, without being forced to write empty `pass` stubs for everything else.

---

## Concrete Subclass Example

```gdscript
class_name MeleeAttackModule
extends AttackModule

func can_attack() -> bool:
    return enabled

func execute_attack(target_position: Vector2, data: AttackData) -> void:
    # melee logic
    pass

func end_attack() -> void:
    # cleanup
    pass
```

---

## Inner Class Support

```gdscript
@abstract
class_name AbstractClass
extends Node

@abstract class AbstractSubClass:
    func _ready():
        pass

class ConcreteClass extends AbstractSubClass:
    func _ready():
        print("ready")
```

---

## Key Rules Summary

| Situation | What to do |
|---|---|
| Method every child must implement | `@abstract func` |
| Method only some children need | Normal method with `pass` body |
| Class that shouldn't be instantiated | `@abstract class_name` |
| Subclass missing an abstract impl | Must also be `@abstract` |
| Attaching abstract script to a Node | ❌ Not allowed |

---

## Virtual Methods (Engine Built-ins)

GDScript has no `virtual` keyword. Engine lifecycle methods like `_ready()`, `_process()`, `_input()` etc. are implicitly virtual — override them freely. They are marked as `virtual` in the official class reference.

Do **not** try to override non-virtual engine methods like `get_class()` or `queue_free()` — this is blocked by the `NATIVE_METHOD_OVERRIDE` warning (treated as error by default).
