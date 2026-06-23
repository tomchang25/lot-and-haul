# item_value_breakdown_panel.gd
# Flat clue-effect breakdown panel. Shows anchor base value and every revealed
# clue (surface then hidden) as inline name/value rows. No affix grouping,
# no section headers, no unrevealed slots. Reuses ValueRow for each row.
class_name ItemValueBreakdownPanel
extends VBoxContainer

var _entry: ItemEntry = null

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(entry: ItemEntry) -> void:
    _entry = entry
    if is_node_ready():
        _apply()


func refresh() -> void:
    _apply()

# ══ Internal ══════════════════════════════════════════════════════════════════


func _ready() -> void:
    if _entry != null:
        _apply()


func _apply() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()

    if _entry == null:
        return

    if not _entry.unveiled:
        return

    # Anchor row
    if _entry.anchor != null:
        var row := ValueRow.from_anchor(_entry.anchor)
        # node-src: ephemeral
        add_child(row)

    # Surface clues
    for clue: ClueData in _entry.surface_clues:
        if _entry.revealed_clue_ids.has(clue.clue_id):
            var row := ValueRow.from_clue(clue)
            # node-src: ephemeral
            add_child(row)

    # Hidden clues — only when verified
    if _entry.verified:
        for clue: ClueData in _entry.hidden_clues:
            if _entry.revealed_clue_ids.has(clue.clue_id):
                var row := ValueRow.from_clue(clue)
                # node-src: ephemeral
                add_child(row)
