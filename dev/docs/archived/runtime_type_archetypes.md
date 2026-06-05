# Runtime Type Archetypes

Runtime types live in `common/gameplay/`. This standard defines the four archetypes they split into and the boundary between them. It defines the **boundaries**, not the membership — which concrete class is which archetype is read straight off the folder tree and class names (that is code-level detail, never written down anywhere; a written copy only rots).

The single question that classifies a runtime type: *does it hold mutable state, and does it own the behaviour that maintains it?*

## The four archetypes

- **Entry (Instance)** (`common/gameplay/*.gd`) — a live instance of a designer **Data**: identity + mutable state + the behaviour that maintains it. The runtime twin of an authored resource; self-serializes when persisted.
- **Store** (`common/gameplay/store/`) — a Manager-held container of one domain's live state. Owns its fields and the mutators that guard their invariants; a Manager autoload holds it and drives it. **Serialization is optional** — a Store carries a save payload (section id + to/from-dict) only when its state must survive save/load. A Store whose state is scoped to a single transient session and never persists is a **Session**: same shape, narrower lifetime, no save payload.
- **Snapshot** (`common/gameplay/snapshot/`) — a read-only value object derived from state at one instant and handed across a boundary (Manager → scene), then discarded. Computed/getter fields only; no mutators, no serialization, no autoload reads. A projection, not a container.
- **Service** (`common/gameplay/service/`) — stateless: pure math / helper functions with no per-instance state.

Serialization is an **orthogonal capability, not an archetype**: Entries and Stores may or may not persist; Snapshots and Services never do. **Store is the superset and Session the non-persisting subset** — they are not split into separate base types until a Session actually needs to survive save/load.

## Discriminator (apply in order)

1. No per-instance state → **Service**.
2. Read-only, derived, one-shot transport → **Snapshot**.
3. Mutable state + invariant-guarding mutators, Manager-held → **Store** (a **Session** if it never persists).
4. A saved/identified instance of a Data → **Entry (Instance)**.

## Naming

The Entry archetype is being renamed to **Instance** — that is its going-forward name. New instance-of-a-Data types take the `*Instance` suffix (e.g. `ItemInstance`). Existing `*Entry` classes (`ItemEntry`, `LotEntry`) keep their names until renamed in a later pass; until then, `Entry` and `Instance` denote the same archetype. The folder (`common/gameplay/*.gd`, alongside `store/` / `snapshot/` / `service/`) is the source of truth for the archetype regardless of the suffix a given class still carries.
