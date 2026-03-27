# System API Documentation Standard

This document defines the standard format used to document **gameplay systems**.

Goals:

* Explain how multiple components work together
* Describe the **execution flow of a system**
* Provide clear usage examples
* Keep documentation **structured but concise**

This applies to systems such as:

* Spawn system
* Loot system
* Pickup system
* Combat system
* Dungeon generation system

---

# 1. What Is a System

A **system** coordinates multiple components to implement gameplay functionality.

Components may include:

* modules
* resources
* scenes
* helper classes

Example systems:

```
Spawn system
Loot system
Pickup system
Combat system
Dungeon generation system
```

Difference from modules:

| Type   | Responsibility                  |
| ------ | ------------------------------- |
| Module | Executes behavior for an actor  |
| System | Coordinates multiple components |

Modules are tools.
Systems define **how tools work together**.

---

# 2. Document Structure

Each system documentation must follow this structure:

```
Title
Location
Purpose
Core Components
System Flow
Main API
Typical Usage
Design Rules
Notes
```

Recommended length:

```
40–80 lines
```

---

# 3. Title

The title must be the **system name**.

Example:

```
# Spawn System
```

---

# 4. Location

Specify the main folder containing the system.

Example:

```
Location
common/gameplay/spawning/
```

If the system spans multiple folders, specify the **main root location**.

---

# 5. Purpose

Describe what the system does.

Guidelines:

* 1–3 short paragraphs
* Describe responsibilities
* Avoid deep implementation details

Example:

```
Handles runtime entity spawning.

Allows enemies, objects, and events to spawn entities
through spawn actions and weighted spawn tables.
```

---

# 6. Core Components

List the important parts of the system.

Format:

```
ComponentName
Short description
```

Example:

```
SpawnPoint
Scene anchor that triggers spawn actions.

SpawnAction
Defines spawn behavior.

SpawnRequest
Runtime object responsible for executing a spawn.

WeightedSceneTable
Randomized scene selection.
```

This section explains **what pieces exist in the system**.

---

# 7. System Flow

Describe the execution pipeline of the system.

Use a simple flow diagram.

Example:

```
SpawnPoint
   ↓
SpawnAction
   ↓
SpawnRequest
   ↓
SpawnExecutor
   ↓
Spawned Entity
```

Then optionally explain the steps.

Example:

```
1. A spawn source triggers a spawn.
2. A SpawnAction prepares spawn behavior.
3. A SpawnRequest is created.
4. The request executes and spawns the entity.
```

---

# 8. Main API

Document the primary public APIs exposed by the system.

Format:

```
function_name(parameters)
Short description
```

Example:

```
SpawnRequest.execute() -> Node
Executes the spawn request and returns the spawned node.
```

Example usage:

```gdscript
var request := SpawnRequest.new()
request.action = spawn_action
request.global_position = position

var spawned := await request.execute()
```

Only include **important APIs**, not every helper function.

---

# 9. Typical Usage

Describe common usage scenarios.

Example:

### Spawn from SpawnPoint

```
SpawnPoint
   ↓
SpawnAction
   ↓
SpawnRequest
   ↓
Spawned Enemy
```

### Manual spawn

```gdscript
var request := SpawnRequest.new()
request.action = enemy_spawn_action
request.global_position = position
request.spawn_parent = world

await request.execute()
```

---

# 10. Design Rules

Describe important architectural rules.

Example:

```
- Systems coordinate multiple components
- Systems should not depend on specific actors
- Actors may trigger systems
- Modules execute behavior, systems coordinate execution
```

---

# 11. Notes

Optional section for constraints or important details.

Example:

```
- Spawn execution may be asynchronous
- Spawn parent must be set correctly
- Spawn actions must validate configuration
```

---

# Example Complete System Document

```
# Spawn System

Location
common/gameplay/spawning/

Purpose
Handles runtime entity spawning using spawn actions
and weighted spawn tables.

Core Components

SpawnPoint
Scene anchor that triggers spawn actions.

SpawnAction
Defines spawn behavior.

SpawnRequest
Runtime object that executes spawning.

System Flow

SpawnPoint
   ↓
SpawnAction
   ↓
SpawnRequest
   ↓
Spawned Entity

Main API

SpawnRequest.execute() -> Node
Execute the spawn request.

Typical Usage

var request := SpawnRequest.new()
request.action = spawn_action
request.global_position = position

var node := await request.execute()

Design Rules

- Systems coordinate multiple components
- Actors may trigger systems
- Modules execute behavior

Notes

- Spawn execution may be asynchronous
```