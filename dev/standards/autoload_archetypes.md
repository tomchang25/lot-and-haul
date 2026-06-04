# Autoload & Domain Archetypes

This standard defines the small set of **roles** a global system may take, and the
rules that keep state ownership, persistence, and cross-domain transactions in the
right layer. The goal is a shape that generalizes across projects: every autoload
answers to exactly one archetype, so a new game built on the same template grows
the same skeleton instead of a bespoke pile of "managers."

The single organizing idea: **a behavior boundary and a persistence boundary are
the same boundary.** The thing that mutates a slice of state is the thing that
serializes it, and nothing reaches across that boundary except through a public
API.

---

## 1. The archetypes

Each role answers one question and holds one kind of responsibility. Suffix names
the role.

| Archetype                                              | Owns                                                                                                                                                                 | May it hold gameplay state?       | Autoload?                   |
| ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- | --------------------------- |
| **Composition Root** (`GameManager` / `AppManager`)    | Boot order: load save, run migrations/validation/audit, initialize systems, hand off to the first scene.                                                             | No                                | Yes                         |
| **Router** (`SceneRouter`)                             | Scene transitions and short-lived navigation payloads (e.g. a pending hand-off).                                                                                     | No (only ephemeral nav payload)   | Yes                         |
| **Persistence Coordinator** (`SaveManager`)            | File IO, schema/migration, dispatch to registered providers. The _only_ system that touches the save file.                                                           | No                                | Yes                         |
| **Domain Manager** (`MetaManager`, `KnowledgeManager`) | One cohesive runtime domain. Holds its Store(s), exposes a focused command/query API, sequences its domain's transactions (and may call peer Managers' public APIs), registers its Stores for save. | Indirectly, through its Stores    | Yes                         |
| **Store** (`EconomyStore`, …)                          | A serializable runtime state slice: its fields, its invariants, its mutators, and its own `section_id`/`to_dict`/`from_dict`. Lives in `common/gameplay/`.           | Yes (the actual state lives here) | **Never**                   |
| **Coordinator** (`RegistryCoordinator`)                | A registry of peers plus lifecycle fan-out (migrate/validate). Holds no domain state. A state-light Service that knows its participants.                             | No                                | Yes                         |
| **Registry** (`*Registry`)                             | Load and query of designer resources. No live gameplay state.                                                                                                        | No                                | Yes                         |
| **Service** (`SellMath`, `*Rules`, `*Calculator`)      | Stateless policy, math, or helper. Takes inputs, returns outputs.                                                                                                    | No                                | No (called, not registered) |

A Domain Manager that holds many _cohesive_ transactions is **not** a God Object.
A God Object holds raw state publicly, lets outsiders mutate it, and accumulates
_unrelated_ responsibilities. Cohesion is the test: if every method belongs to the
same domain loop, the aggregate is correct.

---

## 2. Hard rules

These are the rules that, when broken, rot the architecture. They are the reason
the archetypes exist.

1. **Store is the only save section.** A Domain Manager registers the Stores it
   holds; a Manager or any other autoload is _never itself_ a save section. The
   persistence coordinator therefore only ever sees Stores — never a mix of Stores
   and autoload nodes. (Registration is a single call over the Manager's Store
   list, not one line per Store.)

2. **Stores never reach outward.** A Store touches only its own domain's state,
   invariants, and serialization. It never calls another Store, a Manager, or the
   persistence coordinator. A Store is a boundary, not a dependency hub — the
   moment Stores call each other they become a small God-Object network.

3. **One save per transaction, at the commit point.** The system that _sequences_
   a transaction (a Manager for a single-domain transaction, a use-case for a
   cross-domain one) calls save exactly once, at the end. Stores never save;
   helpers and no-save primitives never save. This guarantees the persisted state
   is either pre- or post-transaction, never half-applied.

