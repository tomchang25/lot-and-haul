# Lot & Haul — Data Architecture

> **Level 1 (vision).** The whole-project organizing principle for how data is authored and how it lives at runtime. This is the conceptual layer; mechanics, formulas, and field names live in L2 (`../systems/`) and L3 (code docstrings). If renaming a class or field would make something here wrong, it is in the wrong layer.

## Two Layers, One Separation

All data in the game lives in exactly two layers:

**Designer resources** are authored, immutable, and loaded at boot. They express what things *are* — categories, items, clues, locations, cars, perks, attributes — defined by the designer and never touched at runtime. They live as `.tres` files under `data/tres/`, generated from YAML source via the data pipeline. They never change during a session.

**Runtime types** are per-instance, mutable, and save-serialized. They express what the *player knows and owns* — which items are in storage, what clues have been revealed, how much cash is on hand, what condition an item is in. They are created, mutated, and destroyed during play. They are the game state.

The separation is what makes the game's core mechanic work: the designer decides what an item *truly is* (value, hidden identity, real name) once; the runtime layer tracks only what the *player has discovered so far*. The gap between the two is uncertainty — the thing the whole game is about.

## The Designer-Resource Ownership Chain

Designer resources form a hierarchy from broad to specific:

```
SuperCategoryData  ←  CategoryData  ←  ItemData  →  Array[ClueData]
```

- A **super-category** groups related categories (Decorative, Fashion, Weapon, Fine Art).
- A **category** defines a class of items: its physical properties (weight, cargo shape) and the category-mastery axis.
- An **item** is one authored thing: its true name, rarity, category membership, and an ordered list of clues (one anchor, then surface, then hidden). True value derives entirely from the clue stack — there is no separate price field.
- A **clue** is the atomic unit of both identity and value: a type (anchor / surface / hidden), the attribute and DC governing discovery, a price effect, and an optional naming slot.

Lookup always goes through the dedicated registry — `CategoryRegistry` for category questions, `SuperCategoryRegistry` for super-category questions. Scanning `ItemRegistry` to answer a category question is a violation of this chain.

## What the Runtime Layer Tracks

The runtime layer never duplicates what the designer encoded. It tracks only the player's *partial knowledge* of each item and the mutable state that results from decisions:

- Which clues have been revealed (and therefore what value and name can be *computed*).
- Whether the anchor clue has been seen (veiled vs. unveiled).
- Whether all hidden clues have been revealed (unverified vs. verified).
- Condition — a mutable float that changes with repair and restoration.
- Research progress toward revealing each hidden clue.

Everything else — the true name, the full value, the item's category, rarity — is read off the designer resource on demand. Runtime state is the minimum needed to reconstruct the player's view of any item at any point.

## Why This Matters for Every System

Any system that shows an item to the player must read display values through the runtime type's computed getters, never directly off the designer resource. That is what enforces the information veil: veiled items return `"???"` and hidden values remain invisible until earned. The designer resource is always there in full; the player only *sees* what the runtime state says they've revealed.

---

See `../systems/item_system.md` for the item lifecycle (creation → inspection → research → selling) and `../README.md` for the three-level documentation model and the runtime-type archetype taxonomy (Entry, Store, Snapshot, Service).
