# Manager Decoupling & Store Exposure

Break the MetaManager ↔ KnowledgeManager dependency cycle, replace the private-field access in run resolution with a value-object handoff, and eliminate proxy-getter boilerplate by exposing stores as getter-only properties on their owning managers. Three independent phases; each ships and merges on its own.

## Why now

The manager layer is the backbone of every new feature — customer evolution, garage sale, vehicle restoration all route through MetaManager and RunManager. The circular dependency between Meta and Knowledge makes both untestable in isolation, and every new cross-domain feature risks adding another reverse edge. The `resolve_current_run` private-field access undermines RunManager's encapsulation contract and will silently break if RunStore's internal shape changes. The proxy-getter tax (35+ pass-through properties across two managers) means every new store field costs two files instead of one, with no real protection gain.

Fixing these now — before the next feature wave — keeps the cost low (small blast radius, no new systems depending on the current wiring) and establishes the conventions that future features follow.

## Phase 1 — Break the dependency cycle

Move the `upgrade_attribute` transaction from KnowledgeManager into MetaManager (it's a cross-domain transaction: spend cash + raise attribute). KnowledgeManager keeps only a pure domain operation `raise_attribute_level(attr)` that mutates its own store without knowing cash exists.

Add three business-event signals to EventBus: `sale_resolved`, `item_repaired`, `item_restored`. MetaManager emits after its commit point; KnowledgeManager subscribes in `_ready()` and awards mastery XP from the callback. This replaces the three direct `KnowledgeManager.add_category_points()` calls in `resolve_customer_sale`, `repair_item`, and `restore_item`.

Strip the two `KnowledgeManager.add_category_points()` calls from `ResearchSlot.apply_repair` and `apply_restore`. The emit moves to MetaManager (the caller), and ResearchSlot becomes a true pure-math helper — no autoload references. `apply_restore` still needs the restoration attribute value; MetaManager passes it in as a parameter instead of ResearchSlot reaching for `KnowledgeManager.get_attribute_value("restoration")`.

After this phase: MetaManager has zero imports of KnowledgeManager. KnowledgeManager has zero imports of MetaManager. ResearchSlot has zero autoload references. The cycle is fully broken.

Acceptance criteria:

1. `MetaManager` never references `KnowledgeManager` by name (no direct call, no `KnowledgeManager.` anywhere in the file). The only remaining read — `get_attribute_value("investigation")` in `research_item` — is a read from a service, not a mutation dependency; move it to a local variable passed from the caller's context or accept it as a tolerated read-only query. If kept, document it as a one-way read with no cycle risk.
2. `KnowledgeManager` never references `MetaManager` by name.
3. `ResearchSlot` has no autoload references — all external values arrive as parameters.
4. `EventBus` defines exactly three new signals: `sale_resolved`, `item_repaired`, `item_restored`.
5. Mastery XP still accrues correctly for sell, repair, and restore actions (manual smoke test).

## Phase 2 — RunResult value object

Add a `RunResult` snapshot class (same archetype as `DaySummary`) in `common/gameplay/snapshot/`. RunManager builds it from `_run_store` via a new `take_run_result() -> RunResult` method, applying `auto_reveal_all_surface()` on cargo items before snapshotting. MetaManager's `resolve_current_run` calls `take_run_result()` instead of `RunManager._run_store`, consumes the result, then calls `RunManager.clear_run_state()`.

`_run_store` becomes truly private — no external code references it. The `resolve_run(record: RunStore)` signature changes to `resolve_run(result: RunResult)`.

If EventBus Phase 1 is already landed, emit `EventBus.run_resolved.emit(result)` at the end of `resolve_current_run` (add the signal to EventBus in this phase if not already present).

Acceptance criteria:

1. No code outside `run_manager.gd` references `RunStore` or `_run_store`.
2. `RunResult` is a snapshot (read-only value object, no mutators, no serialization).
3. Run resolution still correctly applies cash delta, registers cargo into storage, stashes pending-run economics, and clears run state (manual smoke test: complete a run → hub → day summary shows correct numbers).

## Phase 3 — Store exposure and proxy removal

Replace private store references with getter-only public properties on MetaManager and RunManager. Scenes read `MetaManager.economy.cash` instead of `MetaManager.cash`.

Store-layer changes: scalar fields remain bare public (value-copy on read, harmless). Collection fields get a getter property that returns `.duplicate()` for iteration stability — the protection moves from the manager proxy into the store itself. Document the convention: store fields are read-public, mutation goes through the owning manager only.

Manager-layer changes: replace `var _economy: EconomyStore` + 20 proxy properties with `var _economy: EconomyStore` + `var economy: EconomyStore: get: return _economy` (six lines for MetaManager, one line for RunManager). Delete all proxy properties.

Scene-layer changes: batch rename across ~20 scene files. `MetaManager.cash` → `MetaManager.economy.cash`, `MetaManager.storage_items` → `MetaManager.storage.storage_items`, `RunManager.won_items` → `RunManager.run.won_items`, etc. RunManager's getter returns null between runs, so scenes that read run state need a null guard — but the existing proxy pattern already returns defaults for null, so the scene-side guard is equivalent.

Also move `ONSITE_SELL_PRICE := 50` from `cargo_scene.gd` into `Economy` constants.

Acceptance criteria:

1. MetaManager and RunManager have zero proxy properties — all store reads go through the exposed store getter.
2. No scene or external file directly calls a store mutation method (enforced by convention + code review).
3. Collection getters on stores return `.duplicate()` with a docstring explaining iteration stability and shared-ref semantics.
4. All scenes compile and run without error after the rename (full run + hub smoke test).

## Open questions

- **RunManager null-state API for Phase 3**: when `_run_store` is null between runs, `RunManager.run` returns null. Scenes currently get safe defaults (0, empty array) from the proxy. Options: (a) scenes null-check before access, (b) RunManager exposes a static `EMPTY_RUN` sentinel with zero/empty defaults, (c) RunManager always holds a RunStore (cleared to defaults, never null). Leaning (a) — it's honest and the existing proxy defaults were hiding potential bugs anyway.
- **`research_item` reading `KnowledgeManager.get_attribute_value("investigation")`**: this is a one-way read query, not a mutation dependency. Tolerate it as a documented exception to the "Meta never references Knowledge" rule, or inject the value from the scene that calls `research_item`? Leaning tolerate — it's a pure read, no cycle risk, and injecting it from the scene pushes domain knowledge into UI.
