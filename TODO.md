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

### Build Automation (tres Generation + Export Presets)

One-press build flow covering the two release blockers from `dev/docs/visions/itchio_review.md`. (1) `data/tres/` is gitignored — all 250 `.tres` files (30 anchors / 184 clues / 12 categories / 4 cars / 6 lots / 4 super-categories / 5 attributes / 3 perks) exist only on disk, so a fresh clone loads zero resources and the game cannot boot; fix via a bootstrap script that runs the YAML pipeline to regenerate them (or un-gitignore the folder). (2) Export presets are not configured — no build can be produced at all. Fold both into one automated step: generate tres → export Windows + Linux builds.

### Director v2 — Highlight Target Component + Anchor Fill-to-Screen

The Director's `_position_near_anchor` and `_update_dim_hole` assume anchors are bounded UI regions. When an anchor fills the screen (e.g. a full-viewport PanelContainer used as a layout root), the hole cutout covers everything and `_position_near_anchor` shoves the hint panel off-screen or into a corner.

Add a dedicated `HighlightTarget` component (Control subclass or plain node with a Rect2 export) that scenes place in their tree to define a tutorial-highlightable region. The Director consumes these instead of raw Control references. Benefits: the component can specify a logical bounding box independent of the node's actual screen-filling rect, include a named id matching the script's `anchor_id`, and optionally define hint-panel placement preference (above/below/left/right/auto). Scenes that need no tutorial highlight don't add the node — zero-cost for non-tutorial code paths.

Fix for the current fill-to-screen case: detect anchors whose global rect ≈ viewport size and fall back to popup-style centered display with offset, or use the Director's screen-edge margin defaults instead of positioning relative to the anchor's edges.

### Simple Tutorial (No-Story)

The tutorial split out from the story demo — Stage 2's "small onboarding" pulled forward to Stage 1. A data-driven tutorial hint panel (step list: scene + trigger condition + hint text, played in order — no branching, no portraits, no story) guides the player through one full run + hub loop: inspect → bid → cargo (blocked from leaving empty) → storage → knowledge → customer sell → end day. The first run is made deterministic and friendly via the Director injection skeleton below (big car, high stamina, high-value low-depth items); free play afterwards, no multi-run scripting. The 3-run story demo (Uncle, X-Ray, Crown cutscene) moves to Stage 3. Panel is reusable in the full game. See `dev/docs/visions/itchio_review.md`. The hub + storage explain-only slice is promoted to `dev/docs/plans/tutorial_hint_panel.sketch.md`; this entry keeps the run-phase tutorial and injection scope.

### Director System — Phase 1 Injection Skeleton

A single autoload that manages scripted state without modifying production scenes — production scenes receive normal data and are unaware of the override. It is also the foundation of the future tutorial system. Two mechanisms:

- Data injection (zero pollution) — before a run starts, the Director writes fixed lot content, car assignment, and stamina directly into RunStore.
- Signal hooks (minimal pollution) — scenes connect to Director signals in their `_ready()` only when `Director.active` is true; the scenes' own logic is unchanged, behavior is pushed in from outside.

Phase 1 (Stage 1 tutorial) scope: data injection for the first run + one cargo-scene hook that blocks leaving with empty cargo. Deferred to the Stage 3 story demo: multi-run state machine, auction-scene forced-bid hooks, perk grants, and the day-pass cutscene trigger (flag check inside `advance_days()`).

### Dialog System — Deferred to Story Demo

DialogManager, a shared overlay autoload, data-driven from the start — linear dialog first, Uncle branching second. The Director emits signals at the appropriate moments; DialogManager handles display, so no hub or run scene is modified directly. Shared by the story demo and the eventual full game. Deferred to the Stage 3 story demo — Phase 1's tutorial needs only the hint panel from Simple Tutorial above, which the full system can later grow out of.

### Perk Type System: Gate vs Effect

`PerkData` has no type/kind field — all perks are identical resources. Split into `GATE` perks (content access, checked via `required_perk` on resources) and `EFFECT` perks (formula modifiers: keen_eye → inspection bonus, rarity_affinity → price, quick_study → XP gain). Wire effect perks into actual formulas — `perk_effects.gd` is currently a stub.

