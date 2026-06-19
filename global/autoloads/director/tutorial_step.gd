# tutorial_step.gd
# A single step in a tutorial script. RefCounted — cheap to create, passed by ref.
class_name TutorialStep
extends RefCounted

enum Kind { HINT, POPUP }
enum Advance { NEXT, SCENE_ENTERED, EVENT }

var kind: Kind
var anchor_id: String
var text: String
var image: Texture2D = null
var advance: Advance = Advance.NEXT
var unlock_anchor: bool = false
var fallback_anchor_ids: Array[String] = []
## When the primary anchor is non-renderable, skip if false; try fallback if true.
var fallback_when_anchor_unrenderable: bool = false
## Event id checked when advance == Advance.EVENT.
var advance_event_id: StringName = &""
## Target scene id checked when advance == Advance.SCENE_ENTERED.
## Empty string matches any scene registration.
var advance_scene_id: String = ""
## False for informational popups that should not dim or block the scene.
var blocks_input: bool = true


func _init(
        p_kind: Kind,
        p_text: String,
        p_anchor_id: String = "",
        p_advance: Advance = Advance.NEXT,
        p_unlock: bool = false,
        p_image: Texture2D = null,
        p_fallback_anchor_ids: Array[String] = [],
        p_fallback_when_anchor_unrenderable: bool = false,
        p_advance_event_id: StringName = &"",
        p_advance_scene_id: String = "",
        p_blocks_input: bool = true,
) -> void:
    kind = p_kind
    text = p_text
    anchor_id = p_anchor_id
    advance = p_advance
    unlock_anchor = p_unlock
    image = p_image
    fallback_anchor_ids = p_fallback_anchor_ids
    fallback_when_anchor_unrenderable = p_fallback_when_anchor_unrenderable
    advance_event_id = p_advance_event_id
    advance_scene_id = p_advance_scene_id
    blocks_input = p_blocks_input
