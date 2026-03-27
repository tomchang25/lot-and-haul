# Module API Documentation Standard

This document defines the standard format used to document gameplay modules.

Goals:

* Keep documentation **short and readable**
* Make module usage **easy to understand**
* Ensure **consistent documentation across modules**

This applies to modules located under:

```
common/gameplay/*
```

---

# 1. Document Structure

Each module documentation must follow this structure:

```
Title
Location
Purpose
Dependencies
Main API
Example
Notes
```

Keep documentation **short (recommended < 40 lines)**.

---

# 2. Title

The title must be the **module class name**.

Example:

```
# MovementModule
```

---

# 3. Location

Specify the file path of the module.

Example:

```
Location
common/gameplay/movement/movement_module.gd
```

---

# 4. Purpose

Brief description of what the module does.

Guidelines:

* 1–3 sentences
* Focus on **execution responsibility**
* Do not include gameplay logic explanations

Example:

```
Executes actor movement using CharacterBody2D velocity.
Handles acceleration, stopping, and knockback.
```

---

# 5. Dependencies

List dependencies that must be assigned by the owning actor.

Format:

```
dependency_name : type
```

Example:

```
Dependencies

character : CharacterBody2D
stats : Stats (optional)
```

Dependencies must always be **assigned by the actor** and must not be auto-discovered.

---

# 6. Main API

List the main public functions exposed by the module.

Format:

```
function_name(parameters)
short description
```

Example:

```
set_velocity(direction: Vector2)
Move actor in a direction.

stop()
Clear movement velocity.

apply_knockback(force: Vector2)
Apply knockback force.
```

Only include **important APIs**, not every internal helper.

---

# 7. Example

Provide a minimal usage example.

Example:

```
movement_module.character = self
movement_module.stats = stats

movement_module.set_velocity(input_direction)
```

Examples should be **small and focused**.

---

# 8. Notes

Optional section for important constraints or design rules.

Examples:

```
Notes

- Module does not read player input
- Module does not decide AI behavior
- Actor controls when the module runs
```

---

# Example Complete Document

```
# MovementModule

Location
common/gameplay/movement/movement_module.gd

Purpose
Executes actor movement using CharacterBody2D velocity.

Dependencies
character : CharacterBody2D
stats : Stats (optional)

Main API

set_velocity(direction: Vector2)
Move actor in direction.

stop()
Clear movement velocity.

apply_knockback(force: Vector2)
Apply knockback force.

Example

movement_module.character = self
movement_module.set_velocity(input_direction)

Notes

- Does not read player input
- Does not contain AI logic
```