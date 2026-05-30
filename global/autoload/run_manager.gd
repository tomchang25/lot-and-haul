extends Node

# Full state for the current run. Null between runs.
var run_record: RunRecord = null


## Initializes auction AP tiers on the record for a new visit.
## cap and reserve default to Economy constants; call before starting a run.
func init_auction_ap(
        cap: int = Economy.INSPECTION_AP_CAP,
        reserve: int = Economy.INSPECTION_REFILL_METRIC_DEFAULT,
) -> void:
    if run_record == null:
        return
    run_record.inspection_ap_cap = cap
    run_record.refill_metric = reserve
    run_record.actions_remaining = cap


## Clears all per-run state so the next run starts clean.
func clear_run_state() -> void:
    run_record = null
