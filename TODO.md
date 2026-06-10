# TODO

The single forward surface — open this and you see everything: open work _and_ brewing ideas. Every forward item lives in **exactly one** section here (or, once it earns a file, in `dev/docs/plans/`). There is deliberately **no "Done" tier** — done = delete the line; its record lives in `CHANGELOG.md`.

> **The one rule (now about sections, not files):** the actionable tiers (`Plan` / `Chore` / `Bug`) are **one line each** — no paragraphs, no tables, no _why_. The moment an item needs real reasoning, it belongs in `## Draft` as its own `###` sub-section. When a Draft entry grows sub-structure, becomes actionable, or needs to be linked from elsewhere, it graduates to its own file in `dev/docs/plans/`.
>
> Within `## Draft`, no `####` headings or `**label:**` bold-label patterns — use plain-text labels (em-dash, colon) and lists for sub-structure.
>
> **Tag format:** the `[Scope]` tag in actionable lines is **snake_case** — short lowercase identifier, no spaces, no parens, no mixed case (e.g. `[customer_sell]`, `[bugfix]`).

In-flight work lives in `## Active` — promoted from `## Plan` when building starts. The phase-by-phase detail and ordering stay in the linked `dev/docs/plans/` file, never churned into this list.

Actionable line format: `[Scope] one sentence — [ref plans/<x>.md if any]`

---

## Draft

Preliminary concepts — bigger than a one-liner, but a single `###` sub-section says enough. Not necessarily actionable yet. One `###` heading per idea (nested under this `## Draft` so the section stays intact). When an idea outgrows its sub-section / becomes actionable / needs a stable link → move it into its own `dev/docs/plans/<x>.md` (`Status: Exploring`) and delete it here. Stale and never grew → just delete it.

### Image v3 — Lot & Scene Decoration

Lot card decoration with a random icon/badge per lot. Phase-dependent decoration: worker loading truck in cargo, auctioneer gavel in auction, etc. Needs an asset pipeline — blocked on visual direction.

### Category Mastery ↔ Clue Integration

Mastery (category → super-category → rank) is retained as a progression signal (earned via `KnowledgeManager.add_category_points` on `REVEAL` / `SELL`) but currently has no mechanical effect on clue discovery. Idea: at certain ranks, inspection shows "N unrevealed surface clues remaining"; at higher ranks, the easiest surface clue may auto-reveal (no roll, no AP). Mastery does **not** affect DC or success rate — that is the attribute system. Thresholds TBD.

### Attribute Upgrades — Cost Scaling & Max Level

Attribute upgrades currently cost a flat $1000/level. Idea: cost scales with current level (linear or quadratic), or alternative growth paths (per-run rewards, daily training, mastery-gated upgrades). Once the upgrade curve is tuned, add a per-attribute max level / softcap. Designed after the base cash model is play-tested.

### Reputation + Scam Flow

Faction reputation system with scam-detection decision branches — builds on the customer system. Requires the customer system to be stable first.

### Expert Network (Appraisers)

Unresolved design: a network of appraiser NPCs the player can consult for better value estimates (beyond their own attributes). Pay-per-use or relationship-gated.

### Modalized HUD Navigation

Replace per-scene `_back_btn` / `_continue_btn` / `_reset_btn` manual wiring with a shared modalized HUD overlay. The HUD owns navigation controls and scene-agnostic chrome (cash, day display). Scenes emit navigation requests rather than direct `GameManager.go_to_*()` calls. Reduces boilerplate across ~10 scenes.

### Campaign Ending, Achievements & Prestige Perks

