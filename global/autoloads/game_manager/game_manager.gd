# game_manager.gd
# Autoload (Boot): loads save data, runs migrations/validation, hands off to first scene.
extends Node

func _ready() -> void:
    SaveManager.load()
    SaveManager.run_migrations()
    var validation_ok := SaveManager.run_validation()
    var scene_ok := RegistryAudit.check_scene_registry(SceneRouter.scenes)
    var _audit_ok := validation_ok and scene_ok
