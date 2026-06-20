# game_manager.gd
# Autoload (Boot): loads save data, runs validation, hands off to first scene.
# Supports --test-unit (skip boot, route to unit tests) and --ci-run (skip
# routing, CI pilot autoload manages the loop).
extends Node

@warning_ignore("return_value_discarded")

func _ready() -> void:
    var args := OS.get_cmdline_args()

    if "--test-unit" in args:
        _boot_for_tests()
        return

    if "--ci-run" in args:
        _boot_for_ci()
        return

    if _has_testbed_flag(args):
        _boot_for_testbed()
        return

    _boot_normal()


func _boot_normal() -> void:
    var boot_errors := RegistryAudit.collect_boot_errors()
    if not boot_errors.is_empty():
        SceneRouter.go_to_fatal_error("Generated data failed to load", boot_errors)
        return

    _register_runtime_providers()
    SaveManager.boot_load()
    var validation_ok: bool = SaveManager.run_validation()
    var scene_ok: bool = RegistryAudit.check_scene_registry(SceneRouter.scenes)
    var _audit_ok: bool = validation_ok and scene_ok


func _boot_for_tests() -> void:
    _register_runtime_providers()
    # Autoloads have already initialized — registries, managers, event bus all
    # ready. Skip save loading, validation, and scene routing. Route to the
    # test runner scene which will create a GUT node and run all unit tests.
    # The test runner handles its own exit via get_tree().quit().
    var test_scene := load("res://test/test_runner.tscn")
    if test_scene == null:
        ToastManager.show_error("GameManager: test_runner.tscn not found — falling back to normal boot")
        _boot_normal()
        return
    get_tree().change_scene_to_packed.call_deferred(test_scene)


func _boot_for_ci() -> void:
    # Autoloads initialize normally. Save loading, validation, and scene audit
    # run as usual. Scene routing is skipped — the CI pilot autoload (harness/ci_pilot.gd)
    # detects the --ci-run flag and manages the full auto-pilot loop, including
    # its own exit.
    var boot_errors := RegistryAudit.collect_boot_errors()
    if not boot_errors.is_empty():
        for e: String in boot_errors:
            push_error("[FATAL] " + e) # push-error: boot
        get_tree().quit(1)
        return

    _register_runtime_providers()
    SaveManager.boot_load()
    var validation_ok: bool = SaveManager.run_validation()
    var scene_ok: bool = RegistryAudit.check_scene_registry(SceneRouter.scenes)
    var _audit_ok: bool = validation_ok and scene_ok


func _boot_for_testbed() -> void:
    _register_runtime_providers()
    # Save loading is skipped — TestbedPilot calls SaveManager.use_test_slot()
    # which wipes and resets providers before seeding. Only the scene registry
    # audit runs so wiring bugs are surfaced early.
    var _scene_ok: bool = RegistryAudit.check_scene_registry(SceneRouter.scenes)


## Returns true when any argument begins with --testbed=.
func _has_testbed_flag(args: PackedStringArray) -> bool:
    for arg: String in args:
        if arg.begins_with("--testbed="):
            return true
    return false


## Registers save providers before SaveManager.boot_load(). Keeping this list
## explicit avoids provider correctness depending on autoload order.
func _register_runtime_providers() -> void:
    SaveManager.register_provider(KnowledgeManager)
    SaveManager.register_provider(MetaManager)
    SaveManager.register_provider(RunManager)
