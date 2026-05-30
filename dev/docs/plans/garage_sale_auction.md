# Garage-Sale Auction

> Not scheduled. Also serves as the canonical backup of the **merchant negotiation mechanic**, which is being decommissioned with the rest of the merchant system (`game/meta/merchant/`, `MerchantData`, `MerchantRegistry`, special orders) as part of the Phase 9 customer-sell redesign (`../archived/merchant_system_redesign.md`). The negotiation math, state machine, and tuning surface captured here are the reusable core; everything else in the old merchant system is intentionally left to die.

A buy-side run surface. The player visits a garage sale (or estate sale), sees a list of items the seller has laid out, inspects them, picks what to take home by fitting items into a cargo grid, and then haggles the seller's asking price down — trying to pay as little as possible without making the seller dig in and refuse.

It is the **mirror image** of the old merchant shop. There, the player was the _seller_ pushing a basket of owned items _up_ toward a hidden ceiling while the merchant's anger rose. Here the player is the _buyer_ pushing the seller's asking price _down_ toward a hidden floor while the seller's anger rises. The negotiation engine is the same; only the direction and the labels flip.

## Why this exists

The run loop currently has one acquisition channel: the lot auction. Lots are sealed, bid blind-ish, and won whole. The garage sale adds a second acquisition mode with a different texture:

- **Open inventory, not sealed.** Every item is unveiled by default — the player
  sees what is on offer up front and can inspect to reveal clues, but there is no
  "buy the whole mystery box" gamble.
- **Selective, not all-or-nothing.** The player chooses _which_ items to take by
  fitting them into a cargo grid, the same spatial puzzle used in cargo packing and
  customer sell. Grid capacity is the constraint, not a single winning bid.
- **Priced by haggling, not by auction.** Instead of out-bidding rivals, the player
  negotiates the seller's asking price down. This reuses the merchant negotiation
  engine, inverted to buyer-side.

It reuses three mechanics the game already has — clue inspection, grid packing, and basket negotiation — and recombines them so none of the implementation is novel. The bulk of this doc is the negotiation engine, because that is the piece being removed from the codebase and must be preserved precisely.

## Scene flow

```
location / hub entry point
  └── garage_sale_browse        (list of items on offer, all unveiled)
       ├── [inspect an item] -> inspection grid (reveals surface clues)
       └── [select items]    -> cargo grid packing (choose what fits / what to take)
            └── negotiation_dialog   (haggle the asking price down)
                 ├── [deal struck]   -> pay, items enter cargo/storage
                 ├── [seller digs in]-> final offer: accept or walk away
                 └── [walk away]      -> leave with nothing (or with an earlier deal)
```

The browse and inspection surfaces are existing systems referenced below. The packing grid is an existing shared component. The negotiation dialog is the preserved mechanic, re-skinned buyer-side.

---

## Reused systems (references, not new work)

### Item inspection — reuse `game/run/inspection/`

The lot-auction inspection scene (`game/run/inspection/inspection_scene.gd`, documented in `../systems/lot_auction_run.md`) is an AP-limited grid where the player spends action points to **unveil** shape cells (`UNVEIL_COST`) and **inspect clues** (`CLUE_CHAIN_COST`), discovering surface clues via dice rolls modified by the player's attributes.

For the garage sale, the key difference stated in the feature brief is **all items are unveiled by default** — there is no fog over the grid. The player still spends AP (or some inspection budget) to reveal _clues_ and raise `inspection_level`, which sharpens the appraised value, but the "what shape is this even" reveal step is skipped. In practice this means reusing the clue-inspection half of the existing scene with the unveil step pre-completed for every shape.

`ItemEntry` already tracks everything needed: `anchor_revealed`, `revealed_clue_ids`, `inspection_level`, `condition`, and the appraised value resolves through `ItemEntry.item_price` (`(appraised value) × condition_multiplier`, per `CLAUDE.md`). Nothing new is required on the runtime model.

### Cargo selection — reuse `PackingGrid` (`game/shared/packing/packing_grid.gd`)

`PackingGrid extends GridContainer` is the shared spatial-packing component already used by run-phase cargo (`game/run/cargo/cargo_scene.gd`) and the hub customer-sell scene (`game/meta/customer_sell/customer_sell_scene.gd`). Public API:

```
setup(cols, rows)            # size the grid
can_place(item, origin)      # legality check
place(item, origin) / erase(item) / lift(item)
set_held_item(item, rotation) / cancel_placement()
get_active_cells(item) / get_rotated_cells(item)
is_item_placed(item) / get_item_origin(item)
reset() / refresh_visuals()
```

