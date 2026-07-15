# TODO

The single forward surface — open this and you see everything: open work _and_ brewing ideas. Every forward item lives in **exactly one** section here (or, once it earns a file, in `dev/docs/plans/`). There is deliberately **no "Done" tier** — done = delete the line; its record lives in `CHANGELOG.md`.

> **The one rule (now about sections, not files):** the actionable tiers (`Plan` / `Chore` / `Bug`) are **one line each** — no paragraphs, no tables, no _why_. The moment an item needs real reasoning, it belongs in `## Draft` as its own `###` sub-section. When a Draft entry grows sub-structure, becomes actionable, or needs to be linked from elsewhere, it graduates to its own file in `dev/docs/plans/`.
>
> Within `## Draft`, no `####` headings or `**label:**` bold-label patterns — use plain-text labels (em-dash, colon) and lists for sub-structure.
>
> **Tag format:** the `[Scope]` tag in actionable lines is **snake_case** — short lowercase identifier, no spaces, no parens, no mixed case (e.g. `[customer_sell]`, `[bugfix]`).

In-flight and ready-to-implement work lives in `## Active` — promoted from `## Plan` when building starts or the plan is ready to build; more than one entry is fine. The phase-by-phase detail and ordering stay in the linked `dev/docs/plans/` file, never churned into this list.

Actionable line format: `[Scope] one sentence — [ref plans/<x>.md if any]`

---

## Draft

Preliminary concepts — bigger than a one-liner, but a single `###` sub-section says enough. Not necessarily actionable yet. One `###` heading per idea (nested under this `## Draft` so the section stays intact). When an idea outgrows its sub-section / becomes actionable / needs a stable link → move it into its own `dev/docs/plans/<x>.md` (`Status: Exploring`) and delete it here. Stale and never grew → just delete it.

### 0.2.0 Milestone

---

### cargo scene and customer sell scene components unify

cargo scene and customer sell scene components unify to one group instead clone twice

### Inspection and Research Progress Feedback

Inspection and hub research need stronger moment-to-moment feedback because the player currently spends AP or research effort without an obvious sense of cause, progress, and result. The core loop depends on feeling that information was earned, so the screen should make each spend visible as an action resolving into a clue, a value shift, a verified state change, or meaningful progress toward one of those outcomes.

Feedback should be scene-contextual instead of only toast-based. The item card or selected item panel should flash on action, progress meters should move visibly, newly revealed clue rows should animate or highlight, and value/condition/verified labels should call out changed fields long enough to be noticed. Toasts remain useful for exceptional or global messages, but the primary feedback belongs next to the item and clue data it changes.

The design should separate three feedback layers: action feedback confirms the input was accepted; resolution feedback explains what the check or research step did; outcome feedback marks what changed in the item model. Examples: an inspection spend can show the attribute/check context, reveal or fail to reveal a specific surface clue slot, and then pulse the item estimate if the clue affects value. A research completion can fill the item-level research bar, reveal hidden clue rows together, mark the item verified, and show whether verified value moved up or down.

### Cargo Scene Item Summary Rework

The cargo scene summary should stop acting like a placeholder item dump and become the player's quick read on what they are taking home. At this point in the run the player needs to understand cargo composition, risk, and opportunity before confirming, not just see another flat item list.

The summary should answer four scan questions: how many items are loaded, what the current appraised value looks like, how much cargo capacity or weight is consumed, and which items are risky because they are unverified, low-condition, bulky, or low-value for their footprint. Grouping is more useful than a long raw list; likely groupings are category, verification status, value tier, or placement status.

Preferred layout: top summary cards for item count, appraised total, used capacity, and unverified count; a middle grouped item summary that highlights high-value, risky, and bulky entries; and a bottom action area that stays focused on confirming or adjusting cargo. The feature should preserve manual packing decisions and avoid introducing automated cargo behavior unless a separate auto-pack plan is in scope.

### Perk Type System: Gate vs Effect

`PerkData` has no type/kind field — all perks are identical resources. Split into `GATE` perks (content access, checked via `required_perk` on resources) and `EFFECT` perks (formula modifiers: keen_eye → inspection bonus, rarity_affinity → price, quick_study → XP gain). Wire effect perks into actual formulas — `perk_effects.gd` is currently a stub.

### Image v3 — Lot & Scene Decoration

Lot card decoration with a random icon/badge per lot. Phase-dependent decoration: worker loading truck in cargo, auctioneer gavel in auction, etc. Needs an asset pipeline — blocked on visual direction.

### NPC Depth Rolled Price

Full NPC knowledge-level system for rolled price; location-specific bidder personalities. Adds depth to auction encounters beyond the current flat NPC.

Current NPC bidding is too conservative: lots should have about a 50% chance to lose money if the player wins the bid. Improve the random method so NPCs can visibly become `Aggressive` when there is a competing NPC or player bid, making pressure spikes easier to read during the auction.
Need balance auction rolled price and NPC reaction(like, hype, aggressive, overprice)

