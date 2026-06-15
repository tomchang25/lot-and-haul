# clue_chunk.gd
# Spoiler-safe clue display block. Takes an ItemEntry and renders every clue
# slot through a masking helper. Unknown rows render as "???" only — no clue
# text, DC, attribute, price effect, or hidden outcome is leaked.
class_name ClueChunk
extends VBoxContainer

# ── Display constants ──────────────────────────────────────────────────────────

const SURFACE_ICON := "●"
const HIDDEN_ICON := "◆"
const UNKNOWN_TEXT := "???"

const KNOWN_COLOR := Color(0.85, 0.85, 0.85)
const UNKNOWN_COLOR := Color(0.5, 0.5, 0.5)
const HEADER_COLOR := Color(0.55, 0.58, 0.63)
const VERIFIED_COLOR := Color(0.4, 1.0, 0.5)

# ── State ──────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null

# ══ Public API ═════════════════════════════════════════════════════════════════


func setup(entry: ItemEntry) -> void:
    _entry = entry
    if is_node_ready():
        _apply()


func refresh() -> void:
    _apply()

# ══ Internal ═══════════════════════════════════════════════════════════════════


func _apply() -> void:
    for child in get_children():
        child.queue_free()

    if _entry == null:
        return

    _build_anchor()
    _build_surface()
    _build_hidden()


func _make_separator() -> HSeparator:
    var sep := HSeparator.new()
    return sep


func _make_header(text: String) -> Label:
    var lbl := Label.new()
    lbl.text = text
    lbl.add_theme_font_size_override(&"font_size", 10)
    lbl.add_theme_color_override(&"font_color", HEADER_COLOR)
    return lbl


func _make_clue_row(icon: String, text: String, color: Color) -> Label:
    var lbl := Label.new()
    lbl.text = "%s  %s" % [icon, text]
    lbl.add_theme_font_size_override(&"font_size", 11)
    lbl.add_theme_color_override(&"font_color", color)
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return lbl


func _build_anchor() -> void:
    if _entry == null:
        return
    if _entry.anchor == null:
        return
    if not _entry.unveiled:
        return

    # node-src: ephemeral — rebuilt per _apply()
    add_child(_make_separator())

    var header := _make_header("IDENTITY")
    # node-src: ephemeral — rebuilt per _apply()
    add_child(header)

    var anchor := _entry.anchor
    var text: String = anchor.known_text if _entry.unveiled else UNKNOWN_TEXT
    var color := KNOWN_COLOR if _entry.unveiled else UNKNOWN_COLOR
    # node-src: ephemeral — rebuilt per _apply()
    add_child(_make_clue_row("■", text, color))


func _build_surface() -> void:
    if _entry == null:
        return
    var clues: Array[ClueData] = _entry.surface_clues
    if clues.is_empty():
        return

    # node-src: ephemeral — rebuilt per _apply()
    add_child(_make_separator())

    var header := _make_header("SURFACE")
    # node-src: ephemeral — rebuilt per _apply()
    add_child(header)

    for clue: ClueData in clues:
        var revealed := _entry.revealed_clue_ids.has(clue.clue_id)
        var text: String = clue.known_text if revealed else UNKNOWN_TEXT
        var color := KNOWN_COLOR if revealed else UNKNOWN_COLOR
        # node-src: ephemeral — rebuilt per _apply()
        add_child(_make_clue_row(SURFACE_ICON, text, color))


func _build_hidden() -> void:
    if _entry == null:
        return
    var clues: Array[ClueData] = _entry.hidden_clues
    if clues.is_empty():
        return

    # node-src: ephemeral — rebuilt per _apply()
    add_child(_make_separator())

    var header := _make_header("HIDDEN")
    # node-src: ephemeral — rebuilt per _apply()
    add_child(header)

    for clue: ClueData in clues:
        var revealed := _entry.revealed_clue_ids.has(clue.clue_id)
        var text: String = clue.known_text if revealed else UNKNOWN_TEXT
        var color := VERIFIED_COLOR if revealed else UNKNOWN_COLOR
        # node-src: ephemeral — rebuilt per _apply()
        add_child(_make_clue_row(HIDDEN_ICON, text, color))