Signals: `item_clicked`, `cell_clicked`, `placement_changed`, `placement_cancelled`, `hover_started`, `hover_ended`.

The garage sale uses this exactly as customer-sell does — the player drags candidate items into the grid; whatever fits is "what I'm taking home." The set of placed items becomes the **basket** handed to the negotiation dialog. Grid size is the acquisition constraint (a small car forces hard choices among the items on offer).

---

## Negotiation engine (the preserved mechanic)

> Source of truth being backed up: `game/meta/merchant/negotiation_dialog/negotiation_dialog.gd` and the negotiation tuning fields of `data/definitions/merchant_data.gd`. The prose in `../systems/meta/merchant_shop.md` documents the same engine seller-side. This section reproduces the complete math so the engine can be rebuilt after the merchant code is deleted.

### Concept

The dialog opens on a **basket** (the items being traded) and resolves to a single final price. There is a hidden **ceiling** (seller-side it is the max the merchant will pay; buyer-side it becomes the **floor** the seller will accept). The player submits proposals; each proposal either gets accepted, triggers a counter-offer, or exhausts the other party's patience (anger). When anger hits its cap, the other party makes a take-it-or-leave-it **final offer**.

### State

```gdscript
signal accepted(final_price: int)
signal cancelled

enum Phase { NEGOTIATING, FINAL_OFFER }

var _base_offer: int       # Σ item_price over the basket
var _ceiling: int          # hidden, rolled per session
var _current_offer: int    # the standing offer, starts at base_offer
var _anger: float          # 0 → anger_max
var _state: Phase
```

### Session setup — `begin(merchant, basket)`

```
base_offer    = Σ entry.item_price for entry in basket
current_offer = base_offer
ceiling_mult  = randf_range(ceiling_multiplier_min, ceiling_multiplier_max)
ceiling       = int(base_offer × ceiling_mult)
anger         = 0
state         = NEGOTIATING
```

The exact rolled `ceiling` is **never shown**. The UI only shows the _range_ (`base_offer × ceiling_multiplier_min` … `base_offer × ceiling_multiplier_max`), so the player knows the band but must probe for the real number. This mystery is the core of the mechanic — overshoot the ceiling and you instantly max out anger.

### Resolution per submitted proposal — `_resolve_proposal(proposal)`

Evaluated top-to-bottom; first matching branch wins:

| Condition                            | Outcome                                                                                                                                                             |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `proposal <= current_offer`          | Lowball-confirm dialog. On confirm → `accepted(proposal)` (you can always accept the standing offer or worse). On cancel → no anger, the round is **not** consumed. |
| `proposal > ceiling`                 | Anger pinned to `anger_max` → `FINAL_OFFER` state at `current_offer`.                                                                                               |
| anger would reach `anger_max`        | `anger = anger_max` → `FINAL_OFFER` state at `current_offer`.                                                                                                       |
| proposal inside the auto-accept band | Probabilistic immediate `accepted(proposal)` — skips the counter round.                                                                                             |
| otherwise                            | Apply anger, emit a counter-offer, stay in `NEGOTIATING`.                                                                                                           |

### Anger formula

When `current_offer < proposal <= ceiling`:

```
gap   = max(1, ceiling − current_offer)
greed = (proposal − current_offer) / gap          # 0..1, how much of the remaining gap you grabbed
anger += anger_k × greed + anger_per_round
```

`anger_per_round` is a flat tax every submission, so even patient haggling has a hard round ceiling of `anger_max / anger_per_round` rounds. `anger_k` scales the _greed_ penalty: a proposal that jumps most of the way to the ceiling costs far more patience than a small nudge. A `proposal > ceiling` skips this entirely and pins anger to max.

### Auto-accept on small gaps

Before countering, the engine rolls for immediate acceptance when the proposal sits close to the standing offer — this defangs the busywork of forcing a counter round over trivial movement:

```
ratio = (proposal − current_offer) / max(1, ceiling − current_offer)
if ratio <= auto_accept_threshold:
    t = ratio / auto_accept_threshold              # 0..1 across the band
    p = lerp(1.0, auto_accept_p_min, t)            # 1.0 at ratio 0  →  p_min at threshold
    if randf() < p:
        accepted(proposal); return
```

So a proposal almost equal to the current offer accepts near-certainly; one right at the threshold edge accepts with probability `auto_accept_p_min`. Outside the band the normal anger-and-counter flow runs.

### Counter-offer formula

