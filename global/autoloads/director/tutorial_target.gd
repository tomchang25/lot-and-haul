# tutorial_target.gd
# Declares a tutorial highlight region independently of the parent layout
# Control's full rect. Scenes opt in by placing this as a child of the target
# area and registering it via Director. Plain Control anchors continue to work
# without this node.
class_name TutorialTarget
extends Control

enum PreferredSide { AUTO, LEFT, RIGHT, TOP, BOTTOM }

@export var target_id: String = ""
@export var preferred_side: PreferredSide = PreferredSide.AUTO
@export var use_custom_rect := false
@export var custom_rect := Rect2()


## The logical highlight rectangle in global coordinates. When [member use_custom_rect]
## is true, the returned rect is offset by [member custom_rect]'s position relative to
## this node's global origin; otherwise it falls back to the full global rect.
func get_tutorial_rect() -> Rect2:
    if use_custom_rect:
        return Rect2(global_position + custom_rect.position, custom_rect.size)
    return get_global_rect()
