# Autoload Architecture Alignment

## Goal

Bring the project's globals into line with the Autoload & Domain Archetypes
standard, so every global holds exactly one role and persistence flows uniformly
through Owners. This closes the two real inconsistencies left after the meta
decomposition: the knowledge domain persists through its Manager instead of an
Owner, and the boot root also owns scene navigation.

## Requirements

1. The knowledge domain must persist through a dedicated Owner, like every other
   domain, so the persistence layer only ever registers Owners — today the
   knowledge autoload doubles as its own save section, the single place the
   "Owner is the only save section" rule is broken. The new Owner gets the same
   treatment the economy Owner already has: it holds the persistent fields, their
   serialization (including the legacy skill-levels discard), the domain
   invariants, and the mutators; the knowledge Manager keeps registry loading,
   mastery rules, queries, and validation, and routes its writes through the
   Owner's mutators.

2. Owner registration must be a single uniform call — a Manager registers the list
   of Owners it holds — replacing the per-Owner registration lines, so adding or
   removing an Owner is a one-line change and both domain Managers register
   identically.

3. Scene navigation must move out of the boot root into a dedicated navigation
   service. The boot root keeps only the boot sequence (load, migrations,
   validation, audit, first-scene hand-off) and holds no transition methods; the
   navigation service holds only transitions and short-lived nav payloads, no
   persistent state.

> **Dropped:** the original Requirement 4 (extract the attribute-upgrade purchase
> into a use-case to remove the knowledge↔meta Manager cycle) is cut. The Manager
> tier is now treated as a public API surface where cohesive cross-Manager calls
> are accepted, so the cycle is allowed by design — see the amended Hard Rule 4 in
> `dev/standards/autoload_archetypes.md`. The two boundaries that still hold are
> unchanged: Stores never reach outward (Rule 2), and a transaction commits exactly
> once (Rule 3) — both already satisfied by today's `spend_cash`-without-save path.

## Design

Target roles, by the standard:

- **Boot root** — boot sequence only. Loses every navigation method.
- **Navigation service** — every scene transition plus the short-lived hand-off
  payload that currently rides on the boot root. No persistent state, not a save
  provider.
- **Persistence coordinator** — unchanged in responsibility; gains a convenience
  to register a list of providers in one call. Still the only file-IO system, and
  its provider list becomes homogeneous: every entry is an Owner.
- **Knowledge Manager** — stays the domain authority: loads the perk/attribute
  registries, computes mastery, answers queries, validates referential integrity.
  It no longer serializes itself; it holds a knowledge Owner and registers it.
- **Knowledge Owner** — the persistent knowledge slice (mastery points, attribute
  levels, unlocked perks) with its section payload and mutators. Split line: state
  + serialization + invariants + mutators live here; everything that *reasons about*
  knowledge (registry loading, rank math, queries, validation) stays on the
  Manager and calls the Owner's mutators. This mirrors the economy slice exactly —
  it is the same give-the-Owner-behavior pattern, not a bare field move.
- **Meta Manager** — unchanged in this pass. It keeps its in-domain transactions
  (run resolution, day end, customer sale, vehicle purchase, slot actions) as
  public methods, because each is cohesive to the hub loop and touches only its own
  Owners (plus a single allowed, unidirectional call into the knowledge Manager for
  the sale reward, which stays).

The knowledge↔meta cross-Manager spend (attribute upgrade) stays where it is: the
knowledge Manager calls `MetaManager.spend_cash` (a no-save primitive) and commits
once at its own end. No use-case extraction — the Manager tier may call across
itself freely; only Store-inward and single-commit discipline are enforced.

Suggested order, each step leaving the game runnable:

1. Extract the knowledge Owner (Requirement 1) and prove the "every save provider
   is an Owner" rule on a real second domain.
2. Collapse Owner registration to the single-call convention (Requirement 2) on
   both domain Managers.
3. Split navigation out of the boot root (Requirement 3).

The standard is the durable artifact; this plan is the one-time alignment. The
cosmetic rename of the meta domain Manager is deliberately excluded (see
Non-Goals) so rename churn never mixes into an ownership change.

## Non-Goals

1. Do not nest the domain Owners under a single aggregate save section — flat
   per-Owner sections stay, the save format is unchanged, no schema bump or
   migration. Flat is simpler and the decomposition is real.
2. Do not rename the meta domain Manager — that is cosmetic, high-churn, and
   deferred; the standard generalizes the name without forcing existing renames.
3. Do not build a general use-case framework, factory, or per-action file
   scaffolding. Cross-Manager transactions stay as methods on whichever Manager
   owns the flow, calling the other Managers' public APIs directly.
6. Do not chase Manager↔Manager decoupling. The Manager tier is a public API
   surface; cohesive cross-calls are accepted spaghetti. The discipline lives one
   layer down: Stores stay inward-only and each transaction commits once.
4. Do not reroute transactional flows through events — events stay for
   non-transactional side effects only, because a flow needing a single save commit
   cannot guarantee it through events.
5. Do not change gameplay rules, tunables (AP thresholds, customer counts, slot
   numbers), or the save schema. Structure only.

## Acceptance Criteria

1. The persistence coordinator registers only Owners; no Manager or other autoload
   is itself a save section; existing save files still load unchanged.
2. Both domain Managers register their Owners through the same single call; adding
   an Owner is a one-line change.
3. The boot root exposes no navigation methods; all scene transitions go through
   the navigation service, which holds no persistent state.
4. Every autoload resolves to exactly one archetype on the standard's checklist,
   and a full day cycle (auction → run resolution → storage actions → open shop →
   customer sales → day end → summary) behaves identically to before.
