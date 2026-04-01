extends Node

# Flat skill registry. Returns the player's current level for the given skill.
# Always 0 for this slice — full skill progression is deferred.
func get_level(skill_id: String) -> int:
    return 0
