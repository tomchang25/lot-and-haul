# Unlock Gating + Location Tier Review

## Goal

Give the economy a visible progression spine: premium auction locations and special lot kinds locked behind explicit, always-visible requirements, so cash and mastery buy _access_ to content rather than only efficiency. Today money's sole sink is attribute upgrades, which makes "why keep earning" feel hollow; a tiered ladder of locked auction houses with stated conditions answers it the way unlock gates answer it in Melvor-style progression.

## Requirements

1. A generic, data-driven requirement block usable by any gated content entry: an AND-combination of conditions drawn from cash license fee, category or super-category mastery rank, attribute level, and owned perk. Defined once so future gates (prestige unlocks, NPC reaction tiers) reuse the same format instead of inventing parallel ones.
2. Gates apply at two granularities: whole locations (new premium auction tiers — identical auction mechanics, richer lot pools, purely data-driven) and individual lot kinds within a location.
3. Locked content is always visible with its requirements spelled out, each condition showing met/unmet state — visibility is the point: the player must always be able to see what they are working toward. Locked entries are never hidden or vaguely teased.
4. Unlocking is a one-time license purchase, available once all non-cash conditions are met; the cash fee is consumed at purchase and the unlock is permanent, persisting in the save. Recurring cost stays with the existing travel/fuel economy — no entry fees.
5. Location data review: define a tier reference table (per-tier lot value band, lot count per visit, travel cost band, license/requirement band) and audit every existing location into the ladder, naming the content gaps the premium tiers need filled.

## Design

### Requirement block

A requirement block is a list of conditions that must all hold:

| Condition kind  | Semantics                                      | Consumed?                         |
| --------------- | ---------------------------------------------- | --------------------------------- |
| cash fee        | player pays N at unlock                        | yes — the only consumed condition |
| mastery rank    | rank in a named category or super-category ≥ N | no — threshold                    |
| attribute level | a named attribute ≥ N                          | no — threshold                    |
| perk            | player owns a named perk                       | no — threshold                    |

The unlock action lives on the location-select surface (hub phase). A gated entry whose threshold conditions are met and fee is affordable shows an enabled "buy license" action; otherwise each unmet condition is listed with its current vs. required value (e.g. "fine_art mastery 1/3"). Lot-kind gates appear the same way inside the location's detail view and, during a run, in lot browse as visibly locked entries that cannot be inspected or bid on.

### Tier ladder (initial values, all tunable)

| Tier | Identity                          | Lot anchor band     | Lots per visit   | Travel    | Gate (example band)                          |
| ---- | --------------------------------- | ------------------- | ---------------- | --------- | -------------------------------------------- |
| 1    | starter yards (current locations) | low                 | current          | cheap     | none                                         |
| 2    | regional auction houses           | mid, wider spread   | +1               | moderate  | $8,000 + one super-category mastery rank 2   |
| 3    | premium estate sales              | high, high variance | fewer but denser | expensive | $20,000 + mastery rank 3 + one attribute ≥ 5 |

Higher tiers sharpen the core gamble rather than flattening it: bigger anchor values and wider hidden-clue swings, not "strictly better loot" — the player buys access to higher stakes, and their grown attributes/mastery are what make those stakes readable.

Worked example: the player has $11,000, decorative mastery rank 2, Appraisal 4. Location select shows "Harbor Auction House — Tier 2" unlocked-purchasable (license $8,000, mastery met), and "Ashworth Estate — Tier 3" locked with "license $20,000 (have $11,000) · any mastery rank 3 (best: decorative 2) · any attribute 5 (best: Appraisal 4)". The player knows exactly what the next two purchases and the next mastery grind are for.

### Location audit

Classify every existing location into tier 1 or 2 against the reference table (value band, lot count, travel cost), adjusting outliers' data to fit their assigned band. The audit's output also names what tier 3 needs (count of locations, lot pool character per the Super-Category Diversity draft) — that authoring is follow-up content work, not part of this flow.

## Non-Goals

1. No new premium location content is authored here — the audit names the gaps; filling them is separate content work.
2. No recurring entry fees or per-visit costs beyond existing travel/fuel.
3. No prestige or NPC-reaction gating yet — the requirement block is built to be reused there, but those surfaces stay in their Draft entries.
4. No changes to auction, inspection, or lot-draw mechanics — premium tiers differ in data only.
5. No calendar/intel integration (announced one-shot premium auctions belong to the Calendar Special Events draft).

## Acceptance Criteria

1. Locked locations and lot kinds are visible on their select surfaces with each requirement condition shown as met/unmet against current values; nothing gated is ever hidden.
2. The license purchase is only available with all threshold conditions met and sufficient cash; the fee is deducted exactly once and the unlock survives save/load.
3. A gated lot kind cannot be inspected or bid on before unlock, but is visibly listed as locked during a run.
4. Location gates and lot-kind gates consume the identical requirement block format — adding a new condition kind requires no per-surface changes.
5. A tier reference table exists in the data documentation and every existing location carries a tier assignment whose data sits inside its tier's bands.
