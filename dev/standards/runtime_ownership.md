# Runtime Ownership

This document defines which runtime role may own which state. Naming conventions define the suffix; this standard defines the ownership boundary behind the suffix. The four `common/gameplay/` runtime archetypes are defined separately in `runtime_type_archetypes.md`.

---

# 1. Primary Test

Classify runtime code by lifetime, source of truth, and save/checkpoint requirement before choosing a suffix.

| Question                                                                                     | If yes                                                               | If no                           |
| -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------------------- |
| Does the state exist only inside one active scene/session and get discarded with that scene? | It may belong to a `Controller`.                                     | It needs a domain owner.        |
| Must the state survive save/load, checkpoint restore, scene changes, or run resume?          | It belongs to a `Store`, save provider, `System`, or explicit owner. | It may remain scene-local.      |
| Is the state trusted by multiple systems as domain truth?                                    | It belongs to the concept owner.                                     | A controller may coordinate it. |
| Is the script pure computation with no mutable state or side effects?                        | It may be a `Service` or helper.                                     | Do not call it a pure service.  |

---

# 2. Controller

Use `Controller` for scene-scoped scripts that orchestrate runtime flow between scene nodes, UI, and domain owners for the current active session.

A controller may own state that is discarded with the scene, such as current offer, selected interaction mode, pending transition, preview selection, or other UI/session flow state.

A controller may call systems to apply domain mutations, but it must not silently become a second source of truth for an entry, store, save section, or manager-held domain state.

Controllers do not belong under `common/gameplay/` because they are not one of the four runtime type archetypes. Put them with the scene or feature block they orchestrate unless a project-specific standard says otherwise.

---

# 3. Domain Owners

State that must outlive the controller, be serialized, be restored from checkpoint, or serve as cross-system truth belongs to the owner of that concept.

Examples:

| Concept               | Owner                                              |
| --------------------- | -------------------------------------------------- |
| Persisted settings    | Settings store/provider.                           |
| Run state             | `RunSystem` and its stores.                        |
| Meta progression      | `MetaSystem` and its stores.                       |
| Knowledge progression | `KnowledgeSystem` and its stores.                  |
| Save payload          | The provider that owns the state being serialized. |

If a scene-local controller state later needs checkpoint, save, or cross-scene resume, promote that state into the relevant owner instead of adding ad-hoc persistence to the controller.

---

# 4. System

Use `System` for a domain coordinator, mutation gateway, save provider, or aggregate owner when a concept is broader than one scene or must mediate mutations for consistency.

Scenes and controllers call system methods for mutations instead of mutating entries or stores directly. The system coordinates invariants, signalling, and save dirtiness.

---

# 5. Store

Use `Store` for mutable domain state containers. Stores own live fields for one domain and guard invariants through mutators. Persisting stores own their save payload; session-scoped stores may be serialized as part of an owning system snapshot.

Do not create a store only to hold short-lived UI flow state that dies with the scene.

---

# 6. Service

Use `Service` only for stateless computation. A service takes inputs, computes outputs, and returns results without owning mutable state, mutating stores, changing scene nodes, opening UI, or applying gameplay side effects.

Code that applies side effects may still be a helper or applier, but do not classify it as a pure service.
