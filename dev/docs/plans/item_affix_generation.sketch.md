# Affix-Driven Item Generation & Knowledge Dictionary

> This sketch is the durable design home. Implementation is split into specs: `item_affix_generation_core.spec.md` (generation core), `item_affix_naming.spec.md` (affix-only naming), and a deferred Spec C for the knowledge dictionary (R5–R7, out of the playtest cut). Codebase-driven design changes are folded back here, not into the specs.

## Goal

Reverse the item-generation causality so the **name is the index, not the decoration**: draw affixes first, each affix expands into a small set of clue-combinations, and the chosen combination determines the item's surface and hidden clues. This makes reading the name carry real information, turns Authenticate into a genuine bet on hidden clues, and gives the knowledge system a dictionary with a natural page structure — directly fixing the alpha-observed failure where the optimal play is "sort by price and ignore every clue."

## Background — why now

The current pipeline computes `appraised_value = anchor + Σ revealed surface effects` and hands the player a single number. Because the system does the math, clue text is just a footnote on that number and naming is pure ornament, so a rational player sorts by price and never reads anything. This is the exact degeneration Dealer's Life 2 was criticized for ("late game is just watching a number go up"), surfaced in our own alpha play. Pouring more hidden-clue content (the original Stage 2 plan) into a system where clues are ignored is filling a leaking bucket — fix the bucket first. The lever is not "make clues more visible," it is **decision-relevance**: a clue is worth reading only if reading it changes at least one decision.

