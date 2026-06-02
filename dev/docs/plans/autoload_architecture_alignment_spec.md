# Autoload Architecture Alignment — Implementation Spec

Concrete, code-level steps for the design in `autoload_architecture_alignment.md`.
Four phases, each leaving the game runnable and committable on its own. The design
plan is the *why*; this is the *how*. Standard being satisfied:
`dev/standards/autoload_archetypes.md`.

Phase order matches the plan: (1) KnowledgeOwner, (2) single-call registration,
(3) SceneRouter split, (4) attribute-upgrade use-case. Phases 1→2 and 3, 4 are
independent enough to land separately; keep them as separate commits.

---

## Phase 1 — Extract `KnowledgeOwner`

**Goal:** the knowledge slice persists through an Owner, so `SaveManager` only ever
sees Owners. `KnowledgeManager` stops being its own save section.

**Move the manager into a folder** (mirrors `meta_manager/`):

- `global/autoload/knowledge_manager.gd` → `global/autoload/knowledge_manager/knowledge_manager.gd`
- New: `global/autoload/knowledge_manager/knowledge_owner.gd`
- Update the autoload path in `project.godot` (`KnowledgeManager=` line 31 currently
  points at a `.uid`; repoint the `.uid` target or switch to the new `res://` path)
  and move the `.gd.uid` sidecar with the script.

**New `knowledge_owner.gd`** — `class_name KnowledgeOwner extends RefCounted`. It
owns the three persistent fields, their serialization, and the no-save mutators.
Everything that *reasons about* knowledge stays on the Manager.

```
class_name KnowledgeOwner
extends RefCounted

var category_points: Dictionary = {}     # category_id (String) → int
var attribute_levels: Dictionary = {}    # attribute_id (String) → int
var unlocked_perks: Array[String] = []

# ── Mutators (no save) ──
func add_points(category_id: String, gain: int) -> void   # the write half of add_category_points
func set_attribute_level(attribute_id: String, level: int) -> void
func add_perk(perk_id: String) -> bool                    # returns false if already present

# ── Save section ──
func section_id() -> String:  return "knowledge"
func to_dict() -> Dictionary
func from_dict(data: Dictionary) -> void   # verbatim move of current L73–90, incl. the
                                           # skill_levels-discard and float→int coercion
```

Move the body of `to_dict`/`from_dict` from `knowledge_manager.gd:60–90` **unchanged**
— including the legacy `skill_levels` discard and the `attribute_levels` `float`
coercion. `section_id()` must stay `"knowledge"` so the on-disk format is byte-for-byte
the same and no schema bump is needed. The schema-1→2 migration in `save_manager.gd:81–89`
is untouched: it still relocates the three keys into the `"knowledge"` section, which the
Owner now consumes.

**`KnowledgeManager` changes:**

- Add `var _knowledge := KnowledgeOwner.new()` in `_ready()`; register it (see Phase 2)
  instead of `SaveManager.register_section(self)`.
- Delete `section_id`/`to_dict`/`from_dict` and the three field declarations
  (`category_points`, `attribute_levels`, `unlocked_perks`) — they now live on the Owner.
- Rewrite the write paths to route through the Owner, keeping the rank/gain math on the
  Manager:
  - `add_category_points()` keeps computing `gain` (L114–122), then calls
    `_knowledge.add_points(category.category_id, gain)`.
  - `unlock_perk()` keeps the dedupe intent but delegates the append to
    `_knowledge.add_perk(perk.perk_id)`; **drop the inner `SaveManager.save()`** (see note).
  - the attribute increment moves into the Phase 4 primitive.
- Read paths (`get_category_rank`, `get_attribute_value`, `has_perk`, `validate`, etc.)
  read `_knowledge.<field>` instead of the old local fields.
- `validate()` stays on the Manager (it reasons about the registry); it reads
  `_knowledge.unlocked_perks`.

> **Save-on-write note:** `unlock_perk` and the old `upgrade_attribute` each called
> `SaveManager.save()` inline. Per hard-rule 3 only the transaction's commit point saves.
> `unlock_perk` is a single-domain write — keep one save, but at the Manager method tail,
> not inside the Owner. The Owner never saves.