### Rarity Generation after Affix Refactor

`LotData.rarity_weights` is still authored in lot YAML and shown on lot cards, but `ItemGenerator.draw()` no longer reads it. Rarity now falls out of the generated item's hidden clue count, which is currently determined by selected affix combinations. Decide whether rarity should become an affix/combo authoring outcome or remain a lot-level draw constraint, then align lot UI, data authoring, storage costs, XP, sorting, and color tuning.

### Image v3 — Lot & Scene Decoration

Lot card decoration with a random icon/badge per lot. Phase-dependent decoration: worker loading truck in cargo, auctioneer gavel in auction, etc. Needs an asset pipeline — blocked on visual direction.

### Modalized HUD Navigation

Replace per-scene `_back_btn` / `_continue_btn` / `_reset_btn` manual wiring with a shared modalized HUD overlay. The HUD owns navigation controls and scene-agnostic chrome (cash, day display). Scenes emit navigation requests rather than direct `GameManager.go_to_*()` calls. Reduces boilerplate across ~10 scenes.

### Category Mastery ↔ Clue Integration

Mastery (category → super-category → rank) is retained as a progression signal (earned via `KnowledgeManager.add_category_points` on `REVEAL` / `SELL`) but currently has no mechanical effect on clue discovery. Idea: at certain ranks, inspection shows "N unrevealed surface clues remaining"; at higher ranks, the easiest surface clue may auto-reveal (no roll, no AP). Mastery does **not** affect DC or success rate — that is the attribute system. Thresholds TBD.

### Attribute Upgrades — Cost Scaling & Max Level

Attribute upgrades currently cost a flat $1000/level. Idea: cost scales with current level (linear or quadratic), or alternative growth paths (per-run rewards, daily training, mastery-gated upgrades). Once the upgrade curve is tuned, add a per-attribute max level / softcap. Designed after the base cash model is play-tested.

### Reputation + Scam Flow

Faction reputation system with scam-detection decision branches — builds on the customer system. Requires the customer system to be stable first.

### Expert Network (Appraisers)

Unresolved design: a network of appraiser NPCs the player can consult for better value estimates (beyond their own attributes). Pay-per-use or relationship-gated.

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

Pre-run intelligence on available lots — reveal clue counts, surface categories, or estimated value tiers before committing the trip. Waiting on `LocationIntel` resource design. Superseded by Location Review v2 — fold when merging.

### MetaManager Decomposition

MetaManager holds 6 stores and coordinates slot economy, storage AP, vehicle management, run resolution, customer sale, day-end, and location sampling (~358 lines). Below the pain threshold now, but it's the next candidate for splitting if it grows. The slot economy + storage AP section could become its own manager.

### NPC Depth Rolled Price

Full NPC knowledge-level system for rolled price; location-specific bidder personalities. Adds depth to auction encounters beyond the current flat NPC.

### Named Rival NPCs

Two or three persistent named rivals with personalities and favored domains who recur across runs and grow in parallel with the player — beating a named rival is an emotional goal economic numbers alone can't provide. Builds on NPC Depth Rolled Price and the Dialog system. Tentative.

### Lot Pool Variety

Seasonal / rotating lot pools; one-shot special locations as events. Requires the location/auction system to be stable first.

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

### Content Gates (Mastery Rank)

Use `get_mastery_rank()` directly to gate prestige unlocks and NPC reaction tiers. Tier-locked auction houses moved to `dev/docs/plans/unlock_gating_location_tiers.md`, whose generic requirement block these gates should reuse.

### Vehicle Upgrades / Mods

Upgrade system for vehicles: bigger tank, reinforced cargo bay, etc.

### Vehicle Durability & Repair

Wear-and-tear system for vehicles affecting performance; repair cost and downtime.

### Unique Per-Car Perks

Each vehicle grants a unique gameplay modifier (e.g. "+1 action per lot", "ignores first bad item").

### Vehicle Sell-Back / Trade-In

