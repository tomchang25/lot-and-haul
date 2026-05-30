# New Clue Types

**Status:** Exploring

Two candidate clue types beyond the current anchor/surface/hidden modifier model.

## Override clue

Replaces the anchor base price entirely when revealed during Research (e.g. a $200 "old clock" turns out to be a $15,000 Boulle original). Open: does it replace the anchor only or the full appraised value? Do surface adds still apply on top? Validation: hidden type only, max 1 per item.

## Conditional clue

A clue whose price effect depends on whether another specific clue is revealed:

```
if clue A revealed → apply effect_op P, effect_amount N
else               → apply effect_op T, effect_amount M
```

Open: evaluation order (reveal time vs. price-compute time), circular-reference risk, YAML representation, and "else" semantics when A is on the item but unrevealed vs. not present.