### Named Rival NPCs

Two or three persistent named rivals with personalities and favored domains who recur across runs and grow in parallel with the player — beating a named rival is an emotional goal economic numbers alone can't provide. Builds on NPC Depth Rolled Price and the Dialog system. Tentative.

### Customer System Evolution

Weighted tag pools (calendar/event/progression-driven), regular customers with fixed profiles, quality tiers (budget vs. collector), selling-related perks. Builds on the current nightly customer system.

### Bank / Bankruptcy V2

Daily interest on cash reserves, game-over condition when debt threshold is crossed, optional player-initiated loans. Periodic-repayment deadlines (Recettear-style) considered as a floor-pressure driver, but a hard deadline sits uneasily with the calm-hub mood and the survivable-floor pillar — prefer soft daily upkeep (storage rent, fuel) if pressure is needed. Needs the day-slot economy to be stable first.

### Lot Pool Variety

Seasonal / rotating lot pools; one-shot special locations as events. Requires the location/auction system to be stable first.

### Garage Auction

A quick garage-sale encounter modelled on the current inspection scene: inspect visible items to reveal clues, then use Negotiation instead of bidding to decide the deal.

No veiled items and no partial-pick choice. The player buys everything or walks away, so the name may need to move away from "garage auction" toward a better all-or-nothing garage-buy concept.

### Popup system rework

Popup system should unify or generalize and ref from crusader king 3 popup system for wait few second for locking popup

---

### 0.3.0 Milestone

---

### Attribute Upgrades — Cost Scaling & Max Level

Attribute upgrades currently cost a flat $1000/level. Idea: cost scales with current level (linear or quadratic), or alternative growth paths (per-run rewards, daily training, mastery-gated upgrades). Once the upgrade curve is tuned, add a per-attribute max level / softcap. Designed after the base cash model is play-tested.

### Reputation + Scam Flow

Faction reputation system with scam-detection decision branches — builds on the customer system. Requires the customer system to be stable first.

### Auction Modifier: All-Base-Layer Run

An auction modifier variant where every lot contains only base-layer (anchor) clues — no surface or hidden. Requires a general auction modifier system to exist first.

### Training Courses

Hub-based training resource: spend cash and a day slot to temporarily boost an attribute for the next run. Training button in hub, resource-like expiry model.

### Calendar Special Events

Irregular special-auction announcements published on the calendar days in advance, so the player prepares (save cash, train, clear storage) for known future events — anticipation as a goal. Rides on the Calendar skeleton from the weekly-order flow; future home for Intel tip-offs as calendar events. Requires the Calendar skeleton to ship first.

### Intel System / Pre-Run Tip-Offs

Pre-run intelligence on available lots — reveal clue counts, surface categories, or estimated value tiers before committing the trip. Waiting on `LocationIntel` resource design. Superseded by Location Review v2 — fold when merging.

### Karma System

Karma tracks moral alignment separately from prestige — bad karma unlocks evil-aligned actions (scam routes, shady deals), good karma grants standard buffs or rewards (price bonuses, customer trust). Karma decreases when selling unverified items bearing fake or reproduce clues, reflecting the moral cost of passing counterfeit goods. Distinct from prestige: prestige measures reputation for quality/success, karma measures the player's moral trajectory.

---

### Future

---

### Hunter Profile & Statistics

A profile page that makes "better sight" visible as a curve: appraisal-error trend over time, per-category identification counts, best flip records. Pure presentation layer over existing knowledge/run data. Tentative.

### Expert Network (Appraisers)

Unresolved design: a network of appraiser NPCs the player can consult for better value estimates (beyond their own attributes). Pay-per-use or relationship-gated.

### Campaign Ending, Achievements & Prestige Perks

