# clue_tooltip_manager.gd
# Global ClueTooltip singleton. Handles showing/hiding the clue detail tooltip.
# All scenes use this instead of wiring per-scene ClueTooltip instances.
# Every ClueTag calls this automatically — no per-scene connections needed.
extends Node

const ClueTooltipScene: PackedScene = preload("res://game/shared/item_display/clue_tooltip/clue_tooltip.tscn")

var _tooltip: ClueTooltip = null


func _ready() -> void:
    _tooltip = ClueTooltipScene.instantiate()
    _tooltip.name = "ClueTooltip"
    var layer := CanvasLayer.new()
    layer.layer = 128
    layer.add_child(_tooltip)
    add_child(layer)


func show_for_clue(clue: ClueData, anchor: Rect2, revealed: bool = true, valued: bool = false) -> void:
    if _tooltip != null:
        _tooltip.show_for_clue(clue, anchor, revealed, valued)


func show_for_anchor(anchor_data: AnchorData, anchor_rect: Rect2, revealed: bool = true) -> void:
    if _tooltip != null:
        _tooltip.show_for_anchor(anchor_data, anchor_rect, revealed)


func hide_tooltip() -> void:
    if _tooltip != null:
        _tooltip.hide_tooltip()
