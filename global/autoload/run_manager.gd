extends Node

# Full state for the current run. Null between runs.
var run_record: RunRecord = null


# Clears all per-run state so the next run starts clean.
func clear_run_state() -> void:
    run_record = null
