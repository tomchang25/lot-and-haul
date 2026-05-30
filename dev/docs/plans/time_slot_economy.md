# Time-slot day structure & storage AP economy

**Status:** Committed

The current hub phase has two problems. Storage actions run on a passive day-counter with no player agency beyond assignment — the player clicks "next day" and waits for completion timers to tick down. Meanwhile, the run/hub boundary is binary: the player either goes to an auction (consuming the entire day) or stays home with nothing interesting to do besides advance timers.

The fix is a time-slot day model. Each day has three slots (morning, afternoon, evening). The player allocates slots to one of three activities, creating a daily resource-allocation decision with meaningful trade-offs.

- **Auction** — Available only from morning. Consumes morning and afternoon (two slots). The player returns in the evening with one slot remaining. Only one auction per day.

- **Storage maintenance** — The player spends AP to perform hands-on work: Repair (condition toward 0.5), Restore (condition toward 1.0), and Research (reveal one hidden clue per attempt). Each action costs AP rather than running on a day timer. The storage AP pool refreshes daily. This replaces the current day-counter model for all three storage actions.

- **Open shop** — Ends the day immediately. Customer count scales with remaining slots: one slot yields a base number of customers, two consecutive slots yield more, and three consecutive slots yield the most. A bonus-customer incentive rewards dedicating the full day to selling. This replaces the current nightly-customer model where customer count is independent of player choice.

The core tension: going to auction eats two slots, leaving only one for either storage work or a small shop window. Skipping auction gives three slots — enough for heavy storage maintenance, a full shop day, or a mix. The player must weigh acquiring new inventory against processing existing stock and generating revenue.

- **Storage AP replaces day counters** — Repair, Restore, and Research all consume AP from a shared daily pool rather than ticking down over calendar days. This gives the player granular control and creates interesting per-day budgeting. An item that previously took "3 days to authenticate" now takes a comparable total AP across however many days the player chooses to invest.

- **Shop customer scaling** — Consecutive time slots dedicated to selling produce a non-linear customer bonus. This rewards committing to a full shop day but makes the one-slot evening shop (after an auction day) still viable with fewer customers.

Open question: does the storage AP pool share with inspection AP, or are they separate resource pools? A shared pool would create tension between thorough inspection during auctions and having AP left for evening storage work. Separate pools keep the two activities independent but add another number to track.

Open question: how does the daily AP pool size scale with progression? Flat amount, attribute-derived, or unlockable via upgrades? Starting assumption is a flat amount, revisited after the base flow is playable.

Open question: exact customer count curves per slot configuration. Starting assumptions — one slot: 2–3 customers; two consecutive slots: 5–7 customers (base + bonus 1–2); three consecutive slots: 8–12 customers (base + bonus 2–4). These numbers need playtesting.