**Expose the upgrade cost** as a query for Phase 4 (replaces the private const):
`func attribute_upgrade_cost() -> int: return _ATTRIBUTE_UPGRADE_COST`.

**Verification (Phase 1):**

- Load a pre-existing `user://save.json` (both a schema-1 and a schema-2 file) and confirm
  `category_points` / `attribute_levels` / `unlocked_perks` survive a save→load round-trip
  unchanged. This is the one real risk in the whole plan — do not skip it.
- `python dev/tools/lint_standards.py --files <changed>`.
- Boot the game; open Knowledge Hub → Mastery / Attributes / Perks panels render.

---

## Phase 2 — Single-call Owner registration

**Goal:** a Manager registers its Owner list in one call; adding an Owner is one line.

**`save_manager.gd`** — add alongside `register_section`:

```
## Registers several section providers in order. Convenience over register_section.
func register_sections(sections: Array) -> void:
    for s: Object in sections:
        register_section(s)
```

**`meta_manager.gd:90–95`** — collapse the six lines to one, preserving order:

```
SaveManager.register_sections([_economy, _garage, _storage, _progress, _slot, _customers])
```

**`knowledge_manager.gd` `_ready()`** — register identically:

```
SaveManager.register_sections([_knowledge])
```

Order matters only for legacy flat-save dispatch (order-independent there) and for
deterministic section iteration; keep the existing economy→…→customers order so saves
diff cleanly.

**Verification:** boot, do one customer sale + one attribute upgrade, quit, reload —
state intact. Lint.

---

## Phase 3 — Split navigation into `SceneRouter`

**Goal:** the boot root holds only the boot sequence; all transitions move to a Router
with no persistent state.

**New autoload** `global/autoload/scene_router/scene_router.gd` (Router archetype) with
its own `scene_router.tscn` carrying the `@export var scenes: SceneRegistry` (move the
export off `game_manager.tscn`). Move into it, verbatim, from `game_manager.gd`:

- every `go_to_*()` method (L31–101),
- `go_to_day_summary()` + `consume_pending_day_summary()` + the `_pending_day_summary`
  field (L15–27) — this is the allowed ephemeral nav payload.

**`game_manager.gd`** keeps only `_ready()` (boot: `SaveManager.load()`, migrations,
validation, audit, first-scene hand-off). It no longer declares `scenes`; change the
audit line to read the Router's registry:

```
var scene_ok := RegistryAudit.check_scene_registry(SceneRouter.scenes)
```

**`project.godot`** — add `SceneRouter` **before** `GameManager` (GameManager `_ready`
reads `SceneRouter.scenes`). It has no other dependencies, so anywhere above GameManager
is fine; placing it immediately above keeps boot last.

**Call-site migration** — 65 references across ~22 production scripts. Mechanical
rename `GameManager.go_to_` → `SceneRouter.go_to_` (plus the two day-summary methods):

```
rg -l 'GameManager\.(go_to_|consume_pending_day_summary|go_to_day_summary)' game/ global/
```

Files hit (production only): `hub_scene`, `knowledge_hub`, `vehicle_hub`, `lot_browse_scene`,
`day_summary_scene`, `auction_scene`, `inspection_scene`, `location_select`,
`car_shop_scene`, `car_select_scene`, `storage_scene`, `customer_sell_scene`,
`attribute_panel`, `mastery_panel`, `perk_panel`, `location_entry`, `reveal_scene`,
`cargo_scene`, `run_review_scene`, plus the `meta_manager.gd:348` docstring reference.
Update `dev/docs/systems/autoloads.md` (the `GameManager` row + Hub Navigation section)
and any `meta/*.md` that names `GameManager.go_to_*`.

**Verification:** walk a full loop touching every transition — hub → auction → run loop
→ run_review → hub → storage → knowledge panels → vehicle → open shop → customer sell →
day summary → hub. No transition should error. Lint + scene-registry audit must pass at
boot.

---