Sell owned cars for partial value when upgrading, so trading up has a cost offset.

### Tier-Linked Surface Clue Count

Future pool-generator work: surface clue count scales with the anchor's tier (e.g. tier 1 → 1–2 clues, tier 5 → 3–5) instead of one global range — higher-value items carry deeper information, making inspection investment on them more rational. Blocked on the pool generator shipping with the global range first.

### Location Review v2

Richer lot-preview functionality on the location-select screen: browse lot contents before committing AP/travel, see special gating requirements (tier locks, perk gates, mastery minimums), and surface other meta-info (estimated value range, clue count hints, category breakdown). Builds on the existing `LocationIntel` concept in Draft — fold that entry here when merging. Currently the location-select scene shows only name, cost, and tagline; this adds depth to the decision layer without requiring a trip to confirm.

---

## Active

Flows currently being built or ready to implement — may hold more than one entry. One-line pointer each — same format as `## Plan`, promoted here when building starts or the plan is ready to build. Phase detail and progress live in the linked `dev/docs/plans/` file; ship a phase → cut it from that file + append `CHANGELOG.md`, leaving this line untouched. All phases shipped → archive the plan file + delete this line. Nothing in progress or ready → this section is empty.

---

## Plan

Queued work, big enough to have a pre-plan file in `dev/docs/plans/`. Promote a line to `## Active` when building starts; if it goes stale here, retire it back to `## Draft`.

- [robustness] Atomic save writes, hard boot-guard on empty registries, run-state guards, price/save/migration tests — see `dev/docs/plans/robustness_hardening.sketch.md`
- [simple-demo] Stage 1 tutorial split out to the Simple Tutorial draft; Director skeleton + Dialog remain surviving subsystems
- [weekly_order] Weekly Special Order (clue-requirement orders, Monday publish, weekend expiry, turn-in UI) + Calendar skeleton — see `dev/docs/plans/weekly_order_calendar.md`
- [dev/auto-auction] Debug-only quick-win buttons: instant player win at opening bid or rolled price (skip NPC bidding loop; rolled path seeds future auto-bid perk) — see `dev/docs/plans/debug_auto_auction.md`
- [dev/auto-cargo] Debug-only quick-pack buttons: legal one-press auto-pack (seeds future auto-place perk) + stuff-all-and-go ignoring capacity — see `dev/docs/plans/debug_auto_cargo.md`
- [run_persistence] Mid-run save/resume: phase-stable resume scenes, atomic auction, escrowed run economics — see `dev/docs/plans/run_phase_persistence.md`
- [unlock_gating] Requirement-gated premium auction tiers + lot kinds, with location tier reference table & audit — see `dev/docs/plans/unlock_gating_location_tiers.md`
- [garage-sale] Buy-side garage sale with unveiled items, cargo grid, and haggle pricing — see `dev/docs/plans/garage_sale_auction.md`
- [vehicle-restoration] Collectible vehicle parts, full-set assembly, and finished-car sell — see `dev/docs/plans/vehicle_restoration.md`
- [clue_quality] Affix-aware clue information validator for posterior value narrowing and low-signal clue review — see `dev/docs/plans/clue_information_validator.sketch.md`

- [demo] 3-run story demo, demoted to Stage 3 scope (stale — references legacy Skill/Merchant systems);

---

## Chore

One-line, no reasoning, no backing doc.

- [tune] Attribute costs, customer generation weighting, perk balance — won't stabilise until earlier systems impose real constraints.
- [refactor] Collapse the duplicated rank-threshold ladder in `get_category_rank()` to loop over `RANK_THRESHOLDS`
- [style] Standardize docstrings across all `.gd` files — file header + public function GDDoc format.
- [debug] Add an debug button in Hub to sell all items in storage
- [debug] Add an debug button in Hub to add random item
- [debug] Add Debug Overlay that use debug button in hub to toggle?
  ​
- [refactor] ItemYaml - Refactor Yaml strcuture, so I can list all affix and clues situation in each categories

- [bug] Unreveal clues should be unknown as ???

---

## Bug

One-line defect to fix.
