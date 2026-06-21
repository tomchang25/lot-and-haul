# save_load_context.gd
# Push-model diagnostics channel threaded through the load path.
# SaveManager constructs one per successful load; every from_dict() /
# _apply_migrations() writes into it. SaveManager drains it once at the end.
#
# Uses push_warning for console parity in ctx.info() — lint-exempt per
# error_guard_standard.md §3a.
class_name SaveLoadContext
extends RefCounted

## Player-facing data-loss summaries (always visible via show_warning).
var warnings: Array[String] = []

## Debug-only detail: per-entry/clue resolution notes and schema-migration
## messages (show_info + push_warning console parity).
var infos: Array[String] = []


## Appends [param msg] to warnings. Routed to ToastManager.show_warning()
## (always visible) by SaveManager after the load completes.
func warn(msg: String) -> void:
    warnings.append(msg)


## Appends [param msg] to infos and calls push_warning(msg) to preserve
## existing console-output parity. Routed to ToastManager.show_info()
## (debug-only) by SaveManager after the load completes.
func info(msg: String) -> void:
    infos.append(msg)
    push_warning(msg)
