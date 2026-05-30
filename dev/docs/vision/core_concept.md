# Lot & Haul — Core Concept

> **Level 1 (vision).** The whole-game idea in one read. This changes almost never. It deliberately holds no mechanics detail, numbers, or system names — those live in L2 (`../systems/`) and L3 (code docstrings). If something here would break when a formula or scene is renamed, it's in the wrong layer.

## The fantasy

You are a storage-lot hunter. You walk a row of padlocked units you're only allowed to *glance* into, size up what might be inside, and bid against rivals for the whole lot sight-mostly-unseen. Then you haul your winnings home, restore and study them, and sell to the right buyers. It's "Storage Wars" rebuilt as a strategy/management game: the thrill isn't combat or speed, it's **judgement under uncertainty**.

## The one tension everything serves

**You always act on incomplete information, and the truth arrives later.** At the auction you can only partially inspect a lot, so every bid is a bet on what you think is there. The real identity and value of an item only resolve after you've already paid for it — through inspection, research, and authentication back home. A lot you overpaid for can turn out to be treasure; a confident buy can turn out to be junk. That gap between *appraised* and *true* value is the heart of the game. Every system exists to widen, narrow, or help you reason about that gap.

## The loop, conceptually

The game alternates between two moods:

- **On the road (a run)** — high tension. Travel to a location, scan the lots, spend a
  limited inspection budget to peek at clues, then commit real money in an auction. What
  you win, you load and haul back.
- **At home (the hub)** — calm and deliberate. Cargo becomes inventory. You repair,
  restore, and authenticate to turn *uncertain* items into *known* ones, you invest in
  your own abilities, and you sell to buyers whose tastes you learn to read. Then you
  decide what the next run looks like.

The rhythm is *gamble → reveal → consolidate → gamble again*. The reveal is the payoff beat; the consolidation is where skill compounds.

## Why it's fun (the pillars to protect)

- **The reveal.** The moment hidden value resolves — for better or worse — is the
  game's core dopamine hit. Mechanics should build toward it, not blunt it.
- **Reducing your own fog.** Growing as a hunter means the same lot becomes more legible
  to you over time. Progression is *better sight*, not just bigger numbers.
- **Reading the market and the room.** Knowing who buys what, and when value is worth
  banking vs. holding, is a skill the player develops — the game shouldn't hand it over.
- **Meaningful, recoverable risk.** A bad buy should sting without ending the run. The
  fun lives in the swing, so the floor must be survivable.

## What this game is *not*

Not a twitch/action game, not a pure economy spreadsheet, and not a game of perfect information. If a design choice removes uncertainty for free, makes value fully knowable before you pay, or turns judgement into a solved formula, it's working against the core.

---

See `../README.md` for how the three documentation levels fit together, and `../systems/` for how each of these ideas is actually built.
