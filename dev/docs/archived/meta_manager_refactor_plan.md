# MetaManager Refactor — Implementation Handoff

> **Audience:** an implementation agent working in the Lot & Haul repo. This
> document is self-contained, but before writing code you should also read
> `dev/docs/archived/meta_domain_decomposition.md` — this refactor *finishes* the
> design started there (see §0).
>
> **Engine:** Godot 4.6, GDScript. `MetaManager` is the `MetaManager` Autoload
> (`global/autoload/meta_manager.gd`), holding six owned domain objects in
> `global/autoload/meta_manager/`.

---

## 0. What this refactor actually is (read this first)

The honest framing, because it changes where you spend effort:

1. **This is mostly *completing* an existing design, not a new one.**
   `meta_domain_decomposition.md` (archived) already split state into six domain
   *owners* and said each owner should expose "its domain fields **and the
   operations that mutate them**." The owners landed — but only the *fields*. The
   *operations* never moved out of `MetaManager`. So today's owners are anemic
   data bags and `MetaManager` still does all the arithmetic. **The win is moving
   the behavior the original design intended, not inventing a new architecture.**

2. **There is no active bug being fixed by "sealing."** A project-wide grep
   (`grep -rnE "MetaManager\.(cash|storage_items|…)\s*[-+*/]?=" --include=*.gd`)
   returns **zero external writes**. Every external reference to these fields is a
   *read* (UI display, slot checks, read-only iteration). No scene mutates a live
   collection either. So removing the proxy *setters* is **cheap preventive
   insurance against a future footgun**, not a fix for something broken today.
   Frame it that way; do not over-invest in it.

3. **The one change with real present-day value is removing nested saves (§3).**
   `resolve_run()` persists twice mid-transaction, so a crash can save a
   half-applied run. That is a concrete correctness issue. **Do it first.**

Priority order, highest value first: **single-commit saves → move behavior into
owners (consolidate each invariant to one place) → drop proxy setters (cheap
insurance).**

### Naming decision: keep `*Owner`

Do **not** rename the owner classes to `*Store`. The archived design deliberately
calls them "owners," the name is referenced across `class_name`, `.uid` files and
docs, and the rename buys zero behavior. We are adding behavior to the existing
`EconomyOwner`/`GarageOwner`/… classes, not replacing them. ("Store" appears in
this doc only as a concept; the GDScript classes stay `*Owner`.)

---

## 1. Context — what the code does

`MetaManager` is the hub-phase transactional authority for the meta loop. The day
is made of slots (Morning / Afternoon / Evening) plus an auction → storage →
open-shop flow. It currently owns the six domain *owners* but also holds all the
logic that mutates them.

Domains and their fields:

- **economy** — `cash` (`EconomyOwner`)
- **garage** — `active_car`, `owned_cars` (`GarageOwner`)
- **storage** — `storage_items` (Array of `ItemEntry`), `next_entry_id` (`StorageOwner`)
- **slot** — `current_slot`, `storage_ap`, `selling_slots_today`, `pending_run` (`SlotOwner`)
- **progress** — `current_day`, `available_locations` (`ProgressOwner`)
- **customers** — `nightly_customers`, `customer_sales_today` (`CustomersOwner`)

Each owner already implements `section_id()` / `to_dict()` / `from_dict()` and is
registered via `SaveManager.register_section(...)`. **Keep that.** Per-domain save
ownership is correct and already done.

---

## 2. Diagnosis — why the current shape is unsatisfactory

Two problems, in priority order.

### 2a. Behavior never moved (the real gap)

