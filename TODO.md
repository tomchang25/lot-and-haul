# TODO

The single forward surface — open this and you see everything: open work _and_ brewing
ideas. Every forward item lives in **exactly one** section here (or, once it earns a file,
in `dev/docs/plans/`). There is deliberately **no "Done" tier** — done = delete the line;
its record lives in `CHANGELOG.md`.

> **The one rule (now about sections, not files):** the actionable tiers
> (`Plan` / `Chore` / `Bug`) are **one line each** — no paragraphs, no tables, no _why_.
> The moment an item needs real reasoning, it belongs in `## Draft` as its own `###`
> sub-section. When a Draft entry grows sub-structure, becomes actionable, or needs to be
> linked from elsewhere, it graduates to its own file in `dev/docs/plans/`.

Multi-step sequenced work and its dependency order live in `ROADMAP.md`, not here.

Actionable line format: `[Scope] one sentence — [ref plans/<x>.md if any]`

---

## Draft

Preliminary concepts — bigger than a one-liner, but a single `###` sub-section says
enough. Not necessarily actionable yet. One `###` heading per idea (nested under this
`## Draft` so the section stays intact). When an idea outgrows its sub-section / becomes
actionable / needs a stable link → move it into its own `dev/docs/plans/<x>.md`
(`Status: Exploring`) and delete it here. Stale and never grew → just delete it.

### Category Mastery ↔ Clue Integration

Mastery (category → super-category → rank) is retained as a progression signal (earned via `KnowledgeManager.add_category_points` on `REVEAL` / `SELL`) but currently has no mechanical effect on clue discovery. Idea: at certain ranks, inspection shows "N unrevealed surface clues remaining"; at higher ranks, the easiest surface clue may auto-reveal (no roll, no AP). Mastery does **not** affect DC or success rate — that is the attribute system. Thresholds TBD.

### Attribute Upgrades — Cost Scaling & Max Level

Attribute upgrades currently cost a flat $1000/level. Idea: cost scales with current level (linear or quadratic), or alternative growth paths (per-run rewards, daily training, mastery-gated upgrades). Once the upgrade curve is tuned, add a per-attribute max level / softcap. Designed after the base cash model is play-tested.

### Reputation + Scam Flow

Faction reputation system with scam-detection decision branches — builds on the customer system. Requires the customer system to be stable first.

### Expert Network (Appraisers)

Unresolved design: a network of appraiser NPCs the player can consult for better value estimates (beyond their own attributes). Pay-per-use or relationship-gated.

### Museum / Prestige

Prestige system where rare/verified items can be donated or displayed for reputation, unlocking content gates. Design decisions needed first: what does prestige unlock or affect (access tiers, price modifiers, cosmetics, pure achievement)? Is it per-super-category or global? Is the donation UI in storage or a separate scene? The entire path is blocked on deciding the prestige shape.

### Auction Modifier: All-Base-Layer Run

An auction modifier variant where every lot contains only base-layer (anchor) clues — no surface or hidden. Requires a general auction modifier system to exist first.

### Training Courses

Hub-based training resource: spend cash and a day slot to temporarily boost an attribute for the next run. Training button in hub, resource-like expiry model.

### Intel System / Pre-Run Tip-Offs

Pre-run intelligence on available lots — reveal clue counts, surface categories, or estimated value tiers before committing the trip. Waiting on `LocationIntel` resource design.

### NPC Depth Rolled Price

Full NPC knowledge-level system for rolled price; location-specific bidder personalities. Adds depth to auction encounters beyond the current flat NPC.

### Lot Pool Variety

Seasonal / rotating lot pools; one-shot special locations as events. Requires the location/auction system to be stable first.

### Director System

Autoload that manages demo state without modifying production scenes — injects fixed lot content, car assignment, and perks into RunRecord before each run. Uses signal hooks on auction/cargo scenes for forced-bid/block behavior. See `dev/docs/plans/demo_summary.md`.

### Dialog System

Linear dialog first (Uncle branching second). DialogManager overlay autoload with data-driven dialog. Shared by demo runs and eventual full game.

### Bank / Bankruptcy

Daily interest on cash reserves, game-over condition when debt threshold is crossed, optional player-initiated loans. Needs the day-slot economy to be stable first.

### Customer System Evolution

Weighted tag pools (calendar/event/progression-driven), regular customers with fixed profiles, quality tiers (budget vs. collector), selling-related perks. Builds on the current nightly customer system.

### Lot Location Unlock Gating

Perk or mastery rank or unlock fee (or some combination — e.g. a purchasable perk that grants access) to gate which lot kinds are available at which locations. Replaces the simpler "waiting on progression model" placeholder.

### Garage Sell

Sell individual items in a garage-style scene modelled on `game/run/auction/`. System placement unclear: merchant surface or standalone selling channel? Deferred until the customer sell flow is stable.

### Warehouse Variant Support

Hub surfaces different warehouse exteriors and lot counts per location variant. Requires the location system to define variants first.

### Perk Content Expansion

Additional perks beyond the current attribute-threshold triggers, with full acquisition wiring (content-granted, event-granted, etc.).

### Content Gates (Mastery Rank)

Use `get_mastery_rank()` directly to gate prestige unlocks, tier-locked auction houses, and NPC reaction tiers.

### Fuel Cost Pre-Run Preview

Surface `fuel_cost_per_day × travel_days` in the location selection cost card. Blocked on the location system's cost card.

### Vehicle Upgrades / Mods

Upgrade system for vehicles: bigger tank, reinforced cargo bay, etc.

### Vehicle Durability & Repair

Wear-and-tear system for vehicles affecting performance; repair cost and downtime.

### Unique Per-Car Perks

Each vehicle grants a unique gameplay modifier (e.g. "+1 action per lot", "ignores first bad item").

### Vehicle Sell-Back / Trade-In

Sell owned cars for partial value when upgrading, so trading up has a cost offset.

---

## Plan

Committed work, backed by a pre-plan file in `dev/docs/plans/` (`Status: Committed`).

_None yet._

---

## Chore

One-line, no reasoning, no backing doc.

- [data] Delete ghost `data/tres/commodities/` — `CommodityData` is removed.
- [tune] Attribute costs, customer generation weighting, perk balance — won't stabilise until earlier systems impose real constraints.
- [ui] Replace placeholder fade with per-location arrival visuals.
- [refactor] Collapse the duplicated rank-threshold ladder in `get_category_rank()` to loop over `RANK_THRESHOLDS`

---

## Bug

One-line defect to fix.

_None yet._