```
current_offer += int(counter_aggressiveness × (proposal − current_offer))
```

The other party closes a fixed fraction of the distance between its standing offer and the player's proposal each round. Higher `counter_aggressiveness` = moves toward the player faster (more generous). The new `current_offer` becomes the floor for the next round's calculations.

### Final offer

In `FINAL_OFFER` the proposal UI is hidden; only **Accept** (`accepted(current_offer)`) and **Walk Away** (`cancelled`) remain. Per the feature brief, the final price is the last standing offer — which, depending on how badly negotiations went, may be no better than (or could be designed to snap back toward) the original asking price.

### UI layout (preserved node tree)

`negotiation_dialog.tscn` is a centered modal `Control` over a dim `Overlay`:

```
CenterContainer/Panel/MarginContainer/VBox
├── TitleLabel                "Negotiation with <name>"
├── BasketSummaryVBox
│   ├── BasketCountLabel       "N items"
│   └── BasketValueLabel       "Base offer: $X"
├── OfferVBox
│   ├── CurrentOfferLabel      "Current Offer: $X"
│   ├── CeilingRangeLabel      "Merchant range: $min – $max"   (band only, never exact)
│   ├── AngerBar               ProgressBar, max = anger_max
│   └── AngerLabel             "Merchant patience" / "...: Exhausted"
├── ProposalVBox               (visible in NEGOTIATING)
│   ├── ProposalButtonRow      [-50%] [-25%] [-10%] [+10%] [+25%] [+50%]  (relative to current_offer)
│   └── SubmitRow              ProposalInput (SpinBox) + SubmitBtn
├── FinalOfferVBox             (visible in FINAL_OFFER)
│   ├── FinalOfferMessage      "...final offer — take it or leave it."
│   └── AcceptBtn
└── WalkAwayBtn
+ LowballConfirm (ConfirmationDialog)
```

The ±% buttons set `ProposalInput = int(current_offer × (1 + pct))` — they are shortcuts relative to the _standing offer_, not the base.

### Tuning surface (`MerchantData` negotiation fields)

These are the designer-facing knobs to preserve. Reproduced from `data/definitions/merchant_data.gd`:

| Field                    | Default | Meaning                                                                             |
| ------------------------ | ------- | ----------------------------------------------------------------------------------- |
| `ceiling_multiplier_min` | `1.1`   | Lower bound of the per-session ceiling roll (× base offer).                         |
| `ceiling_multiplier_max` | `1.3`   | Upper bound of the ceiling roll. The shown range.                                   |
| `anger_max`              | `100.0` | Patience cap; reaching it forces the final offer.                                   |
| `anger_k`                | `20.0`  | Gain on the greed term of the anger formula.                                        |
| `anger_per_round`        | `20.0`  | Flat anger per submission. Sets the hard round cap (`anger_max / anger_per_round`). |
| `counter_aggressiveness` | `0.3`   | Fraction of the gap closed per counter, in `(0, 1]`.                                |
| `auto_accept_threshold`  | `0.2`   | Gap-ratio below which auto-accept may fire.                                         |
| `auto_accept_p_min`      | `0.05`  | Acceptance probability at the threshold edge (interpolates from `1.0`).             |
| `negotiation_per_day`    | `1`     | Sessions allowed per day (runtime `negotiations_used_today`).                       |

Two reference merchant tunings from `data/yaml/merchant_data.yaml`:

- **Pawn Shop** — generous, forgiving: ceiling `1.1–1.3`, `anger_max 100`,
  `counter_aggressiveness 0.3`, `auto_accept_threshold 0.2`. A soft trainer
  opponent.
- **Antique Dealer** — tighter and pricklier: ceiling `1.2–1.5` (wider mystery,
  higher payoff), `anger_max 80` (less patient), `anger_k 25` /
  `anger_per_round 25` (greed punished harder), `counter_aggressiveness 0.4`
  (closes faster when it does move), `auto_accept_threshold 0.15` (narrower
  free-accept band). Rewards precise probing.

### Settlement (seller-side, for reference)

The old seller-side accept path (`MetaManager.sell_items`, `merchant_shop_scene._on_negotiation_accepted`): credit `SaveManager.cash += price`, erase sold entries from `SaveManager.storage_items`, clear any research slots on them, award `KnowledgeManager` category points with the `SELL` action, increment the merchant's `negotiations_used_today`, then `SaveManager.save()`. On cancel it still incremented the negotiation count and saved. The daily budget reset and ceiling re-roll happened in `MerchantRegistry.advance_day()` → `_reset_negotiations()`.

---

