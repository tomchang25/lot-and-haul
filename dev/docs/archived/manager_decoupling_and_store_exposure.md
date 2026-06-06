# Manager Decoupling & Store Exposure

Break the MetaManager ↔ KnowledgeManager dependency cycle, replace the private-field access in run resolution with a value-object handoff, and eliminate proxy-getter boilerplate by exposing stores as getter-only properties on their owning managers. Three independent phases; each ships and merges on its own.

## Why now

The manager layer is the backbone of every new feature — customer evolution, garage sale, vehicle restoration all route through MetaManager and RunManager. The circular dependency between Meta and Knowledge makes both untestable in isolation, and every new cross-domain feature risks adding another reverse edge. The `resolve_current_run` private-field access undermines RunManager's encapsulation contract and will silently break if RunStore's internal shape changes. The proxy-getter tax (35+ pass-through properties across two managers) means every new store field costs two files instead of one, with no real protection gain.

Fixing these now — before the next feature wave — keeps the cost low (small blast radius, no new systems depending on the current wiring) and establishes the conventions that future features follow.

## Phase 1 — Break the dependency cycle - Finished

Move the `upgrade_attribute` transaction from KnowledgeManager into MetaManager (it's a cross-domain transaction: spend cash + raise attribute). KnowledgeManager keeps only a pure domain operation `raise_attribute_level(attr)` that mutates its own store without knowing cash exists.

Add three business-event signals to EventBus: `sale_resolved`, `item_repaired`, `item_restored`. MetaManager emits after its commit point; KnowledgeManager subscribes in `_ready()` and awards mastery XP from the callback. This replaces the three direct `KnowledgeManager.add_category_points()` calls in `resolve_customer_sale`, `repair_item`, and `restore_item`.

Strip the two `KnowledgeManager.add_category_points()` calls from `ResearchSlot.apply_repair` and `apply_restore`. The emit moves to MetaManager (the caller), and ResearchSlot becomes a true pure-math helper — no autoload references. `apply_restore` still needs the restoration attribute value; MetaManager passes it in as a parameter instead of ResearchSlot reaching for `KnowledgeManager.get_attribute_value("restoration")`.

After this phase: MetaManager has zero imports of KnowledgeManager. KnowledgeManager has zero imports of MetaManager. ResearchSlot has zero autoload references. The cycle is fully broken.

## Phase 2 — RunResult value object - Finished

Add a `RunResult` snapshot class (same archetype as `DaySummary`) in `common/gameplay/snapshot/`. RunManager builds it from `_run_store` via a new `take_run_result() -> RunResult` method, applying `auto_reveal_all_surface()` on cargo items before snapshotting. MetaManager's `resolve_current_run` calls `take_run_result()` instead of `RunManager._run_store`, consumes the result, then calls `RunManager.clear_run_state()`.

`_run_store` becomes truly private — no external code references it. The `resolve_run(record: RunStore)` signature changes to `resolve_run(result: RunResult)`.

If EventBus Phase 1 is already landed, emit `EventBus.run_resolved.emit(result)` at the end of `resolve_current_run` (add the signal to EventBus in this phase if not already present).

## Phase 3 — Store exposure and proxy removal

Managers stop acting as middlemen for reads. Scenes go directly to the store: `MetaManager.economy.cash` instead of `MetaManager.cash`. Stores protect their own fields with getter-only properties (language-enforced, not convention).

Store-layer changes: every field gets a private backing variable and a getter-only property. Scalars use `var cash: int: get: return _cash` — GDScript enforces no external write (no setter = runtime error on assignment). Collection fields return `.duplicate()` in the getter for iteration stability. Mutation methods stay internal, called only by the owning manager. Document the convention at the top of each store: "Fields are read-public via getters. Mutation goes through the owning Manager only."

Manager-layer changes: store references become plain public fields (`var economy: EconomyStore`). No getter-only wrapper needed — reassigning the entire store object is not a realistic accident. Delete all proxy properties (20+ on MetaManager, 15+ on RunManager).

Scene-layer changes: batch rename across ~20 scene files. `MetaManager.cash` → `MetaManager.economy.cash`, `MetaManager.storage_items` → `MetaManager.storage.storage_items`, `RunManager.won_items` → `RunManager.run.won_items`, etc. RunManager's store is null between runs, so scenes that read run state need a null guard — but run-phase scenes only exist while a run is active, so the guard is a startup assert, not a per-access check.

Also move `ONSITE_SELL_PRICE := 50` from `cargo_scene.gd` into `Economy` constants.

Acceptance criteria:

1. MetaManager and RunManager have zero proxy properties — all store reads go through the public store reference.
2. Every store field uses private backing + getter-only property (no external setter).
3. Collection getters on stores return `.duplicate()` with a docstring explaining iteration stability and shared-ref semantics.
4. No scene or external file directly calls a store mutation method (enforced by convention + code review).
5. All scenes compile and run without error after the rename (full run + hub smoke test).

## Open questions

- **RunManager null-state API for Phase 3** (resolved): `RunManager.run` is null between runs. Run-phase scenes assert non-null in `_ready()` — they only exist while a run is active, so null means a bug. Hub-phase scenes never read RunManager's store. No sentinel or always-hold needed.
- **`research_item` reading `KnowledgeManager.get_attribute_value("investigation")`**: this is a one-way read query, not a mutation dependency. Tolerate it as a documented exception to the "Meta never references Knowledge" rule, or inject the value from the scene that calls `research_item`? Leaning tolerate — it's a pure read, no cycle risk, and injecting it from the scene pushes domain knowledge into UI.
