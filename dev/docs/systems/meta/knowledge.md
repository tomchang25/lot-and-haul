# Knowledge

Meta system in `game/meta/knowledge/` and autoload `KnowledgeManager` — the player's progression as a lot hunter, split across three independent concerns (category Mastery, the five Attributes, and Perks).

> The old "three pillars (Mastery / Skill / Perk)" framing is gone. Phase 7 removed the skill system entirely; the five SPECIAL-style **attributes** took its place. There is no `SkillData` / `SkillLevelData`, no `try_upgrade_skill`, no skill gates.

## Goal

Give the player distinct progression axes that don't substitute for each other: time spent playing (mastery), cash deliberately invested (attributes), and content-granted privileges (perks). A grinder with high mastery still has weak appraisal dice; a player who pumped Investigation still hasn't earned any narrative perk.

## Reads

- `SaveManager.category_points` — mastery layer 1 (persisted)
- `SaveManager.attribute_levels` — per-attribute level, `attribute_id → int` (persisted)
- `SaveManager.unlocked_perks` — unlocked perk ids (persisted)
- `SaveManager.cash` — consumed by attribute upgrades
- `SuperCategoryRegistry.get_categories_for_super()` / `get_all_super_categories()` — used to aggregate super-category and mastery rank

## Writes

- `SaveManager.category_points` — accumulated via `add_category_points()`
- `SaveManager.attribute_levels` — incremented by `upgrade_attribute()`
- `SaveManager.unlocked_perks` — appended by `unlock_perk()`
- `SaveManager.cash` — debited by `upgrade_attribute()`

No scene transitions owned by this system directly; consumed by run scenes (inspection, reveal), the Storage research flow, and the Knowledge Hub UI.

## Feature Intro

### Data Definitions

`SaveManager` persists exactly three knowledge fields — category points (mastery layer 1), attribute levels, and unlocked perk ids. Category rank, super-category rank, and mastery rank are all **derived on demand** from category points — no caching, no stored player level. (See `../shared/data_model.md` and `../shared/autoloads.md`.)

`AttributeData` and `PerkData` are designer resources (`data/definitions/*.gd`, instances under `data/tres/`); their fields live in `../shared/data_model.md` and the code. Two behavioural notes that matter here:

- An **attribute** is not a level-with-prerequisites resource like the old skills — it's a
  single scalar the player buys up, defaulting to 1. Attributes feed clue-discovery dice
  during inspection and research; they **do not gate anything** in `KnowledgeManager`.
- A **perk** is sourced from an attribute threshold: reaching the perk's required attribute
  value is the intended unlock trigger.

`KnowledgeManager` (autoload) is the API surface for all three concerns: mastery (grant category points, read the three derived ranks), attributes (read a value — defaulting to 1 when unset — and upgrade for a flat $1000/level), and perks (unlock and query). It also exposes a `KnowledgeAction` enum (Inspect / Reveal / Appraise / Repair / Sell / Restore) used to scale point gains, and the **public `RANK_THRESHOLDS` constant** the Mastery Panel reads for its progress display. It loads its perk and attribute registries at boot and registers with `RegistryCoordinator`, so its `validate()` (perk/attribute registries non-empty; every saved perk id resolves) runs at boot with the others. Signatures and the threshold/cost constants live in `knowledge_manager.gd`.

### Mastery — Four Derived Layers

Only the bottom layer is stored; everything above is computed on demand.

```
Category Points  ──►  Category Rank  ──►  Super-Category Rank  ──►  Mastery Rank
   (stored)         (step thresholds)      (sum of categories)      (sum of supers)
```

**Layer 1 — Category Points.** Persistent integer per category in `SaveManager.category_points`. Granted by `add_category_points()`; gain = `_BASE_MASTERY[action] * (rarity + 1)`. Base mastery per action: `INSPECT=2`, `REVEAL=1`, `APPRAISE=4`, `REPAIR=4`, `SELL=3`, `RESTORE=4`. Points never reset, never spend, never gate anything directly — they exist only to produce category rank.

**Layer 2 — Category Rank.** Step function over points, range 0–5, driven by the public `RANK_THRESHOLDS` constant:

| Points | Rank |
| ------ | ---- |
| 0      | 0    |
| 100    | 1    |
| 400    | 2    |
| 1600   | 3    |
| 6400   | 4    |
| 25600  | 5    |

`RANK_THRESHOLDS` is the public contract — the Mastery Panel reads it directly for its "points / next threshold" display. Note: `get_category_rank()` currently re-encodes these thresholds as a hard-coded if/elif ladder rather than looping over the constant; the two sources must stay in sync. Candidate for cleanup.

**Layer 3 — Super-Category Rank.** Sum of category ranks within a super-category. Reads `SuperCategoryRegistry.get_categories_for_super()`.

**Layer 4 — Mastery Rank.** Global level shown in the hub header. Sum of all super-category ranks. Reserved for future content gates (prestige, tier-locked auction houses, NPC reaction tiers).

### Attributes (replaces skills)

Five SPECIAL-style stats — **Appraisal, Perception, Restoration, Negotiation, Investigation** — each a single scalar with a starting value of 1. They are the active, cash-spent progression axis that replaced the old skill ladder. Their job is to bias the clue-discovery dice (and the restore math) during inspection and research; the higher the relevant attribute, the better the player's odds of revealing surface clues and the stronger restore gains. **Attributes do not gate anything in `KnowledgeManager`** — they are read at roll time by the inspection / research systems.

Upgrade model (`upgrade_attribute()`): flat **$1000 per level**, no prerequisites, instant (no day tick). The call debits cash, increments the stored level, saves, and returns `false` if the attribute id is unknown or the player can't afford it. There is no max level in code today.

### Perks

Binary unlocks. Each `PerkData` declares a `required_attribute` + `required_attribute_value` threshold; reaching that attribute value is the intended acquisition trigger. `unlock_perk(perk)` appends to `SaveManager.unlocked_perks` (idempotent + save); `has_perk()` / `has_perk_by_id()` are flat lookups. Perks are not purchased directly with cash like attributes — they are granted when their attribute threshold is met (or by content).

### Knowledge Hub Navigation

`game/meta/knowledge/` is a sub-group under `game/meta/` (parallel to `hub/`). The parent scene `knowledge_hub.gd` / `knowledge_hub.tscn` routes to three standalone sub-panels:

- **Mastery Panel** (`mastery_panel/`) — read-only: mastery rank, super-category ranks, category point progress.
- **Attributes Panel** — the five attributes with current values and a $1000 upgrade button per attribute (disabled when cash is short).
- **Perk Panel** (`perk_panel/`) — read-only: unlocked vs locked perks, showing each perk's attribute threshold.

Back from any sub-panel returns to Knowledge Hub via `GameManager.go_to_knowledge_hub()`. Back from Knowledge Hub returns to Hub.

## Notes

### Why the three concerns are separate

- **Mastery is the residue of play.** No decision required; reflects time spent in a category.
- **Attributes are the spend.** Active cash investment; bias the clue dice and restore math. Reflect deliberate stat-building.
- **Perks are the gift.** Granted at attribute thresholds (or by content); reflect narrative / milestone position.


