# Roadmap Entry Standard

A roadmap entry is a decision record, not a spec. Every entry answers the same
two questions.

**Why** — What problem exists, what constraint changed, or why this decision
was made. One to three sentences. Should be legible to yourself three months
from now without any other context.

**Goal** — What the system's behavior or the player's experience looks like
once this entry is resolved. Describe the outcome, not the approach.

---

## Format Rules

- One bolded title line, feature name only.
- `Why:` label followed by prose. Sub-bullets for Goal — each bullet is one
  named sub-goal, bolded title, em dash, then one to two sentences on what that
  piece looks like when done.
- No filenames, function names, or enum values. Those are implementation detail
  and belong in the agent prompt, not here.
- No "should", "plan to", "consider" — write decided things.

---

## Example

**Item knowledge & inspection overhaul**

Why: The current system exposes too much structured information too cheaply.
Players can read layer depth, potential rating, and condition tier directly
from the item list, reducing all storage decisions to parameter comparison
rather than judgment under uncertainty. The goal is to make information feel
earned and lossy, not just locked behind a cost.

- **Accuracy-based display** — Condition and rarity are no longer revealed in
  discrete steps. A continuous accuracy value per item gates display resolution
  so coarse information comes cheap and precise information requires investment.

- **Rarity as the primary value signal** — Potential rating and layer depth are
  removed from the player-facing UI. Rarity replaces them as the main heuristic
  for whether an item is worth researching further.
