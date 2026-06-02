# Meta Domain Decomposition and Load-Time Integrity Ownership

## Goal

Decompose the meta progression system's single state bag into per-domain state owners that each own both their live fields and their own serialization, so the behavioral boundary and the persistence boundary are one boundary. This removes the anemic save-adapter layer that mirrors the meta system's fields, and halts the god-object growth where one system holds every domain's state. In the same pass, relocate save-data referential-integrity checks out of the content registries and into each owner's load path, returning content registries to pure load-and-query.

## Requirements

1. Each meta domain (economy, garage, storage, slot flow, calendar/progress, nightly customers) owns its own persistent fields and its own save payload conversion — the domain that mutates a field is the domain that serializes it, so there is one boundary and no mirror layer.
2. Domain owners are plain owned objects held by the meta progression system, **not** new global singletons or autoloads. This is the explicit guardrail: decomposition must not regress into "one autoload per domain." Global reachability and whole-session lifetime are the only things that justify an autoload, and a domain owner has neither — it is reached only through its holder.
3. The meta progression system stays the single transaction coordinator: cross-domain operations (day end, run resolution, customer sale) remain in one place and sequence calls into the owners they touch, because atomicity across domains must keep a single home even after state is distributed.
4. The persistence coordinator iterates registered owners to write and read sections and gains no per-domain knowledge; the former standalone save-section adapter objects are retired once each domain owns its serialization.
5. Save-data referential integrity (a persisted id resolving to existing content) moves to the owning domain's load path; content registries stop reaching into live state and reduce to load + query, so the dependency arrow points owner → content — the direction the owner already depends in.
6. Per-domain load sanitizes rather than asserts: an unresolved persisted id is dropped with a warning, not a hard error, so an older save loads resiliently. A single sanitize-on-load mechanism replaces the current duplicated repair-then-report pair.

## Design

### Layering

Three layers, each fact in exactly one:

- Record value objects own record-level shape and serialization (unchanged).
- Domain owners own a domain's live fields, the operations over them, and the domain's save payload.
- The meta progression system holds the domain owners, coordinates cross-domain transactions, and exposes reads and actions to scenes.
- The persistence coordinator owns file IO, schema handling, and provider dispatch only.

### What a domain owner is (and is not)

A domain owner is a plain object instantiated and held by the meta progression system. It is not registered globally, not an autoload, and not reachable except through its holder. It exposes its domain fields, the operations that mutate them, a section id, and payload conversion both ways. Adding a future domain means adding one owned object and registering it as a save provider — never a new global. The meta progression system becomes a façade plus transaction coordinator: it forwards single-domain reads and actions to the owning object, and it implements multi-domain transactions by calling several owners in sequence.

### Domain ownership map

| Domain | Owns |
| --- | --- |
| Economy | cash |
| Garage | owned vehicles, active vehicle |
| Storage | stored item records, next entry id |
| Slot flow | current slot, storage AP, selling-slot commitment, pending run economics |
| Progress | calendar day, sampled available locations |
| Customers | nightly customers, today's sale ledger |

Knowledge progression already owns its own state and serialization; it is the reference shape for this refactor and is otherwise unchanged.

### Cross-domain transactions stay singular

Day-end folds economy, slot, customers, and pending-run state together; run resolution touches economy, storage, and slot; a customer sale touches storage, economy, customers, and knowledge. These remain single methods on the coordinator that call into the relevant owners in order. Splitting state ownership does not split transaction ownership — the win is removing the mirror layer and slimming the held state, not scattering the sequencing logic.

### Integrity ownership

Today a content registry validates that persisted ids resolve by reaching into live state — a backward dependency, and the reason a new persisting domain forces edits into a registry. After the refactor:

- Content well-formedness stays in the authoring-time validation pipeline; runtime content registries drop their content-correctness checks beyond a load-succeeded sanity guard.
- Each domain owner, on load, checks its own persisted ids against the relevant content registry and drops unresolved ones with a warning. The check runs where the owner already depends on content, so the arrow is owner → content.
- The previous pattern of repairing in one pass and re-reporting in another collapses into the single sanitize-on-load step; the second pass was effectively dead after the first.

### Ordering

Incremental, lowest-coupling first. Knowledge is already in target shape and acts as the template. Economy and garage move next (smallest field sets, least entangled). Storage, slot, progress, and customers move last because day advancement and sale resolution thread through them. Each domain's live-state references are repointed at its owner before the next domain moves, so the codebase never holds two owners for one field.

## Non-Goals

1. No new autoloads or global state service for any domain owner — the decomposition is explicitly into owned objects, not singletons.
2. No gameplay rule changes: economy, slot rules, customer generation, storage actions, day advancement, and vehicle purchase behave identically.
3. No save-schema redesign beyond moving serialization onto owners; section ids and payload shapes are preserved.
4. No cross-section (owner-to-owner) post-load integrity pass — each domain's integrity depends only on content, so a per-owner load check suffices; a coordinator-level post-load pass is deferred until a real cross-owner reference exists.
5. No mid-run persistence for the active run.

## Acceptance Criteria

1. Each listed domain owns its own fields and its own save payload; no separate adapter object mirrors those fields.
2. No domain owner is a global singleton or autoload; every one is reached only through the meta progression system.
3. The persistence coordinator holds no per-domain field knowledge and writes the same set of sections as before.
4. Loading existing saves (legacy flat, prior sectioned, and current) restores every domain's state into equivalent live state, with unresolved persisted ids dropped and warned rather than aborting the load.
5. Content registries perform load and query only; no registry reads live gameplay state, and referential checks live on the owners.
6. Cross-domain transactions (day end, run resolution, customer sale) remain single coordinated operations and produce outcomes identical to before.
7. Scenes display the same values and invoke the same actions as before.
