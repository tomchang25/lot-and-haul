# game_manager.gd
# Autoload (Boot): loads save data, runs validation, hands off to first scene.
extends Node

func _ready() -> void:
    SaveManager.load()
    var validation_ok := SaveManager.run_validation()
    var scene_ok := RegistryAudit.check_scene_registry(SceneRouter.scenes)
    var _audit_ok := validation_ok and scene_ok
