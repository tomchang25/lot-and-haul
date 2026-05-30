# Lot & Haul — Roadmap

Forward-only: the active flow, its dependency order, and decided-but-deferred work. This
is a decision log and dependency map, not an implementation spec.

Shipped work is **cut from here** and recorded in `CHANGELOG.md` — there is no "completed"
table. Design facts (value hierarchy, core-loop principles) live in `dev/docs/systems/` and
`dev/docs/vision/`, not here. Concept-level explorations live in `dev/docs/plans/`
(`Status: Exploring`) and are linked below.

---

## Active

### Time-Slot Day Structure + Storage AP Economy

Replace the passive day-counter hub with a three-slot day model (morning / afternoon /
evening) so each day is an explicit resource-allocation decision, and convert storage
actions from day-timers to an AP economy. Core tension: an auction eats two slots, leaving
one for light storage or a small evening shop; skipping the auction frees all three for
heavy maintenance or a full shop day.

Wiring already present: `Customer.generate_for_night(rng, storage_items, count, …)` takes
an explicit `count`; the slot economy passes a slot-derived count instead of the default
roll. Open questions (shared vs. separate AP pool, pool sizing, per-slot customer curves)
and full design: `dev/docs/plans/time_slot_economy.md`.
