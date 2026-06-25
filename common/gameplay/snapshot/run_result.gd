# run_result.gd
# Snapshot produced by RunSystem.take_run_result() at run end.
# Carries final run economics and cargo (surface-clues already auto-revealed)
# for MetaSystem.resolve_run() to consume. Not serialized — the economics are
# stashed into SlotStore.pending_run by resolve_run().
class_name RunResult
extends RefCounted

## Net cash from on-site item sales (abandoned items sold before loading cargo).
var onsite_proceeds: int = 0

## Total auction price paid across all lots won this run.
var paid_price: int = 0

## Location entry fee charged at run start.
var entry_fee: int = 0

## Fuel cost for the round trip to this location.
var fuel_cost: int = 0

## Cargo items committed for transport. Surface clues are fully revealed before
## this snapshot is built — do not call auto_reveal_all_surface() again.
var cargo_items: Array[ItemEntry] = []
