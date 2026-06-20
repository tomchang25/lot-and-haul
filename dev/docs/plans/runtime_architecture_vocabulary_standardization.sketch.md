# Runtime Architecture Vocabulary Standardization

## Goal

Standardize the runtime architecture vocabulary so each suffix communicates ownership and mutation responsibility. The change separates gameplay domain authorities from infrastructure managers, removes the ambiguous Entry/Instance dual name, and makes future refactors easier to review by naming layer boundaries directly.

## Requirements

1. Gameplay domain authorities use `System`, because they own domain Stores, mediate mutations, and coordinate gameplay transactions.
2. Infrastructure facilities keep `Manager`, because persistence, boot, audio, and toast plumbing are not gameplay domain authorities and should remain visually distinct from Systems.
3. Runtime entity types use `Entry` as the single official name, because `Instance` is too generic and the current `Entry/Instance` dual wording weakens searchability.
4. Stores remain separate from Entries, because Stores own domain containers and save-section state while Entries represent live per-entity records held by those containers.
5. View remains an umbrella term for presentation-layer scenes, views, panels, rows, and components, not a forced class suffix for every UI script.
6. Snapshot and Service remain runtime archetypes with hard boundaries: Snapshots are read-only derived one-shot values, and Services are stateless pure helpers without saved mutable state.

## Design

The standard vocabulary is `Data -> Store -> System -> View`, with `Entry`, `Snapshot`, and `Service` filling the runtime supporting roles. `Data` is designer-authored definition content. `Store` is mutable runtime domain state. `System` is the gameplay authority that owns Stores and mediates writes. `View` is anything presenting or collecting input from the player.

The mutation path should read as `View -> System -> Store/Entry -> EventBus`. Views may read state exposed by Systems and Stores, but gameplay mutations flow through the owning System so save dirtiness, signals, cross-system transactions, and invariants stay centralized.

Manager remains valid for infrastructure. This is intentional, not a leftover: `SaveManager`, `GameManager`, `AudioManager`, and `ToastManager` are not renamed in the gameplay pass because they describe project/runtime services rather than domain state authorities.

Entry is not folded into Store. A Store may hold many Entries and can own the collection-level invariants, but an Entry owns per-entity identity, mutable record state, and entity-local serialization. Calling Entry a Store variant would hide the difference between a container and a record.

## Sketch (non-normative)

Proposed rename shape:

```text
global/autoloads/managers/run_manager.gd       -> global/autoloads/systems/run_system.gd
global/autoloads/managers/meta_manager.gd      -> global/autoloads/systems/meta_system.gd
global/autoloads/managers/knowledge_manager.gd -> global/autoloads/systems/knowledge_system.gd

RunManager       -> RunSystem
MetaManager      -> MetaSystem
KnowledgeManager -> KnowledgeSystem
```

Proposed Entry folder cleanup:

```text
common/gameplay/instance/ -> common/gameplay/entry/

ItemEntry stays ItemEntry
LotEntry stays LotEntry
CustomerEntry stays CustomerEntry
```

Suggested standard wording:

```text
Data: designer-authored immutable Resource definitions.
Entry: live runtime entity records with identity and per-entity mutable state.
Store: System-held mutable domain containers and save payload owners.
System: gameplay/domain authority that owns Stores, mediates mutations, coordinates transactions, emits gameplay events, and marks saves dirty.
View: presentation layer umbrella for scenes, views, components, rows, panels, and other UI blocks.
Snapshot: read-only derived value object computed once and discarded.
Service: stateless pure helper with no saved mutable state and no side effects.
Manager: infrastructure/global facility outside gameplay domain authority.
```

Suggested migration order:

1. Update standards and docs vocabulary first so review has a target language.
2. Rename gameplay autoload folder and class references from managers to systems.
3. Rename the runtime `instance` folder to `entry` and update script paths and preload references.
4. Update autoload names and project settings after call sites are ready.
5. Run parser/lint/tests after each high-blast-radius rename group, because autoload and script path mistakes tend to fail at load time.
6. Leave infrastructure Managers untouched unless a separate future infrastructure naming pass explicitly scopes them.

Suggested rule text for mutation mediation:

```text
Views, UI blocks, and display helpers never mutate an Entry or Store directly. Gameplay mutations flow through the owning System: View -> System.wrapper(...) -> Store/Entry mutator -> EventBus signal and save dirty mark when needed.
```

## Non-Goals

1. Do not rename infrastructure Managers in this pass.
2. Do not force every UI class to use a `View` suffix.
3. Do not merge Entries into Stores or rename Entry classes to Store classes.
4. Do not redesign gameplay behavior while doing the vocabulary refactor.

## Acceptance Criteria

1. Gameplay domain authorities use the System vocabulary consistently in code, docs, autoload names, and standards.
2. Infrastructure Managers remain visibly separate from gameplay Systems.
3. Entry is the only official runtime record archetype name, with no remaining standard-level Entry/Instance dual naming.
4. Store, Entry, Snapshot, and Service boundaries remain distinct and reviewable.
5. Existing save/load behavior and gameplay flows remain unchanged after the rename.
