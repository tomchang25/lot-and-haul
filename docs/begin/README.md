# Lot & Haul — Project Overview

A single-run auction scavenging game. The player visits a warehouse, inspects items
with limited stamina, bids on the entire lot, loads what fits, and returns home to
reveal the true value of everything they hauled.

---

## Core Loop

```
Warehouse Entry → Inspection → List Review → Auction Bid → Cargo Loading → Home Appraisal
```

Each stage passes data forward through `GameManager`. No stage can reach back.

---

## Block Index

| File | Stage |
|---|---|
| `block_01_item_data.md` | Item Data (foundation) |
| `run_warehouse.md` | Warehouse Entry (atmosphere + run init) |
| `block_02_inspection.md` | Inspection (stamina + clue system) |
| `block_03_list_review.md` | List Review (bridge UI) |
| `block_04_auction.md` | Auction Bid |
| `block_05_cargo.md` | Cargo Loading |
| `block_06_home_appraisal.md` | Home Appraisal + Final Settlement |

---

## Global Data Flow

```
GameManager (autoload)
    item_entries: Array[ItemEntry]      generated at run start (replaces current_lot + inspection_results)
    lot_result: Dictionary              written by Block 04 (Auction)
    cargo_items: Array[ItemEntry]       written by Block 05 (Cargo Loading)
    run_result: Dictionary              written by Block 06 (Home Appraisal)
```

Blocks execute in order. Each block reads from `GameManager` and writes its result
back before handing control to the next stage.

---

## Hard Constraints (Vertical Slice)

- 4 items only, hardcoded
- Stamina fixed at 8
- Knowledge level fixed at 0 (beginner), no upgrades
- NPC bid price = sum of all true values x 0.75, no randomness
- Cargo limit: 6 items, 20 kg total
- No shipping, no selling on-site, no drag-and-drop
- No save system, no animations, no audio