## Phase 4 — Attribute-upgrade use-case

**Goal:** the one cross-Manager state-mutating transaction runs through a single
entry point that commits once and returns a structured outcome; the
`KnowledgeManager ↔ MetaManager` cycle is removed.

**Result value** `common/gameplay/upgrade_result.gd`:

```
class_name UpgradeResult
extends RefCounted
var ok: bool
var message: String          # "" on success; "not enough cash" / "cannot upgrade" on fail
static func success() -> UpgradeResult
static func failure(msg: String) -> UpgradeResult
```

**Use-case** `common/gameplay/upgrade_attribute_use_case.gd` — static, no instance, no
framework:

```
class_name UpgradeAttribute
extends Object

## Buys one level of [param attribute_id]. Sequences both Managers' public APIs and
## commits exactly once. Reaches no Owner directly.
static func run(attribute_id: String) -> UpgradeResult:
    if KnowledgeManager.get_attribute_by_id(attribute_id) == null:
        return UpgradeResult.failure("cannot upgrade")
    var cost := KnowledgeManager.attribute_upgrade_cost()
    if not MetaManager.cash >= cost:
        return UpgradeResult.failure("not enough cash")
    MetaManager.spend_cash(cost)              # no save
    KnowledgeManager.apply_attribute_upgrade(attribute_id)  # no save
    SaveManager.save()                        # single commit
    return UpgradeResult.success()
```

**`KnowledgeManager`** — replace `upgrade_attribute()` (L177–189) with a **no-save**
primitive the use-case composes:

```
## No-save: increments the stored level by one. Caller commits.
func apply_attribute_upgrade(attribute_id: String) -> void:
    var attr := get_attribute_by_id(attribute_id)
    var current := _knowledge.attribute_levels.get(attribute_id, attr.starting_value)
    _knowledge.set_attribute_level(attribute_id, current + 1)
```

Delete the `MetaManager.spend_cash` call and the inline `SaveManager.save()` from
KnowledgeManager — that removes the knowledge→meta edge. `MetaManager.spend_cash`
(L104) stays; its only remaining caller is the use-case. The meta→knowledge edge
(`resolve_customer_sale` → `add_category_points`, L247) is the single allowed
unidirectional call and stays as-is.

**Call site** `attribute_panel.gd:45–49`:

```
func _on_upgrade_pressed(attr: AttributeData) -> void:
    var result := UpgradeAttribute.run(attr.attribute_id)
    if not result.ok:
        # surface result.message ("not enough cash" vs "cannot upgrade")
        return
    _rebuild_all()
```

Also drop the duplicated `const UPGRADE_COST := 1000` (L5) and read
`KnowledgeManager.attribute_upgrade_cost()` where the row affordability is computed
(L40), so the cost has one home.

**Verification:** upgrade with sufficient cash (level +1, cash −1000, persists);
attempt with insufficient cash (rejected, `message == "not enough cash"`, no state
change); confirm `KnowledgeManager` no longer references `MetaManager` except nothing,
and `MetaManager` references `KnowledgeManager` only in `resolve_customer_sale` /
`research_item`. Lint.

---

## Acceptance (maps to the plan's criteria)

1. `grep -n register_section` shows only Owners registered; `KnowledgeManager` is not a
   section. Old saves load unchanged. *(Phase 1)*
2. Both Managers register via one `register_sections([...])` call. *(Phase 2)*
3. `game_manager.gd` exposes no `go_to_*`; all transitions go through `SceneRouter`,
   which holds only the ephemeral day-summary payload. *(Phase 3)*
4. Attribute upgrade runs through `UpgradeAttribute.run` (one commit, structured result);
   `KnowledgeManager` no longer calls `MetaManager`; the cycle is gone. *(Phase 4)*
5. Every autoload resolves to exactly one archetype, and a full day cycle behaves
   identically. *(verified at the end of Phase 3 and Phase 4)*

## Out of scope (from the plan's Non-Goals)

No aggregate save section, no `MetaManager` rename, no general use-case framework, no
event-routed transactions, no gameplay/tunable/schema changes. Structure only.