A 100-day main-line ending (inspired by Hero's Adventure 大俠立志傳): on day 100 the main storyline resolves into one of several endings with a matching achievement, then the save continues as sandbox where side quest lines remain completable. Achievements are earned from condition completion or quest-line endings and grant Score; at new-game start the player picks starting perks unlocked by accumulated Score / specific achievements (meta-progression across playthroughs). Collection-type achievements also serve as the interim chase layer until the Museum/Prestige shape is decided, so Museum needs no early skeleton.

### Museum / Prestige

Prestige system where rare/verified items can be donated or displayed for reputation, unlocking content gates. Design decisions needed first: what does prestige unlock or affect (access tiers, price modifiers, cosmetics, pure achievement)? Is it per-super-category or global? Is the donation UI in storage or a separate scene? The entire path is blocked on deciding the prestige shape.

### Shop Preparation Layer

Daytime shop actions should prepare tonight's business instead of opening the shop immediately. This keeps the fantasy that the shop is actually pressable at night while preserving a strategic reason to spend earlier slots on selling-related setup.

Possible preparation actions: `Prepare Shop` to improve customer volume or quality, `Set Tonight Tags` to bias demand toward categories or clue families the player wants to move, and `Assign Employee` to decide who handles routine selling work. The evening `Open Shop` action remains the actual manual customer-sell entry point and day closeout.

This layer should sit between the current slot commitment model and later employee automation. It can explain why a player who spent more of the day preparing gets better traffic or matching without requiring the selling scene to be entered before night.

### Half-AFK Shop

Add a low-friction employee-assisted selling path for nights when the player does not want to manually pack every customer car. The player sets tonight tags and assigns an NPC employee, then the employee auto-sells a limited set of matching items at about `x1.0` to `x1.5` price depending on employee attributes.

Manual selling should remain the high-control, high-upside option. Half-AFK selling is a convenience lane: lower interaction cost, lower ceiling than strong manual play, and meaningful dependence on the employee's appraisal or negotiation profile. It should avoid full-storage liquidation and should not blindly sell high-risk unverified items unless the player explicitly allows that behavior.

This likely depends on the shop preparation layer, because tags and assigned employee need to be chosen before the night resolves.

### Perk Content Expansion

Additional perks beyond the current attribute-threshold triggers, with full acquisition wiring (content-granted, event-granted, etc.).

### Content Gates (Mastery Rank)

Use `get_mastery_rank()` directly to gate prestige unlocks and NPC reaction tiers. Tier-locked auction houses moved to `dev/docs/plans/unlock_gating_location_tiers.md`, whose generic requirement block these gates should reuse.

### Vehicle Rework

Upgrade system for vehicles: bigger tank, reinforced cargo bay, etc.

Wear-and-tear system for vehicles affecting performance; repair cost and downtime.

Each vehicle grants a unique gameplay modifier (e.g. "+1 action per lot", "ignores first bad item").

Sell owned cars for partial value when upgrading, so trading up has a cost offset.

### Location Review v2

Richer lot-preview functionality on the location-select screen: browse lot contents before committing AP/travel, see special gating requirements (tier locks, perk gates, mastery minimums), and surface other meta-info (estimated value range, clue count hints, category breakdown). Builds on the existing `LocationIntel` concept in Draft — fold that entry here when merging. Currently the location-select scene shows only name, cost, and tagline; this adds depth to the decision layer without requiring a trip to confirm.

### Dialog System — Deferred to Story Demo

DialogManager, a shared overlay autoload, data-driven from the start — linear dialog first, Uncle branching second. The Director emits signals at the appropriate moments; DialogManager handles display, so no hub or run scene is modified directly. Shared by the story demo and the eventual full game. Deferred to the Stage 3 story demo — Phase 1's tutorial needs only the hint panel from Simple Tutorial above, which the full system can later grow out of.

---

## Active

> Do not delete this reminder text
> Flows currently being built or ready to implement — may hold more than one entry. One-line pointer each — same format as `## Plan`, promoted here when building starts or the plan is ready to build.
> Phase detail and progress live in the linked `dev/docs/plans/` file;
> Ship a phase → cut it from that file + append `CHANGELOG.md`, leaving this line untouched.
> All phases shipped → archive the plan file + delete this line.

Nothing currently in progress.

---

## Plan

Queued work, big enough to have a pre-plan file in `dev/docs/plans/`. Promote a line to `## Active` when building starts; if it goes stale here, retire it back to `## Draft`.

- [tag_clue_rework] Per-anchor identity tags (period/element/type) as the customer demand language, clue pool cut to ≤20 effect-based clues, single affix with weighted hidden pool, auto-collected notes with mastery-gated probability reads — see `dev/docs/plans/item_tags_effect_clues.md`

- [weekly_order] Weekly Special Order (clue-requirement orders, Monday publish, weekend expiry, turn-in UI) + Calendar skeleton — see `dev/docs/plans/weekly_order_calendar.md`; order requirements need a tags+effects redesign after tag_clue_rework

- [unlock_gating] Requirement-gated premium auction tiers + lot kinds, with location tier reference table & audit — see `dev/docs/plans/unlock_gating_location_tiers.md`

- [garage-sale] Buy-side garage sale with unveiled items, cargo grid, and haggle pricing — see `dev/docs/plans/garage_sale_auction.md`

- [vehicle-restoration] Collectible vehicle parts, full-set assembly, and finished-car sell — see `dev/docs/plans/vehicle_restoration.md`

- [balance_preview_v2] Balance preview HTML report — rich HTML output with per-effect and tag distribution tables, category breakdowns, and value distribution charts; rebuild against tag_clue_rework

- [data_layout] Domain-first data ownership and Catalog Resource conventions, preserving the current generated catalog until a focused migration — see `dev/docs/plans/domain_first_data_and_catalog_resources.md`

---

## Chore

One-line, no reasoning, no backing doc.

- [fix] update changelog rule to disallow unicode and force to be "compact"

- [tune] Attribute Rework

- [ci] Diagnose GitHub Actions infinite loop in Godot GUT/smoke jobs and re-enable the disabled CI layers.

---