A 100-day main-line ending (inspired by Hero's Adventure 大俠立志傳): on day 100 the main storyline resolves into one of several endings with a matching achievement, then the save continues as sandbox where side quest lines remain completable. Achievements are earned from condition completion or quest-line endings and grant Score; at new-game start the player picks starting perks unlocked by accumulated Score / specific achievements (meta-progression across playthroughs). Collection-type achievements also serve as the interim chase layer until the Museum/Prestige shape is decided, so Museum needs no early skeleton.

### Hunter Profile & Statistics

A profile page that makes "better sight" visible as a curve: appraisal-error trend over time, per-category identification counts, best flip records. Pure presentation layer over existing knowledge/run data. Tentative.

### Museum / Prestige

Prestige system where rare/verified items can be donated or displayed for reputation, unlocking content gates. Design decisions needed first: what does prestige unlock or affect (access tiers, price modifiers, cosmetics, pure achievement)? Is it per-super-category or global? Is the donation UI in storage or a separate scene? The entire path is blocked on deciding the prestige shape.

### Auction Modifier: All-Base-Layer Run

An auction modifier variant where every lot contains only base-layer (anchor) clues — no surface or hidden. Requires a general auction modifier system to exist first.

### Training Courses

Hub-based training resource: spend cash and a day slot to temporarily boost an attribute for the next run. Training button in hub, resource-like expiry model.

### Calendar Special Events

Irregular special-auction announcements published on the calendar days in advance, so the player prepares (save cash, train, clear storage) for known future events — anticipation as a goal. Rides on the Calendar skeleton from the weekly-order flow; future home for Intel tip-offs as calendar events. Requires the Calendar skeleton to ship first.

### Intel System / Pre-Run Tip-Offs

Pre-run intelligence on available lots — reveal clue counts, surface categories, or estimated value tiers before committing the trip. Waiting on `LocationIntel` resource design.

### Entry/Instance Archetype — Standardize to Model or Service

The Entry/Instance archetype is in a middle state: it has mutable fields and self-mutating methods (`unveil()`, `attempt_clue()`, `auto_reveal_all_surface()`), but scenes call those methods directly rather than going through a Manager. This makes Entry neither a clean data Model (mutations mediated by Manager, like Stores) nor a stateless Service. Decide which direction Entries should go: thin data holders where Managers own all mutations (aligning with the Store pattern), or self-contained objects with a clear contract for who may call mutation methods and when. This shapes both the ItemEntry cleanup and the encapsulation work below.

### MetaManager Decomposition

MetaManager holds 6 stores and coordinates slot economy, storage AP, vehicle management, run resolution, customer sale, day-end, and location sampling (~358 lines). Below the pain threshold now, but it's the next candidate for splitting if it grows. The slot economy + storage AP section could become its own manager.

### NPC Depth Rolled Price

Full NPC knowledge-level system for rolled price; location-specific bidder personalities. Adds depth to auction encounters beyond the current flat NPC.

### Named Rival NPCs

Two or three persistent named rivals with personalities and favored domains who recur across runs and grow in parallel with the player — beating a named rival is an emotional goal economic numbers alone can't provide. Builds on NPC Depth Rolled Price and the Dialog system. Tentative.

### Lot Pool Variety

Seasonal / rotating lot pools; one-shot special locations as events. Requires the location/auction system to be stable first.

### Director System

Autoload that manages demo state without modifying production scenes — injects fixed lot content, car assignment, and perks into RunStore before each run. Uses signal hooks on auction/cargo scenes for forced-bid/block behavior. See `dev/docs/plans/demo_summary.md`.

### Dialog System

Linear dialog first (Uncle branching second). DialogManager overlay autoload with data-driven dialog. Shared by demo runs and eventual full game. See `dev/docs/plans/demo_summary.md`.

### Bank / Bankruptcy

Daily interest on cash reserves, game-over condition when debt threshold is crossed, optional player-initiated loans. Periodic-repayment deadlines (Recettear-style) considered as a floor-pressure driver, but a hard deadline sits uneasily with the calm-hub mood and the survivable-floor pillar — prefer soft daily upkeep (storage rent, fuel) if pressure is needed. Needs the day-slot economy to be stable first.

### Customer System Evolution

Weighted tag pools (calendar/event/progression-driven), regular customers with fixed profiles, quality tiers (budget vs. collector), selling-related perks. Builds on the current nightly customer system.

### Garage Sell

Sell individual items in a garage-style scene modelled on `game/run/auction/`. System placement unclear: merchant surface or standalone selling channel? Deferred until the customer sell flow is stable.

### Warehouse Variant Support

Hub surfaces different warehouse exteriors and lot counts per location variant. Requires the location system to define variants first.

### Perk Content Expansion

Additional perks beyond the current attribute-threshold triggers, with full acquisition wiring (content-granted, event-granted, etc.).

### Perk Type System: Gate vs Effect

`PerkData` has no type/kind field — all perks are identical resources. Split into `GATE` perks (content access, checked via `required_perk` on resources) and `EFFECT` perks (formula modifiers: keen_eye → inspection bonus, rarity_affinity → price, quick_study → XP gain). Wire effect perks into actual formulas — `perk_effects.gd` is currently a stub.

### Content Gates (Mastery Rank)

Use `get_mastery_rank()` directly to gate prestige unlocks and NPC reaction tiers. Tier-locked auction houses moved to `dev/docs/plans/unlock_gating_location_tiers.md`, whose generic requirement block these gates should reuse.

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

### Pool-Based Item Generation

Remove `ItemData` as an authored-per-item resource. Instead, generate items at lot-draw time: pick a category, draw an anchor variant (lot/location tier weight curves), draw surface clues uniformly (anchor-conditioned drawing is its own Draft below), draw rarity (lot/location-controlled frequency) then that many hidden clues uniformly from valid non-excluded options. True name from affix composition, true value from drawn modifiers. Draw-control metadata (anchor tiers, exclusive groups) shipped with the clue schema cleanup; draw rules and regenerated pools come from `dev/docs/plans/clue_content_standard_regen.md`. Remaining work here: the generator itself, lot/location tier curves + rarity frequency tables, a balance-tuning tool to preview draw value distributions before shipping, and item serialization moving from registry item-id lookup to stored clue lists (generated items have no registry id). Prerequisites: clue content regen shipped; affix naming validated across the curated set (already in place).

### Anchor-Conditioned Surface Draw

Future pool-generator work: bias surface clue draws by the item's anchor (tier/category affinity) instead of pure uniform. A first half-built attempt — affinity tags plus per-tag weight overrides authored on surface clues — was removed by the clue schema cleanup: the anchor side of the relationship was never defined, and per-clue weight dictionaries degenerate into a disguised per-pair weight matrix. Needs a settled model first (e.g. tags declared on anchors, a single weight function over tag overlap, never per-pair matrices). Blocked on the pool generator existing at all; uniform draw is the shipping behavior until then.

### Combination Naming Rules

A combination rule defines a set of input clue ids and a replacement naming entry (slot, text, priority). When all inputs are revealed on the same item, the combination replaces individual naming entries during display-name composition — e.g. `{Blown Glass, Moser}` → `"Bohemian Moser"`. Authored per category, separate from clue definitions.

Validation — the validator enforces:

- existence of every referenced clue id,
- same-domain inputs,
- priority dominance over the individual naming entries it replaces,
- full-reveal name match (the composed name equals the authored combination name when all inputs are revealed).

Open questions:

- Pairs only, or arbitrary input sets?
- A single clue participating in multiple combination rules — allowed, and how resolved?
- Strict text containment vs. free replacement of the individual entries.

Prerequisite: the affix-naming system validated across the full item set (composed == authored) — already in place.

### ItemEntry Cleanup / Data Standard

`item_entry.gd` (698 lines) mixes price math, display text helpers, serialization, clue mechanics, and factory logic. Split into layers: `ItemEntry` = data + price logic, display getters = separate concern (`ItemDisplay` or similar). Clear boundary: `ItemData` (designer resource, the _what_), `ItemEntry` (runtime instance, the _state+behavior_), display (the _show_).

### ItemEntry Encapsulation — Manager-Mediated Mutations

Run-phase scenes (`inspection_scene`, `reveal_scene`, `run_review_scene`) mutate ItemEntry directly — `entry.unveil()`, `entry.attempt_clue()`, `entry.condition = ...` — bypassing RunManager. This is inconsistent with the Store/Manager pattern established by the save refactor where all state mutation goes through the owning Manager. Add thin RunManager wrappers (`unveil_item()`, `apply_trailer_damage()`, etc.) so ItemEntry mutations follow the same discipline as Store mutations. Not urgent — harmless today because no one else observes mid-run ItemEntry state — but blocks any future save-on-inspect or mid-run persistence.

---

## Active

Flows currently being built. One-line pointer each — same format as `## Plan`, just promoted here when work starts. Phase detail and progress live in the linked `dev/docs/plans/` file; ship a phase → cut it from that file + append `CHANGELOG.md`, leaving this line untouched. All phases shipped → archive the plan file + delete this line. Nothing in progress → this section is empty.


---

## Pending

The deferred tail of an in-flight flow. When a confirmed initiative spans multiple plans, the parts not being built yet wait here instead of crowding `## Active` — same one-line format, promoted to `## Active` when their turn comes. Normally empty: a small fix or a feature that a single plan covers never uses this tier — it goes straight from `## Plan` to `## Active`.

- [item_entry_refactor] ItemEntry layer split (data + price vs display) + Manager-mediated mutations, merged into one refactor — plan file pending, reasoning in the ItemEntry / Entry-Instance `## Draft` sections
- [pool_generation] Pool-based item generation (generator, lot/location tier curves, balance tool, clue-list serialization) — plan file pending, reasoning in the Pool-Based `## Draft` section; depends on clue_content + item_entry_refactor

---

## Plan

Queued work, big enough to have a pre-plan file in `dev/docs/plans/`. Promote a line to `## Active` when building starts; if it goes stale here, retire it back to `## Draft`.

- [clue_content] Generation standard, prompt rewrite, reference tables + full YAML regen on the post-cleanup schema (absorbs cleanup review leftovers) — see `dev/docs/plans/clue_content_standard_regen.md`
- [weekly_order] Weekly Special Order (clue-requirement orders, Monday publish, weekend expiry, turn-in UI) + Calendar skeleton — see `dev/docs/plans/weekly_order_calendar.md`
- [unlock_gating] Requirement-gated premium auction tiers + lot kinds, with location tier reference table & audit — see `dev/docs/plans/unlock_gating_location_tiers.md`
- [garage-sale] Buy-side garage sale with unveiled items, cargo grid, and haggle pricing — see `dev/docs/plans/garage_sale_auction.md`
- [vehicle-restoration] Collectible vehicle parts, full-set assembly, and finished-car sell — see `dev/docs/plans/vehicle_restoration.md`
- [demo] Tutorial 3-run surface (stale — references legacy Skill/Merchant systems); Director + Dialog systems are surviving subsystems — see `dev/docs/plans/demo_summary.md`

---

## Chore

One-line, no reasoning, no backing doc.

- [tune] Attribute costs, customer generation weighting, perk balance — won't stabilise until earlier systems impose real constraints.
- [refactor] Collapse the duplicated rank-threshold ladder in `get_category_rank()` to loop over `RANK_THRESHOLDS`
- [dev] Auto-put won items to cargo grid (dev-only, skips manual packing).
- [dev] Instant-finish auction at current price (dev-only action).
- [style] Standardize docstrings across all `.gd` files — file header + public function GDDoc format.

---

## Bug

One-line defect to fix.