The owners are **anemic**: `EconomyOwner` holds `cash` and a save payload and
nothing else. All logic still lives in `MetaManager`, just spelled
`_economy.cash` instead of `cash`. The result is that each invariant (e.g. "cash
can't go negative," "AP is charged only after the effect lands") lives in
`MetaManager` rather than in the domain that owns the data. That's the
half-finished part of `meta_domain_decomposition.md`.

### 2b. Proxy setters are a latent leak (cheap to close)

`MetaManager` re-exposes all 13 fields as proxy properties **with public
setters** (`set(v): _economy.cash = v`). That means `MetaManager.cash = 999` is
*possible* and would bypass every guard. **It is not currently done anywhere** —
so this is a footgun to disarm, not a live wound. Closing it is cheap; just don't
let it dominate the work.

Additionally, for reference-type fields (`storage_items`, `owned_cars`, …) the
getter hands out the **live** collection. No external code mutates it today, but
the path exists (see §4's GDScript note).

**Conclusion:** the target is a **thin coordinator** plus **owners that hold their
data *and* the behavior that protects it** — which is what the archived design
already specified. Move behavior; then disarm the setters.

---

## 3. Remove nested saves (DO THIS FIRST — highest value, lowest risk)

Today several operations call `SaveManager.save()` at their own tail, and
`resolve_run()` calls `register_storage_items()` (which saves) and *then* keeps
mutating `pending_run` and `current_slot` before saving again. One logical
transaction becomes two persisted states; a crash between them persists a
half-applied run.

**Rule:** a transaction saves **exactly once, at its commit point.** Helpers used
inside a transaction must not save.

Introduce no-save internals and let only the public transaction save. Put the
no-save mutators on the owners (this is also the first slice of "move behavior"):

```gdscript
# StorageOwner — no save
func register_entry(entry: ItemEntry) -> void:
    entry.id = next_entry_id
    next_entry_id += 1
    storage_items.append(entry)
    if entry.item_data != null and entry.item_data.auto_verify:
        entry.reveal_all_hidden()

func register_entries(entries: Array) -> void:
    for e in entries:
        register_entry(e)
```

```gdscript
# MetaManager — single-domain op saves once
func register_storage_items(entries: Array[ItemEntry]) -> void:
    _storage.register_entries(entries)
    SaveManager.save()

# MetaManager — cross-domain transaction saves once, at the end
func resolve_run(record: RunRecord) -> void:
    _economy.apply_delta(record.onsite_proceeds - record.paid_price
        - record.entry_fee - record.fuel_cost)
    for entry in record.cargo_items:
        entry.auto_reveal_all_surface()
    _storage.register_entries(record.cargo_items)   # no inner save
    _slot.stash_pending_run(record)                 # no inner save
    _slot.set_slot(3)                               # no inner save
    RunManager.clear_run_state()
    SaveManager.save()                              # single commit
```

> GDScript has no rollback. "Save once at the end" does not give atomicity against
> a mid-method crash, but it guarantees what gets *persisted* is either the
> pre-transaction state or the fully-applied state — never a half-applied one.
> That is the achievable, correct guarantee.

*Verify:* play a full day cycle; confirm save fires once per logical action and
the day summary still reflects run + customer economics correctly. Then run lint
(see §8).

---

## 4. The GDScript constraint that shapes the rest

`Array`, `Dictionary`, and `Object` are **reference types**, so a getter that
returns the live collection is a disguised write path:

```gdscript
func get_storage_items() -> Array:
    return storage_items                          # returns the LIVE array
MetaManager.get_storage_items().erase(item)       # would mutate real storage
```

Therefore:

- **Reads of value types are harmless.** `MetaManager.cash` (an `int`) can be read
  forever — it can't break an invariant. Do **not** spend effort wrapping
  value-type reads.
- **Spend effort on eliminating external *writes*.** What breaks state is
  `cash += 100`, `storage_items.erase(...)`, `current_slot = 4` from *outside* the
  owning domain. (As noted in §0, none of these exist today — so this is about
  keeping the door shut, not chasing existing offenders.)
- For reference-type collections, **don't expose the live collection.** Expose
  operations (`remove_entries()`, `count()`, `get_by_id()`), or when a scene needs
  to iterate for display, return a **shallow duplicate** (`storage_items.duplicate()`
  — the `ItemEntry` objects stay shared, which is what you want for read-only
  display; callers must not mutate the returned array's membership).

The current display call sites (`storage_scene`, `customer_sell_scene`,
`car_shop_scene`, `hub_scene`) all iterate read-only today, so returning a
duplicate from a `get_*` accessor is a safe, non-breaking swap.

---

## 5. Target architecture

```
MetaManager  (thin coordinator / Autoload)
  - holds references to the six domain owners
  - owns ONLY cross-domain transactions (methods touching 2+ domains)
  - delegates single-domain operations to the relevant owner
  - performs exactly one SaveManager.save() at each transaction's commit point

EconomyOwner   (SaveSection)  cash + can_afford/spend/earn/apply_delta
GarageOwner    (SaveSection)  active_car/owned_cars + owns/add/set_active
StorageOwner   (SaveSection)  storage_items/next_entry_id + register/remove/count/get_by_id
SlotOwner      (SaveSection)  current_slot/storage_ap/selling_slots_today/pending_run + phase ops
ProgressOwner  (SaveSection)  current_day/available_locations + advance_day/set_locations
CustomersOwner (SaveSection)  nightly_customers/customer_sales_today + generate/record/remove
```

Each owner: owns its fields and its save payload; exposes methods that enforce its
own invariants; does **not** expose public setters for reference-type fields; does
**not** call `SaveManager.save()` itself (the coordinator commits — §3).

A coordinator that owns multi-domain transactions is **not** a God Object. A God
Object *also* holds all raw data publicly and lets outsiders mutate it. We keep
the coordinator and remove the God-Object traits.

> **Calculation stays put.** Price/rule math (`SellMath`, the repair/restore/
> research math in `ResearchSlot`) already lives outside `MetaManager`; scenes
> compute, `MetaManager` commits. This refactor does **not** move calculation —
> only data ownership and transaction boundaries.

---

## 6. Worked slice — economy (the template)

Smallest, cleanest domain. Three steps: **(a) give the owner behavior →
(b) route writes through it → (c) disarm the setter.**

### 6a. Behavior on the owner

```gdscript
# economy_owner.gd  (class_name EconomyOwner stays)
var cash: int = 0   # field name unchanged → save key "cash" unchanged

func can_afford(amount: int) -> bool:
    return cash >= amount

## Returns true if the spend happened. Refuses to go negative — the invariant
## EconomyOwner exists to protect.
func spend(amount: int) -> bool:
    assert(amount >= 0, "spend() expects a non-negative amount")
    if cash < amount:
        return false
    cash -= amount
    return true

func earn(amount: int) -> void:
    assert(amount >= 0, "earn() expects a non-negative amount")
    cash += amount

## For pre-validated transactions applying a signed delta atomically
## (e.g. resolve_run's proceeds minus costs). Use sparingly; prefer earn/spend.
func apply_delta(delta: int) -> void:
    cash += delta
```

> Keep the in-memory field named `cash` and the `to_dict`/`from_dict` key
> `"cash"` identical. **Do not change the save format.** (No `_cash` rename is
> needed — the owner is already a private object reached only through
> `MetaManager`, so the field is not part of any public surface that scenes see.)

### 6b. Route every cash write through the owner

In `MetaManager`:

| Location | Current | Becomes |
|---|---|---|
| `end_day` | `_economy.cash -= Economy.DAILY_BASE_COST` | `_economy.apply_delta(-Economy.DAILY_BASE_COST)` * |
| `resolve_customer_sale` | `_economy.cash += sale_price` | `_economy.earn(sale_price)` |
| `buy_car` | `_economy.cash -= car.price` (after check) | `_economy.spend(car.price)` |
| `resolve_run` | `_economy.cash += proceeds - paid - entry - fuel` | `_economy.apply_delta(proceeds - paid - entry - fuel)` |

\* `end_day` deducts living cost unconditionally today and **can drive cash
negative**. Preserve that: use `apply_delta(-DAILY_BASE_COST)`, **not** `spend()`
(which would refuse and silently change the rule). If a designer later wants a
debt/game-over state, that's a separate gameplay decision — out of scope here.

There are no external cash *writes* to route (grep confirms zero). External
*reads* (`car_shop_scene`, `auction_scene`, `attribute_panel`, `day_summary`,
`knowledge_manager`) may stay as `MetaManager.cash`, or convert to a `get_cash()`
delegate opportunistically — not a priority.

### 6c. Disarm the setter

Replace the read/write proxy with a getter-only delegate. `cash` is a value type,
so a getter-only property is safe and keeps existing reads compiling:

```gdscript
# MetaManager — read-only. No setter == no external write path.
var cash: int:
    get: return _economy.cash
    # no set: MetaManager.cash = x now errors — that's the point
```

A getter-only property on a **value** type is an acceptable transition aid. A
getter that returns a live **collection** is not (§4).

**Done-check (economy):** `grep -rnE "MetaManager\.cash\s*[-+*/]?=([^=])" --include=*.gd`
returns nothing; the only code that changes cash is inside `EconomyOwner`; the
"cannot go negative via spend" rule lives in exactly one place.

---

## 7. Cross-domain transaction pattern (the coordinator's real job)

`resolve_customer_sale` legitimately spans storage, knowledge, economy, customers.
It **should** stay centralized — the fix is that it calls owner methods instead of
field-poking.

**After:**

```gdscript
func resolve_customer_sale(
        items: Array,
        sale_price: int,
        customer: Customer = null,
        strategy: String = "",
) -> void:
    var sold_ids := _storage.remove_entries(items)   # -> Array[int] of removed ids
    for entry in items:                              # knowledge reward stays here
        KnowledgeManager.add_category_points(
            entry.item_data.category_data,
            entry.item_data.rarity,
            KnowledgeManager.KnowledgeAction.SELL,
        )
    _economy.earn(sale_price)
    _customers.record_sale(_progress.current_day, customer, strategy,
        sold_ids, sale_price)
    if customer != null:
        _customers.remove_customer(customer)
    SaveManager.save()
```

```gdscript
# StorageOwner
func remove_entries(entries: Array) -> Array:        # -> Array[int] of removed ids
    var ids: Array[int] = []
    for e in entries:
        ids.append(e.id)
        storage_items.erase(e)
    return ids
```

```gdscript
# CustomersOwner
func record_sale(day: int, customer: Customer, strategy: String,
        sold_ids: Array, sale_price: int) -> void:
    customer_sales_today.append({
        "day": day,
        "customer_id": customer.customer_id if customer != null else "",
        "customer_name": customer.display_name if customer != null else "",
        "strategy": strategy,
        "item_count": sold_ids.size(),
        "item_ids": sold_ids,
        "sale_price": sale_price,
    })

func remove_customer(customer: Customer) -> void:
    nightly_customers.erase(customer)
```

The coordinator still reads like the use case ("remove items, pay out, reward
knowledge, log the sale, drop the customer, commit"), but each owner guards its
own data.

---

## 8. Ordered implementation plan

Separate commits. The game must remain runnable after each. **After each commit,
run the standards linter** (this repo enforces scene-architecture and node-source
rules, and an out-of-loop agent has no in-editor lint hook):

```
python dev/tools/lint_standards.py --files <changed files>
```

There are no automated gameplay tests, so each step's behavioral check is a manual
full-day-cycle playthrough — treat that as the regression gate.

1. **Single-commit saves (§3).** Add no-save owner mutators; each public
   transaction saves exactly once at its commit point. No behavior change.
   *Verify:* full day cycle; save fires once per logical action; day summary
   reflects run + customer economics. Lint.

2. **Economy slice end-to-end (§6).** Add `EconomyOwner` methods; route the four
   cash writes through them; make `MetaManager.cash` getter-only.
   *Verify:* grep shows zero external cash writes; buying a car, a customer sale,
   `end_day` living cost (still allowed to go negative), and `resolve_run` payout
   all produce correct cash. Lint.

3. **Repeat §6 per domain, one commit each**, simplest first:
   **garage → slot → progress → storage → customers.** For each: add methods that
   enforce that domain's invariants (§9), route any writes through them, make the
   field's proxy getter-only (value types) or replace it with operation/duplicate
   accessors (reference types). For `storage_items`/`owned_cars`/`nightly_customers`/
   `available_locations`, swap display call sites to a `get_*` that returns a
   shallow `duplicate()`.

4. **Confirm `MetaManager` is thin:** it holds the six owner refs, exposes a small
   set of cross-domain transactions plus thin getter-only delegators, and contains
   no raw field arithmetic. The six owners hold all the rules.

---

## 9. Invariants that MUST be preserved (no gameplay change)

Structural refactor — output behavior identical unless a designer approves a
change.

- **Save format unchanged.** Every `section_id()` / payload key stays identical so
  existing saves load. Owner field names stay as-is too.
- **`next_entry_id`** is monotonic, never reset, assigned on registration.
- **Storage AP actions** keep `guard → apply → charge → save` order; AP is charged
  **only after** the effect lands; a no-op/guarded call costs nothing. Thresholds
  unchanged: repair `condition < 0.5`; restore `0.5 ≤ condition < 1.0`; research
  `condition ≥ 0.5` and has an unrevealed hidden clue. Research adds
  `5 + investigation` progress.
- **`end_day`** still: advances `current_day`, deducts `DAILY_BASE_COST` (allowed
  to go negative — use `apply_delta`), sums `customer_sales_today` into the
  summary, folds `pending_run` then clears it, resets `current_slot = 1`,
  `storage_ap = 0`, `selling_slots_today = 0`, clears `available_locations`,
  returns a populated `DaySummary`.
- **`pending_run`** stays persisted between `resolve_run` and `end_day` so a quit
  in the evening slot doesn't drop the run breakdown.
- **`resolve_run`** sets `current_slot = 3`; navigation stays the caller's job
  (`GameManager.go_to_hub()`).
- **`begin_auction`** still asserts `current_slot == 1`.
- **`begin_storage_slot`** does `current_slot += 1` then `storage_ap = STORAGE_AP_MAX`.
- **`begin_open_shop`** sets `current_slot = 4`, clears the sales ledger, generates
  customers.
- **Nightly customer counts:** selling_slots 1→2–3, 2→4–6, 3→7–10, else 0.
- **`buy_car`** requires non-null, not already owned, affordable.
- **`resolve_customer_sale`** still tolerates a null customer (caller manages
  removal) for backward compatibility.
- **Knowledge reward** on sale (`add_category_points` with category/rarity/SELL)
  stays — keep it in the coordinator (§7) or move it into a `remove_entries`
  callback; either is fine, but keep the call.

---

## 10. What NOT to do

- **Do not** rename `*Owner` classes to `*Store` — pure churn, breaks `.uid`/
  `class_name` references, zero behavior gain, contradicts the archived design's
  vocabulary.
- **Do not** add proxy *setters* that forward to an owner. That is the exact
  anti-pattern being removed.
- **Do not** "seal" a reference-type field by returning the live `Array`/
  `Dictionary` from a getter — that's a write path in disguise (§4). Return a
  shallow duplicate, or expose operations.
- **Do not** prioritize wrapping value-type *reads*. They don't break invariants.
- **Do not** over-invest in the sealing narrative — no external writes exist
  today; it's preventive. The valuable work is single-commit saves (§3) and
  consolidating each invariant into its owner.
- **Do not** split files first or create new owner files — the six owners already
  exist. The point is *who may mutate what*.
- **Do not** move price/rule calculation into owners or the coordinator — it lives
  in `SellMath` / `ResearchSlot`. Leave it.
- **Do not** change the save format, AP thresholds, customer-count ranges, slot
  numbers, or any tunable. Structure only.
- **Do not** make any owner a global/autoload — they are owned objects reached
  only through `MetaManager` (a hard guardrail from `meta_domain_decomposition.md`).

---

## 11. Definition of done

- Project-wide grep (use `bash` + `-E`; the in-editor file-search is unreliable on
  this mount) returns **zero external writes** for every domain field:
  ```
  grep -rnE "MetaManager\.(cash|storage_items|current_slot|storage_ap|selling_slots_today|pending_run|nightly_customers|customer_sales_today|active_car|owned_cars|available_locations|next_entry_id|current_day)\s*[-+*/]?=([^=])" --include=*.gd
  ```
- No proxy property exposes a setter; reference-type collections are never handed
  out live (display accessors return a shallow `duplicate()`).
- Each domain's invariant lives in exactly one place (its owner).
- Every transaction calls `SaveManager.save()` exactly once, at its commit point;
  no helper saves.
- `MetaManager` contains no raw field arithmetic — only owner-method calls and
  cross-domain coordination.
- `python dev/tools/lint_standards.py` passes on all changed files.
- A full day cycle (auction → resolve_run → storage AP actions → open shop →
  customer sales → end_day → day summary) behaves identically to before, and old
  save files still load.

---

## 12. Docs/tracking follow-up (repo convention)

Per `CLAUDE.md`: this is sequenced multi-step work, so it lives as this plan file
with a **one-line pointer in `TODO.md`** (`## Plan` while queued, promote to
`## Active` once building). Ship a step → cut it from this file + append
`CHANGELOG.md`, same commit. When the whole refactor lands, graduate the
conclusion into `dev/docs/systems/meta/` and archive this plan, then delete its
`TODO.md` line.
