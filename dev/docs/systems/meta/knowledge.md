# Knowledge

Meta system in `game/meta/knowledge/` and autoload `KnowledgeManager` — the player's progression as a lot hunter, split across three independent concerns: category Mastery, the five Attributes, and Perks.

## Goal

Give the player distinct progression axes that don't substitute for each other: time spent playing (mastery), cash deliberately invested (attributes), and content-granted privileges (perks). A grinder with high mastery still has weak appraisal dice; a player who pumped Investigation still hasn't earned any narrative perk. The three axes stay separate by design.

## Why They're Separate

- **Mastery** is the residue of play — no decision required; reflects time spent in a category. Categories accumulate points via inspection, reveal, sell, repair, restore actions; points derive a category rank (0–5), which rolls up to a super-category rank, which sums to the global Mastery Rank shown in the hub header. Only category points are persisted; all higher ranks are computed on demand.
- **Attributes** are the spend — active cash investment that biases clue-discovery dice and the restore math. The five SPECIAL-style attributes (Appraisal, Perception, Restoration, Negotiation, Investigation) replace the old skill ladder. Attributes do **not** gate anything in `KnowledgeManager`; they are read at roll time by inspection and storage-research systems.
- **Perks** are the gift — granted at attribute thresholds (or by content). Each `PerkData` declares a required attribute + value; reaching that threshold is the intended trigger. Perks are binary unlocks, not purchased directly.

## Mastery Layer Architecture

Only the bottom layer is stored; everything above is computed on demand:

```
Category Points  ──►  Category Rank  ──►  Super-Category Rank  ──►  Mastery Rank
   (stored)         (step thresholds)      (sum of categories)      (sum of supers)
```

The public `RANK_THRESHOLDS` constant on `KnowledgeManager` is the single source for the step-function thresholds — both the internal rank computation and the Mastery Panel's "points / next threshold" display read it. These two consumers must stay in sync. See `knowledge_manager.gd` for threshold values and the upgrade cost constant.

## Knowledge Hub Navigation

`knowledge_hub.gd` routes to three standalone sub-panels: **Mastery** (read-only: rank + per-category progress), **Attributes** (per-attribute values + upgrade button), **Perk** (read-only: unlocked vs. locked, showing each perk's attribute threshold). Back from any sub-panel returns to Knowledge Hub; back from Knowledge Hub returns to Hub.
