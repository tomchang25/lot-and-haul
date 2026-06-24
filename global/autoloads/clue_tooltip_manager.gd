# clue_tooltip_manager.gd
# Global ClueTooltip singleton. Handles showing/hiding the clue detail tooltip.
# All scenes use this instead of wiring per-scene ClueTooltip instances.
# Every ClueTag calls this automatically — no per-scene connections needed.
extends Node

const HIDE_GRACE_SEC := 0.25

const ClueTooltipScene: PackedScene = preload("res://game/shared/item_display/clue_tooltip/clue_tooltip.tscn")

var _tooltip: ClueTooltip = null

var _source_hovered := false
var _tooltip_hovered := false
var _hide_generation := 0


func _ready() -> void:
    _tooltip = ClueTooltipScene.instantiate()
    _tooltip.name = "ClueTooltip"
    _tooltip.hover_state_changed.connect(_on_tooltip_hover_state_changed)
    var layer := CanvasLayer.new()
    layer.layer = 128
    layer.add_child(_tooltip)
    add_child(layer)


func show_for_clue(clue: ClueData, anchor: Rect2, revealed: bool = true, valued: bool = false) -> void:
    _source_hovered = true
    _hide_generation += 1
    if _tooltip != null:
        _tooltip.show_for_clue(clue, anchor, revealed, valued)


func show_for_anchor(anchor_data: AnchorData, anchor_rect: Rect2, revealed: bool = true) -> void:
    _source_hovered = true
    _hide_generation += 1
    if _tooltip != null:
        _tooltip.show_for_anchor(anchor_data, anchor_rect, revealed)


func is_tooltip_visible() -> bool:
    return _tooltip != null and _tooltip.visible


func hide_tooltip() -> void:
    _source_hovered = false
    _queue_hide_if_unowned()


func _on_tooltip_hover_state_changed(hovered: bool) -> void:
    _tooltip_hovered = hovered
    if hovered:
        _hide_generation += 1
    else:
        _queue_hide_if_unowned()


func _queue_hide_if_unowned() -> void:
    if _source_hovered or _tooltip_hovered:
        return

    _hide_generation += 1
    var generation := _hide_generation

    await get_tree().create_timer(HIDE_GRACE_SEC).timeout

    if generation != _hide_generation:
        return
    if _source_hovered or _tooltip_hovered:
        return
    if _tooltip != null:
        _tooltip.hide_tooltip()
