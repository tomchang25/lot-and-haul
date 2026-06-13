# Clue Information Validator

## Goal

Add an affix-aware balance preview mode that measures whether each revealed clue actually changes the player's value estimate. The current balance view catches broad price-distribution problems, but it does not catch clue content that is mechanically present yet carries little or no information.

## Requirements

1. The validator must simulate generated items through the current affix/combination structure, because clue information now comes from both direct price effects and the hypotheses implied by an affix's weighted combination table.
2. The report must keep the existing whole-pool value-distribution view, then add per-clue information metrics so content authors can see which clues are decision-relevant and which are decorative noise.
3. A clue's usefulness is measured by how much revealing it changes the posterior value distribution for matching generated items, not only by the clue's direct `effect_amount`. A low direct modifier can still be useful when it strongly distinguishes a valuable hidden tail.
4. Low-information clues should warn first, not hard-fail. Some clues may be retained for naming, demand tags, tutorial readability, or genre texture, but the tool should make that trade visible instead of relying on gut feel.
5. The tool should support stable seeded runs so balance changes can be compared before and after content edits.

## Design

The useful signal is "how much uncertainty did this clue remove?" For each clue, compare the prior value distribution for the population where that clue could plausibly appear against the posterior value distribution after the clue is known to be present. Report shrinkage in spread and any expected-value shift, because both matter: a clue can be useful by narrowing risk or by revealing that the item is much better/worse than the prior.

Use soft thresholds for the first pass. A practical initial warning band is "appears often enough to judge, but reduces p10-p90 spread by less than roughly 5% and shifts mean value by less than roughly 5%." The exact numbers are tuning knobs; the important contract is that low-signal clues are surfaced for review instead of silently bloating the content pool.

The validator is especially valuable before a large clue or affix content pass. It turns "does this clue have presence?" into a repeatable gate: keep high-signal clues, merge redundant clues, reweight combinations whose tells are too obvious or too flat, and cut content that only adds words.

## Sketch (non-normative)

Start by bringing `dev/tools/balance_preview.py` back into alignment with the runtime generator: load `data/yaml/affixes.yaml`, draw prefix/suffix affixes by weight, draw one weighted combination per affix, and build surface/hidden clue sets from those combinations. Keep the plain-item fallback only for no-affix items. Do not rely on `rarity_weights` for generated rarity; hidden clue count falls out of the drawn combinations.

Each simulated draw should retain enough provenance to evaluate information:

```python
@dataclass
class DrawResult:
    anchor_id: str
    category_id: str
    affix_ids: list[str]
    combination_ids: list[str]
    surface_ids: list[str]
    hidden_ids: list[str]
    prior_value: float
    full_true_value: float
```

For a first implementation, use `full_true_value` as the resolved value distribution being narrowed. Later, a second mode can measure "currently appraised value after this reveal" if inspection UI tuning needs it.

Per clue:

```python
all_values = [r.full_true_value for r in relevant_draws]
posterior_values = [r.full_true_value for r in relevant_draws if clue_id in r.surface_ids or clue_id in r.hidden_ids]
spread_before = p90(all_values) - p10(all_values)
spread_after = p90(posterior_values) - p10(posterior_values)
spread_shrink = 1.0 - spread_after / spread_before
mean_shift = abs(mean(posterior_values) - mean(all_values)) / max(mean(all_values), 1.0)
```

"Relevant draws" should start as same-category draws, because cross-category value bands differ so much that category mix can drown out clue signal. Add an affix-scoped view when useful: for clues owned by affix combinations, compare against draws carrying the same affix set so the report answers "once I know this item is Rustic, did this clue distinguish which Rustic branch I am in?"

Suggested report shape:

```text
Clue information, category=handbag
  bag_exterior_faded: n=812 shrink=0.41 mean_shift=-0.18 verdict=ok
  bag_hardware_tarnished: n=812 shrink=0.02 mean_shift=-0.01 verdict=low-info
  bag_override_replica: n=184 shrink=0.73 mean_shift=-0.62 verdict=ok
```

JSON output should include raw counts, p10/p50/p90 before and after, spread shrink, mean shift, affix scope if applicable, and verdict. Keep warnings soft in stdout so the tool can be used during authoring without blocking every experimental content edit.

## Non-Goals

1. Repricing auction lots directly from the information metrics. The first pass measures clue quality; pricing policy can use the data later.
2. Building a live player-facing posterior assistant. The dictionary remains experiential; this tool is offline authoring QA.
3. Solving final clue wording or merge decisions automatically. The report flags candidates, and the designer chooses whether to cut, merge, reweight, or deliberately keep a low-signal clue.

## Acceptance Criteria

1. Running the preview with a fixed seed produces stable per-clue information metrics across repeated runs.
2. The value-distribution summary still reports broad appraised and true-value health, while the new section reports per-clue posterior narrowing and expected-value shift.
3. A clue that appears frequently but barely changes the relevant value distribution is called out as low-information.
4. A clue with a small direct modifier but strong correlation to a valuable or dangerous hidden branch is not falsely treated as noise.
5. The simulated generation path matches the affix/combination draw structure used by the game, including plain no-affix fallback and hidden-count-derived rarity.
