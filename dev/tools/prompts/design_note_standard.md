# Design Note Standard

A design note is a record for your future self. It captures something about the
project — a problem, a decision, a direction — in a form that holds up without
surrounding context three months later.

Most notes do at least one of:

- Describe a problem, friction, or constraint you've hit.
- Record a decision and what it changes.

Some do both. Some do only one. That's fine.

---

## Format Rules

- One bolded title line. A noun phrase naming the feature, system, or topic —
  not a verb phrase like "fix the X".
- Body in prose. No `Why:` label. If the note has both a problem and a
  direction, separate them with a blank line, not a header.
- Sub-bullets are optional. Use them when concrete sub-pieces have been
  decided: bolded title, em dash, one to two sentences on what that piece looks
  like when done. Skip them entirely for problem-only or observation-only notes.
- Use `Open question:` for things you've identified as undecided. Don't hedge
  the surrounding prose — call the unknown out explicitly.
- No filenames, function names, or enum values. Implementation detail belongs
  in agent prompts, not here.
- No "should", "plan to", "consider". Write decided things, describe problems
  honestly, or flag open questions.

---

## Examples

### Decision with sub-goals

**Item knowledge & inspection overhaul**

The current system exposes too much structured information too cheaply. Players
can read layer depth, potential rating, and condition tier directly from the
item list, reducing all storage decisions to parameter comparison rather than
judgment under uncertainty. The fix is to make information feel earned and
lossy, not just locked behind a cost.

- **Accuracy-based display** — Condition and rarity are no longer revealed in
  discrete steps. A continuous accuracy value per item gates display resolution
  so coarse information comes cheap and precise information requires investment.

- **Rarity as the primary value signal** — Potential rating and layer depth are
  removed from the player-facing UI. Rarity replaces them as the main heuristic
  for whether an item is worth researching further.

### Problem-only

**Late-game cash glut**

Once the player unlocks two specialist merchants and starts hitting completion
bonuses on premium orders, daily cash income outpaces every available sink.
Bank interest is a rounding error at that scale, and storage upgrades aren't
recurring. The session loses tension around money decisions in a way the early
game doesn't.

### Direction with open question

**Negotiation auto-accept on small gaps**

The merchant counters on every submission regardless of how close the proposal
is to its current offer. When the player lands a few dollars above the standing
offer, the forced extra round produces no meaningful price movement while
burning a submission and trickling more anger — it punishes near-agreement.

- **Proximity-based acceptance** — When the player's proposal sits within a
  small margin of the merchant's current offer, the merchant accepts at the
  proposed price instead of countering. Outside that margin the existing
  anger-and-counter flow still runs.

Open question: the "small" threshold needs a definition — percentage of
gap-to-ceiling, flat dollar amount, or fraction of base offer. Each produces a
different feel at scale.