This sketch supersedes and absorbs two existing `TODO.md ## Draft` entries — **Combination Naming Rules** (its combination→name mapping becomes the affix's preferred name) and **Anchor-Conditioned Surface Draw** (its "bias surface by structure" intent is now served by affix-owned combination tables instead of a per-pair weight matrix).

## Requirements

1. An item's display name is composed of drawn affixes (prefix / anchor body / suffix), and each affix deterministically constrains which clue-combinations the item can carry — so the name is a readable index into the item's possible contents, not a label applied after the fact.
2. Each affix owns a small table of clue-combinations; generating an affixed item draws exactly one combination from that table, which expands to that combination's surface + hidden clues. This is the reversal: combination → clues, replacing today's independent uniform surface/hidden draws.
3. Combinations under the same affix must **share some surface clues (symptoms) and differ on distinguishing clues** — revealing a shared clue does not collapse the hypothesis, revealing a distinguishing clue locks the posterior. The shared/distinct overlap ratio is the suspense knob and must be an authored property, not an accident.
4. The data model supports an arbitrary number of prefixes and suffixes on one item; the current generation policy draws at most 0–1 prefix and 0–1 suffix, kept sparse so most items are plain (mediocre = fast skip) and a two-affix item is rare and visually loud. Conflicting affixes are blocked by exclusive groups; any conflict that survives is narrative ("a suspicious modern lamp"), never a numeric contradiction.
5. The player learns affixes through a **dictionary**: one page per affix, one slot per combination. A slot fills only when the player has *verified* an item of that combination, revealing its real clue makeup and effects. Unverified combinations show as visible blank slots — the blanks are themselves information (you can see how many possibilities remain).
6. The dictionary records **personal verified experience, never an auto-solver**: it shows "you've encountered 7 *suspicious* items, 5 opened as forgeries," not "suspicious = these clues." It must never collapse a live hypothesis for the player by displaying the answer.
7. Probability assistance is tiered to give **prior, not precise posterior**: Mastery unlocks "which combinations exist under this affix" (seeing the blanks); a perk gives a qualitative lean ("smells like a fake"); exact percentages come only from the player's own verified-sample stats in the dictionary. The system never hands over a precise live posterior like "30% antique / 70% forgery."
8. Affixed items are priced at auction near their **naive (blind-buy) expected value**, so a player who can't read the table loses slightly over time and a player who can — using inspect AP to buy discriminating evidence and cherry-pick — converts that edge into profit. Every dictionary slot filled measurably shifts the player's EV curve upward.
9. Naming is refactored away from per-clue `naming_slot` + `naming_priority` override (100+ names with weak, mutually-overriding priority) toward **affix-only naming**: the display name is composed purely from the attached affixes' names plus the anchor body, and clues no longer participate in naming at all. Because the name reveals exactly the affix set, the player reads it to infer the *set of possible combinations* under each affix — and then bets on which one they actually hold. Small enough vocabulary to memorize, large enough to feel like expertise.

## Design

### The grammar/material split

Learnability is compression. Pure random assembly (today's uniform draw over 30 anchors × 184 clues) has maximum entropy — nothing to learn, so reading one clue has near-zero posterior value and the summed number always wins. The fix is to inject *compressible structure* the player's brain can grow a grammar around. The split:

- **Grammar (hand-designed, deliberately small):** the affix list (each affix is a name), each affix's combination table, and the shared-vs-distinguishing clue layout. This is the thing the player memorizes — keep it tight (5–8 affixes for playtest, ~20 for full Stage 2).
- **Material (LLM → YAML → tres, mass-produced):** flavor text, clue descriptions, anchor variants. Unbounded volume is fine here because the player doesn't memorize it.

Players learn grammar, not vocabulary. This also dissolves the Stage 2 content anxiety: the real design work is a small affix/combination table, not hundreds of authored clue lines.

### Worked example — the "Suspicious" (可疑的) prefix

A "Suspicious" affix is just a set of clue-combinations — each combination is an array of clues the draw picks as a unit, with no authored identity beyond its contents (surface clues plain, **hidden clue bold**):

- (Smudged Label, **Counterfeit**)
- (Smudged Label, **Genuine Antique**)
- (Repair Marks, Later Restoration *(hard surface)*, **Historical Artifact**)

**Smudged Label** is the shared symptom — the first two combinations both carry it, so revealing it does *not* tell the player which one they hold. **Repair Marks** appears only in the third, so revealing it immediately locks the posterior to that combination. So inspect AP is spent buying the *discriminating* clue, not just "one more clue for a bit more value." If surfaces never overlapped, the first reveal would end the bet too fast; if they fully overlapped, inspect would be pointless and the player could only wait for Authenticate. Overlap is the dial.

The "Modern" (現代的) prefix is the contrasting cheap-tell: Mass-Produced / Replica / Reissue / Reprint — a cluster of low-value combinations the experienced player learns to skip on sight.

### Pair correlation is conditional, not a lookup

Where a surface clue correlates with a hidden pool, make it **conditional probability, not a deterministic table**: surface X lands ~60–75% in hidden pool Y, with the tail occasionally a reversal (the rare genuine article among the fakes, or the high-quality forgery). If the table were deterministic, learning it would turn Authenticate from a bet back into a dictionary lookup — just moving "sort by number" up one level. Rarity tunes the fidelity: low-rarity affixes pair honestly, high-rarity affixes deliberately muddy the water. Poker players know every odd and every hand is still tense — that's the target state.

### Conflict authority — one source of truth

Two affixes can co-occur (one prefix + one suffix), so their clue sets merge — which raises the question of what stops two contradictory clues landing on the same item. The answer: **the clue-level `exclusive_group` is the sole authority**, and there is deliberately no affix-level conflict field. A clue `exclusive_group` states a hard fact about an object ("serial filed off" and "intact factory serial" cannot both be true); that invariant must hold no matter how the clues arrived. An affix-level exclusive list would be a coarser, parallel, hand-maintained rule that drifts out of sync — exactly the rot we're avoiding — so it's dropped.

Enforcement is two-tier but single-rule. A build-time validator walks every legal affix pair × their combination cross-product and asserts the merged clue set never doubles a clue `exclusive_group` and never collides two overrides. Because the draw can only ever produce a subset of what the validator already cleared, a green build is *complete* — the runtime draw-time check is pure insurance (see Sketch). The one thing this design gives up is purely-thematic affix conflict with no clue basis (a "waterlogged" + "mint-in-box" name that's silly but not clue-contradictory); the intended fix is to ground that incompatibility in a real shared clue `exclusive_group`, keeping a single source of truth. A hard affix-pair ban with no clue basis can be added back later in one field if it's ever actually needed.

### The knowledge economy

The auction price of an affixed item anchors near its naive EV. The blind player breaks even-to-slightly-negative long term; the knowledgeable player reads the affix, spends inspect AP to push the posterior, and buys only the favorable bets — turning information asymmetry into realized profit. Each dictionary slot the player fills is a permanent, measurable upward shift in their EV curve. That is the core fantasy made mechanical: better sight literally pays.

## Sketch (non-normative)

Names below are proposals; the implementer renames to match conventions on the ground. References to existing code are recalled, not verified — the codebase wins every disagreement.

### Schema — promote the affix to a first-class designer resource

New `data/definitions/affix_data.gd` (`AffixData extends Resource`), authored in `data/yaml/affixes/`, generated to `data/tres/affixes/`:

```
# affix_data.gd
affix_id: String              # "suspicious"
naming_slot: String           # "prefix" | "suffix"  (anchor stays the body)
display_name: String          # "Suspicious"
category_scope: Array[String] # category_ids this affix can attach to ("" = generic)
rarity_weight: int            # how often this affix appears at all (sparse by default)
combinations: Array[AffixCombination]

# AffixCombination (inner resource or sub-dict)
combination_id: String        # "suspicious_forgery" — internal id only, never shown to the player
weight: int                   # draw weight within the affix
surface_clue_ids: Array[String]   # includes the shared symptoms
hidden_clue_ids: Array[String]
```

The name lives on the affix (`display_name` + `naming_slot`), never on the combination — every combination under an affix shares the same name, which is exactly what makes the name an index into a *set* of possibilities rather than an answer. The existing per-clue `naming_slot` / `naming_priority` fields (seen in `clue_data.gd`) are **removed**: clues no longer participate in naming at all.

### Generator — reverse the draw order

`item_generator.gd::draw()` today goes anchor → uniform surface → rarity → constrained hidden. Reverse to **category → anchor → affixes → per-affix combination → clues**:

```
func draw(category, tier_weights, rarity_weights, ..., rng):
    result.anchor = _draw_anchor(category, tier_weights, rng)
    var affixes := _draw_affixes(category, rng)        # per-slot draw, sparse; re-picks a combination / drops an affix on clue-conflict (see below)
    for affix in affixes:
        var combo := _pick_combination(affix, rng)      # weighted within the affix
        result.surface_clues += _resolve(combo.surface_clue_ids)
        result.hidden_clues  += _resolve(combo.hidden_clue_ids)
    # plain (no-affix) items: fall back to a thin baseline surface draw, no hidden
    result.affixes = affixes                             # carried so naming + dictionary can index
    return result
```

**Capacity vs. draw policy are separate concerns.** The data model and naming composer must support an *arbitrary* number of prefixes and suffixes on one item (e.g. 3 suffixes + 2 prefixes) — `result.affixes` is an unbounded list and the name composer concatenates however many it's handed. The *generation* policy is the throttle: for now `_draw_affixes` draws **at most 0–1 prefix and 0–1 suffix** (so an item has zero, one, or at most two affixes), kept sparse. Widening the draw to multi-affix items later is a policy change in `_draw_affixes` alone — the schema, composer, and dictionary need no change.

**Hidden clues and rarity become downstream of the combination.** Today hidden clues are drawn independently by a rarity roll (`_pick_rarity` over a `rarity_weights` table, then `_draw_hidden_clues(count)`), and `ItemEntry.rarity` is defined as the hidden-clue count. Under the affix model, hidden clues arrive *only* from drawn combinations, so that whole rarity-roll path is **retired** for generation: a plain (no-affix) item carries no hidden clues and is therefore always the lowest rarity, while an affixed item's rarity falls out of how many hidden clues its combination(s) carry. The `rarity` mechanism itself (count → tier) is unchanged; only its *source* moves. Affix appearance frequency is governed by each affix's own `rarity_weight` and is global for now — lot-level biasing of affix frequency (the old role of `LotData.rarity_weights`) is out of scope for the playtest cut.

**Conflict handling at draw time is insurance, not the guarantee.** There is no affix-level `exclusive_group` — conflicts are owned entirely by the clue layer (see Design). The validator is exhaustive, so a green build can never *draw* a conflicting pair. The draw-time check is belt-and-suspenders against shipping without re-running the validator or against data drift: after merging the two affixes' clues, if any clue-level `exclusive_group` is doubled (or two overrides collide), **re-pick one affix's combination or drop an affix** — never strip an individual clue, which would corrupt that combination's meaning (its dictionary slot, its surface/hidden balance).

`GenerationResult` grows an `affixes: Array[AffixData]` field (plus the chosen `combination_id`s) so the display-name composer and the dictionary can index by them. The old `_draw_surface_clues` / `_draw_hidden_clues` uniform pools remain only for the plain-item baseline.

### Display-name composition

Compose purely from affix slots: `prefix(es) + anchor body + suffix(es)`. The name is fully determined by the attached affixes' `display_name`s and the anchor — clues and combinations contribute nothing, so a plain (no-affix) item is just its anchor name. The validator already proves composed == authored for the affix-naming system (per the existing Draft note); keep that check pointed at the affix-only path.

### Dictionary (read-only panel first)

A Knowledge sub-scene: one page per `AffixData`, a grid of slots = its `combinations`. Slot state derived from owned/verified `ItemEntry` history (likely via `KnowledgeManager`): filled slot shows real clue makeup + effects + personal sample count ("seen 7, 5 forgeries"); unverified slot shows a blank with the combination locked. Verified-on-contact filling means collection is a byproduct of normal play, not a separate grind. Strictly read-only — it never displays an answer for an unverified live item.

### Scope split — playtest build vs Stage 2

Playtest-build cut (the thing being validated): 5–8 affixes, 2–3 combinations each, generator draw-order reversal, display-name composition, dictionary as a **read-only** panel. Everything else is Stage 2 content/polish and must not block playtest.

### Migration / step order

1. **(Blocker, unrelated) Export Presets + tres bootstrap** — do this first; it's the build blocker from `itchio_review.md` and gives a shippable build at any point during the refactor.
2. `AffixData` schema + YAML pipeline (validate / yaml_to_tres / stats) + 5–8 authored playtest affixes. Extend the validator with the **cross-product conflict check**: for every legal affix pair × their combination cross-product, assert the merged clue set never doubles a clue `exclusive_group` and never collides two overrides. This is the build-time guarantee that replaces an affix-level conflict field.
3. Generator draw-order reversal + `GenerationResult.affixes`, plus the draw-time insurance check (on a merged-clue conflict, re-pick a combination or drop an affix — never strip a clue).
4. Affix-only display-name composition; remove the per-clue `naming_slot` / `naming_priority` fields; keep the naming validator on the affix path.
5. Dictionary read-only panel keyed off verified history.
6. Tutorial + Director injection **last** — tutorial step copy references affixes ("notice this *suspicious* item"), so writing it earlier means rewriting it.

## Non-Goals

1. **Info-content / EV validator** (`balance_preview.py` upgrade: simulate 10k draws, report per-clue posterior narrowing, and blind-buy-EV vs perfect-info-EV per affix to price the value of knowledge and flag dead affixes) — Stage 2.
2. **Dictionary sample statistics and the probability-lean perk** (qualitative "smells like a fake", verified-sample percentages) — Stage 2; the playtest panel is presence/absence of slots only.
3. **The full ~20-affix grammar** and exhaustive hidden-clue content — Stage 2 content work; playtest ships the thin cut.
4. **NPC bid-behavior as information leakage** (an expert NPC biting on a lot is itself a clue) — Stage 2 late / Stage 3.
5. Any change to the `item_price` pipeline or `SellMath` — the value-as-range presentation layer is already in place and is not touched here.

## Acceptance Criteria

1. Generating an affixed item produces clues drawn from that affix's combination table — not from the global uniform pools — and two items sharing an affix share their authored symptom clues while differing on the distinguishing clue.
2. The displayed name of an affixed item is composed purely from its attached affixes plus the anchor, and lets a knowledgeable player narrow the item's possible clue contents *before* inspecting; two items with the same affix set share the same name regardless of which combination they hold.
3. Under the current draw policy a generated item carries at most one prefix and one suffix; most are plain, two-affix items are rare, and conflicting affixes never co-occur on the same item. (The schema and name composer still accept arbitrarily many affixes — only the draw is throttled.)
4. The dictionary shows filled slots only for combinations the player has verified, and shows remaining possibilities as visible blanks; it never reveals the makeup of an unverified item the player currently holds.
5. In an unprompted playtest, testers begin reading item names to inform bidding and voluntarily choose to gamble on hidden clues via Authenticate — the two behavior signals this whole refactor exists to produce. (This is the single pass/fail bar; anything not serving it is Stage 2.)
