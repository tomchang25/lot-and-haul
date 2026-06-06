My take: these two issues feel like a conflict, but they're actually answered by the same distinction — **reads vs. writes**. Once you split on that axis, both mostly dissolve, and your `resolve_run` example is already closer to right than you think.

## The middleman "problem" is really a reads problem

A pass-through getter is only a smell when it adds nothing. The fix isn't to delete the manager — it's to stop routing _reads_ through it. Expose the Store (or a read-only snapshot) and let callers read fields directly. That's safe precisely because of your own archetype rule: a Store guards its invariants on _mutation_, so reading its fields can never break anything. `RunManager.get_paid_price()`, `get_fuel_cost()`, `get_cargo()`… that's the boilerplate to kill. `RunManager.run_store` (read access) is fine.

_Writes_ are the opposite: those stay behind a manager method or a Store mutator, because that's where invariants and the save commit live. So:

- Reads → expose the Store, no middleman.
- Writes → go through the owning manager / Store mutator.

The manager keeps three real jobs (lifecycle/factory of its store, invariant-guarding multi-store transactions, save coordination) and loses only the one with no value (query forwarding).

## Your cross-manager example is mostly correct — don't split it

The instinct to "split by specific fields" is the wrong move, and you already sensed why. Passing the whole `RunStore` in is **dependency injection, not a hidden dependency** — MetaManager never reaches into RunManager's private state; the caller hands it the data. Reading `record.cargo_items` / `record.onsite_proceeds` is exactly what a Store-as-data-container is for. Splitting into six scalars would multiply the very middleman surface you're trying to shrink. So keep `resolve_run(record: RunStore)`.

## The one thing I'd actually change

The real wart is that `resolve_run` reaches _back out_: `RunManager.clear_run_state()` and `SaveManager.save()` at the bottom. MetaManager is doing meta-domain writes (good) but also driving RunManager's lifecycle and owning the global commit (layering leak). Lift the transaction boundary up to whoever orchestrates the run→hub transition:

```gdscript
# orchestrator (scene transition / GameManager)
MetaManager.resolve_run(RunManager.run_store)  # meta-domain writes only, no inner save
RunManager.clear_run_state()                   # run-domain lifecycle
SaveManager.save()                             # single commit owned by the boundary
```

Now each manager only touches its own domain, the foreign Store flows in by parameter, and the "single commit" is honest — it sits at the transaction boundary instead of being smuggled into a meta method. `resolve_run` itself just drops its last two lines.

## Rule of thumb to settle future cases

A manager should own _writes and lifecycle_ for its domain and nothing else. Reads go straight to the Store. Cross-domain writes take the foreign Store as a parameter and never reach through the foreign manager. The transaction boundary (sequencing + save) lives in the caller, not in whichever manager happened to do the last write.

That keeps managers thin without making Stores public free-for-alls — managers stop being read-proxies but stay the gatekeepers for the thing that actually needs gatekeeping.