## Buyer-side inversion (what changes for the garage sale)

The engine is symmetric; only orientation and labels change.

| Seller-side (old merchant shop)                              | Buyer-side (garage sale)                                                                                      |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| Player pushes price **up**                                   | Player pushes price **down**                                                                                  |
| Hidden **ceiling** = max merchant will pay                   | Hidden **floor** = min the seller will accept                                                                 |
| `base_offer = Σ item_price` (what merchant initially offers) | `asking_price` = seller's opening number (e.g. `item_price × asking_multiplier > 1`)                          |
| Proposals climb toward the ceiling                           | Proposals descend toward the floor                                                                            |
| `proposal > ceiling` → instant max anger                     | `proposal < floor` → instant max anger (insulting lowball)                                                    |
| Lowball guard: `proposal <= current_offer`                   | Highball guard: `proposal >= current_offer` (offering _more_ than the standing price — auto-accept / confirm) |
| Counter moves merchant's offer up toward player              | Counter moves seller's price down toward player                                                               |
| Accept credits cash, removes items                           | Accept **debits** cash, **adds** items to cargo/storage                                                       |

Mechanically the cleanest implementation keeps the math identical and works in "discount space" — negotiate over how far _below_ the asking price the deal lands, so all the existing `>`/`<` comparisons and the greed ratio carry over unchanged. The "anger" stays anger; the "ceiling" is relabeled "floor" in the UI; the ±% buttons offer discounts instead of markups.

### New data this needs

- A garage-sale **seller** definition carrying the same negotiation tuning block
  (`floor_multiplier_min/max` in place of `ceiling_multiplier_*`, plus
  `anger_max`, `anger_k`, `anger_per_round`, `counter_aggressiveness`,
  `auto_accept_threshold`, `auto_accept_p_min`). This is the `MerchantData`
  negotiation block, extracted and renamed — do **not** revive the special-order /
  category-pricing fields.
- An **asking price** per sale (or per item), above the appraised value, that the
  haggling reduces.
- The on-offer **item list** for the sale (unveiled `ItemEntry` instances).

### What is explicitly NOT carried over

The Phase 9 redesign (`../archived/merchant_system_redesign.md`) deletes these and the garage sale should not resurrect them: special orders / order slots / the fulfillment panel, super-category specialist pricing (`accepted_super_categories`, `price_multiplier`, `off_category_multiplier`), the merchant hub navigation, the reputation/scam and expert-network deferred surfaces, and `MerchantRegistry` order orchestration. Only the negotiation engine and its tuning block survive here.

## Open questions

- **Where does the garage sale live in the loop?** A run-phase location variant
  (alongside lot auctions) or a hub-phase nightly option (alongside customer sell)?
  This decides which scene-flow entry point and which save buckets the bought items
  land in.
- **Floor snap-back on blown negotiations.** The brief says a failed negotiation may
  leave the player paying "the last offered price or even the original asking
  price." The old engine's final offer is simply `current_offer`; a snap-back-toward-
  asking behavior on anger-max would need to be added.
- **Inspection budget source.** Lot-auction inspection spends run AP. A standalone
  garage sale needs its own AP/budget source decided, since all items start unveiled
  and only clue-reveal costs apply.
- **Per-item vs basket haggling.** The merchant engine haggles the whole basket at
  once. A garage sale could plausibly haggle item-by-item; basket-level is the
  cheaper reuse and is assumed here unless design says otherwise.

## Source map (for rebuilding after deletion)

- Negotiation logic + UI handlers: `game/meta/merchant/negotiation_dialog/negotiation_dialog.gd`
- Negotiation UI tree: `game/meta/merchant/negotiation_dialog/negotiation_dialog.tscn`
- Tuning fields + defaults: `data/definitions/merchant_data.gd` (negotiation block)
- Reference tunings: `data/yaml/merchant_data.yaml` (`pawn_shop`, `antique_dealer`)
- Seller-side basket UI + settlement wiring: `game/meta/merchant/merchant_shop/merchant_shop_scene.gd`
- Settlement: `MetaManager.sell_items()` (`global/autoload/meta_manager.gd`)
- Daily budget / ceiling orchestration: `MerchantRegistry.advance_day()` (`global/autoload/registries/merchant_registry.gd`)
- Packing grid (reused as-is): `game/shared/packing/packing_grid.gd`
- Inspection (reused, unveil pre-completed): `game/run/inspection/inspection_scene.gd`
- Seller-side prose docs (same engine): `../systems/meta/merchant_shop.md`, `../systems/meta/merchant.md`