4. **Transaction placement follows its span:**
   - _Within one domain's Stores_ → a public method on that domain's Manager.
   - _Across two or more Managers, and it mutates state_ → a public method on the
     Manager that owns the flow, calling the other Managers' **public APIs**
     directly; promote it to a thin **use-case** only if it earns its own file
     (Rule 7). The Manager tier is a public API surface — Manager→Manager
     public-API calls are accepted, including cohesive cycles. What is **still
     forbidden**: gathering all transactions into one global transaction hub (that
     _is_ a God Object wearing a cleaner name; it is **not** the Coordinator
     archetype, which does lifecycle/dispatch fan-out and never sequences gameplay).
     Whatever sequences the transaction still commits exactly once (Rule 3), and no
     Store is dragged across the boundary (Rule 2). _Rationale: in a single-player
     game with fixed-order autoloads, policing Manager-tier coupling costs more
     ceremony than it returns; the load-bearing boundaries are the Store edge and
     the single save commit, not the Manager mesh._
   - _Read-only query across Managers_ → a direct public-API call is fine.
   - _Non-transactional side effect_ (UI refresh, audio, analytics, tutorial hint)
     → an event. Never route a flow that needs a single save commit through events.

5. **Scenes call one entry point per action.** A scene invokes a single
   use-case/Manager method and lets it orchestrate; a scene never sequences several
   Managers itself, and never calls the persistence coordinator (except an explicit
   manual-save UI). If a scene is assembling a transaction, the transaction is in
   the wrong place.

6. **Public method saves; primitives don't.** A transaction that must persist
   exposes exactly one public method that saves. The no-save primitives it composes
   are internal — callers outside the owning Manager/use-case must not call them.
   GDScript has no true `private`; the boundary is held by naming convention and
   this standard, and is a review concern.

7. **A transaction earns its own file.** Default: a transaction lives as a method on
   its domain Manager. It is promoted to a standalone use-case only when it _earns_
   it — it crosses two Managers, or it grows complex enough to test independently.
   Do not pre-build a use-case layer, factory, or per-action scaffolding ahead of
   need. (This is the maturity scale from `CLAUDE.md` applied to behavior.)

---

## 3. Placing a new system — the checklist

Every global must answer these unambiguously:

```
Does it own persistent gameplay state?
  yes → Domain Manager (+ Store[s])
  no  → Composition Root / Router / Coordinator / Registry / Service

Does it write the save file?
  only the Persistence Coordinator does file IO
  only Stores produce/consume section payloads

Does it sequence cross-domain gameplay that mutates state?
  one domain      → a method on that Domain Manager
  two+ Managers   → a use-case over their public APIs (commits once)

Is it pure navigation?   → Router
Is it boot/init only?    → Composition Root
Is it stateless policy?  → Service
```

If a system answers "yes" to more than one of _own state / route / persist / boot_,
it is carrying two roles and should be split.

---

## 4. Naming

Suffix encodes role; avoid project-specific vocabulary in the generalized template
so the skeleton ports between games. A project may keep a domain-specific name
(e.g. a hub-phase Manager named for its phase) as long as the _role_ is
unmistakable from the archetype table — generalize the name in the template, not
necessarily in every existing project.

| Role                    | Generalized name                               | Suffix rule                             |
| ----------------------- | ---------------------------------------------- | --------------------------------------- |
| Boot / composition root | `GameManager` / `AppManager`                   | `Manager` (singular, the root)          |
| Navigation              | `SceneRouter`                                  | `Router`                                |
| Persistence             | `SaveManager`                                  | `Manager` (the persistence coordinator) |
| Domain authority        | `<Domain>Manager`                              | `Manager`                               |
| Persistent state slice  | `<Domain>Store`                                | `Store`                                 |
| Peer lifecycle fan-out  | `<Thing>Coordinator`                           | `Coordinator`                           |
| Designer data           | `<Thing>Registry`                              | `Registry`                              |
| Stateless policy/math   | `<Thing>Rules` / `<Thing>Calculator` / `*Math` | none — never an autoload                |

---

## 5. Enforcement

These are **review-time** rules today. Consistent with `standards_enforcement.md`,
a rule earns a machine check only once it has drifted enough to be worth one — none
of these are pre-declared as future checks. Two are cheaply greppable if drift
starts (a save provider that is an autoload node rather than a Store; a Store
that calls a Manager/`SaveManager`); promote them to `lint_standards.py` only when
that happens.
