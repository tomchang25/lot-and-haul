# Phase 9 — Merchant System Redesign (PR Staging)

## Purpose

Ordered commit plan for delivering the Phase 9 implementation spec as a single PR. Each stage is exactly one commit; the PR is the sum of all stages. Hand this to an implementation agent together with the impl spec — the spec says *what*, this says *in what order*. No implementation detail here by design.

Follow `phase_9_merchant_system_pre_plan.md` and `phase_9_merchant_system_impl_spec.md` for all scope, behavior, and design detail.

## Sequencing Principle

**Additive first, remove last.** The new customer selling system is built and made fully playable while the legacy merchant/special-order stack still compiles; the legacy stack is deleted only in the final stage. Every commit must leave the project compiling and the game launchable, with run-phase cargo behavior unchanged until intentionally touched.

## Commit Gate

**The implementing agent must not commit anything on its own.** At the end of each stage it stops and waits for the user to verify that stage. Only after the user confirms does the agent commit, then proceed to the next stage. The agent does not chain stages or batch commits without explicit per-stage sign-off.

## Stages

### Stage 1 — Extract shared packing module
- **Scope:** Move grid placement / rotation / occupancy core out of the run-phase cargo scene into a shared component; cargo scene consumes it. Weight, trailer slots, and run summary stay in cargo.
- **Depends on:** —
- **Green state:** Pure refactor. Run-phase cargo behaves identically; no customer code yet.

### Stage 2 — Customer runtime model + generation
- **Scope:** Customer value object in `common/gameplay` (demand tags + grid dims, with save round-trip) plus RNG-injectable 50/50 match-biased generation. Not wired to any flow.
- **Depends on:** —
- **Green state:** New type compiles and is unit-testable in isolation; no in-game behavior change.

### Stage 3 — Pure sell-math helper
- **Scope:** Fit intersection, dice-pool sizing, sum→multiplier banding (committed constants), and car-total / contribution pricing. Pure functions.
- **Depends on:** Stage 2 (operates over customer + item runtime types).
- **Green state:** Helper compiles and is unit-testable; not yet wired.

### Stage 4 — Meta-layer customer lifecycle + persistence
- **Scope:** Generate customers on day advance, persist them through the save layer, and expose a resolve-sale entry that commits cash/storage by delegating to the sell-math helper. Coexists with the legacy selling path.
- **Depends on:** Stages 2, 3.
- **Green state:** Customer state generates, persists, and round-trips through save; legacy merchant selling still works.

### Stage 5 — Customer-sell scene + routing
- **Scope:** New sell scene consuming the shared packing module, the sell-math helper, and the meta-layer API; full Conservative/Aggressive flow with dice UI and confirm/decline. Register the scene and point the hub selling entry at it.
- **Depends on:** Stages 1, 4.
- **Green state:** New selling loop fully playable end to end. Legacy merchant scenes still exist but are no longer the hub entry point.

### Stage 6 — Remove legacy selling stack + save migration
- **Scope:** Delete merchant/special-order scripts, scenes, and `.tres`; remove the merchant registry from boot and the documented autoload order; strip merchant routing and the old sell path from scene routing and the meta layer; drop and migrate legacy merchant/order keys on save load; remove merchant data directories.
- **Depends on:** Stage 5 (new path must be live first).
- **Green state:** No selling path exists outside the customer system; pre-Phase-9 saves load with legacy keys dropped. Completes the impl spec.

## Notes

- The user verifies each stage before the agent commits — see Commit Gate above. Suggested verification handles to make that easy: Stages 2–3 unit tests; Stage 4 a save round-trip; Stage 5 a manual play-through of the sell loop; Stage 6 loading a pre-Phase-9 save.
- Stage 6 is a breaking change (save format change + removed systems); flag it as such when it is committed.
- If a stage proves too large to review, the natural further splits are Stage 5 (scene scaffold vs. sell-decision/dice) and Stage 6 (code removal vs. save migration).
