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
) -> void:
    kind = p_kind
    text = p_text
    anchor_id = p_anchor_id
    advance = p_advance

# ── Fluent factories ──────────────────────────────────────────────────────────


static func hint(p_text: String, anchor: String = "") -> TutorialStep:
    return new(Kind.HINT, p_text, anchor)


static func popup(p_text: String) -> TutorialStep:
    return new(Kind.POPUP, p_text)

# ── Fluent modifiers ──────────────────────────────────────────────────────────


func unlock() -> TutorialStep:
    unlock_anchor = true
    return self


func on_event(event_id: StringName) -> TutorialStep:
    advance = Advance.EVENT
    advance_event_id = event_id
    return self


func on_scene(scene_id: String) -> TutorialStep:
    advance = Advance.SCENE_ENTERED
    advance_scene_id = scene_id
    return self


func no_block() -> TutorialStep:
    blocks_input = false
    return self


func with_fallback(ids: Array[String]) -> TutorialStep:
    fallback_anchor_ids = ids
    fallback_when_anchor_unrenderable = true
    return self
