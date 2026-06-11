# ItemEntry Layer Split & Manager-Mediated Mutations

## Goal

Split the item instance into clean layers — data + price logic vs presentation — and route all mutations of it through its owning Manager, so the instance follows the same discipline as Stores. Today the item instance mixes price math, display formatting, serialization, clue mechanics, and factory logic in one type, run-phase scenes mutate it directly, and it reaches into the knowledge system on its own — which blocks any future mid-run persistence and leaves the Entry/Instance archetype without a settled contract.

## Requirements

1. The item instance keeps only: identity and mutable state, the full price pipeline, gameplay queries (demand tags, weight, shape, reveal/verification state), serialization, and factory creation. Mutators stay on the instance as invariant-guarding methods — the instance remains an Entry/Instance archetype, not a passive data bag — but they become Manager-only surface.
2. All presentation concerns move out of the instance into a display helper on the UI side of the project: name composition from revealed naming entries, every formatted text string, every color decision, and column-sort key extraction. The sort-key logic is coupled to a UI column enumeration today, which is exactly why the helper lives UI-side: shared gameplay code must not depend on UI types.
3. Scenes never mutate an item instance directly. Each mutation goes through a thin wrapper on the Manager that owns the instance's current container — the run-phase manager while the item is in a run, the meta/storage manager while it is in storage — mirroring how Store mutations already work. Ownership decides the mediator because that is the manager that would also own any future persistence of that mutation.
4. The instance stops calling the knowledge system. XP awards for reveal-type actions become notifications: after a successful mediated mutation, the mediating Manager emits an event on the event bus and the knowledge system subscribes and awards XP. This follows the existing cross-manager convention — the mutation is correct whether or not XP lands, so it must not be a direct call from inside the instance.
5. The Entry/Instance archetype decision becomes a written standard: a new runtime-type archetype standard under the standards folder records the four archetypes and the mutation-mediation rule ("Entries keep invariant-guarding mutators; only the owning Manager calls them; scenes go through Manager wrappers"), and the project instructions' conventions section is updated to point to it. This refactor is the reference implementation of that rule.
6. Serialization stays an isolated layer of the instance, touched by nothing else in this split — the queued pool-based generation work will replace registry-id lookup with stored clue lists, and it must be able to do so by touching only that layer.

## Design

Layer map for the current instance, by destination:

| Concern                 | Examples (behavioral)                                                                                                                    | Destination                    |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ |
| State                   | unveiled flag, condition, revealed clue set, research progress, persistent id, estimate-center offset                                    | stays on instance              |
| Derived state           | verification status, inspection ratio                                                                                                    | stays on instance              |
| Price pipeline          | resolved price view (range/exact/point), appraised value, verified value, condition multiplier, full-true debug value, NPC estimate roll | stays on instance              |
| Gameplay queries        | demand tags, weight, cargo shape/cells, "has clues left to inspect"                                                                      | stays on instance              |
| Mutators                | unveil, clue attempt, research advance, surface auto-reveal, hidden reveal, storage migration                                            | stay on instance, Manager-only |
| Factory + serialization | creation roll, save/load round-trip incl. legacy-key migrations                                                                          | stays on instance              |
| Presentation            | display-name composition, all formatted texts, all colors, unknown-masking ("???"), rarity names, column sort keys                       | UI-side display helper         |

Mediation pattern, traced for one mutation: a run-phase scene asks the run manager to attempt a clue on an entry; the manager calls the entry's mutator, which guards its invariants (no duplicate reveals, roll math unchanged); on success the manager emits a reveal event carrying the category and rarity context; the knowledge system hears it and awards XP. The scene's view of success or failure is the wrapper's return value — identical information to today.

Veil-masking is presentation: the instance exposes its veiled state as data, and the display helper decides that veiled means "???" texts and muted colors. The price pipeline keeps its own veil handling (a veiled item resolves to an unknown price view) because that is value semantics, not formatting.

System-level pre-unveils (lot generation, migrations) that set the unveiled flag without the player-triggered reveal flow remain legitimate direct state writes by the owning systems — the mediation rule governs scenes, not the Managers and pipelines that own the data.

## Non-Goals

1. No change to any price formula, roll formula, XP amount, or player-visible behavior — this is a pure structural refactor.
2. No migration of other Entry types (lot, customer) to the new standard in this refactor; they follow later, individually, under the written standard.
3. No mid-run persistence or save-on-inspect — this refactor only removes the blocker.
4. No serialization format change — clue-list storage for generated items belongs to the pool-based generation work.

## Acceptance Criteria

1. Behavior is identical before and after: same prices, same ranges, same names, same colors, same sort orders, same XP awards in the same situations.
2. No scene mutates an item instance directly; every mutation path goes through an owning-Manager wrapper, and reveal-type XP arrives via an event-bus notification instead of a call from inside the instance.
3. Shared gameplay code no longer references any UI type; the display helper owns all formatting and the UI column coupling.
4. Save/load round-trips unchanged, including all legacy-key migrations and stale-clue stripping.
5. The runtime-type archetype standard exists, records the mutation-mediation rule, and the project instructions point to it.
