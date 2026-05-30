# item_entry.gd
# Runtime context for one item within a single warehouse run.
class_name ItemEntry
extends RefCounted

# ── Display constants ─────────────────────────────────────────────────────────

const UNKNOWN_TEXT := "???"

# ── Inspection constants ─────────────────────────────────────────────────────

const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

# ── Pricing ──────────────────────────────────────────────────────────────────

const MAX_SPREAD: float = 0.5


# A resolved value snapshot. All numbers already include condition multiplier.
class PriceView extends RefCounted:
    var known: bool = false # false when veiled or anchor not revealed
    var exact: bool = false # true when verified — single number, no range
    var min_value: int = 0
    var max_value: int = 0
    var point_value: int = 0 # the resolved item_price

# ── State ─────────────────────────────────────────────────────────────────────

var item_data: ItemData = null

# True after the anchor clue has been revealed (auto-revealed on first inspect).
# This is the sole authority for veil state — use is_veiled() to read it.
var anchor_revealed: bool = false

var condition: float = 1.0

# Unique persistent ID assigned when this entry enters storage.
# -1 = not yet in storage. Assigned by SaveManager
var id: int = -1

# Rolled once at creation in [-0.5, 0.5]. Biases the estimated range away from
# the true price at low inspection; its contribution scales to zero at max
# inspection so the range always converges on the true value.
var center_offset: float = 0.0

# Computed: true when every hidden clue is in revealed_clue_ids.
# If item has no hidden clues, verified is true by default.
var verified: bool:
    get:
        var hidden := _hidden_clues()
        if hidden.is_empty():
            return true
        for clue: ClueData in hidden:
            if not revealed_clue_ids.has(clue.clue_id):
                return false
        return true

var revealed_clue_ids: Array[String] = []

## Accumulated research progress toward each hidden clue, keyed by clue_id.
## Each Research AP spend adds (5 + investigation attribute) to the target clue's
## entry. The clue reveals once progress >= clue.dc. Persists across slots and days.
var research_progress: Dictionary = {}

# ══ Clue helpers ══════════════════════════════════════════════════════════════


func _anchor_clue() -> ClueData:
    if item_data == null:
        return null
    for clue: ClueData in item_data.clues:
        if clue.type == ClueData.ClueType.ANCHOR:
            return clue
    return null


func _surface_clues() -> Array[ClueData]:
    if item_data == null:
        return []
    var result: Array[ClueData] = []
    for clue: ClueData in item_data.clues:
        if clue.type == ClueData.ClueType.SURFACE:
            result.append(clue)
    return result


func _hidden_clues() -> Array[ClueData]:
    if item_data == null:
        return []
    var result: Array[ClueData] = []
    for clue: ClueData in item_data.clues:
        if clue.type == ClueData.ClueType.HIDDEN:
            result.append(clue)
    return result


func _revealed_surface_count() -> int:
    var count := 0
    for clue: ClueData in _surface_clues():
        if revealed_clue_ids.has(clue.clue_id):
            count += 1
    return count


func _total_surface_count() -> int:
    return _surface_clues().size()


func all_surface_revealed() -> bool:
    return _revealed_surface_count() >= _total_surface_count()


## Revealed clue ids that act as demand tags for the customer sell system.
## A clue's id IS its tag (Phase 9). Surface clues are revealed once the item is
## in storage; hidden clues only after authentication (verified). Anchor clues
## are excluded — the anchor is the base-value identity, not a demand tag.
func fit_tags() -> Array[String]:
    var tags: Array[String] = []
    if item_data == null:
        return tags
    for clue: ClueData in item_data.clues:
        if clue.type == ClueData.ClueType.ANCHOR:
            continue
        if revealed_clue_ids.has(clue.clue_id):
            tags.append(clue.clue_id)
    return tags


func _naming_clue_pool() -> Array[ClueData]:
    if item_data == null:
        return []
    var result: Array[ClueData] = []
    for clue: ClueData in item_data.clues:
        if clue.clue_id in revealed_clue_ids:
            result.append(clue)
        elif clue.type == ClueData.ClueType.ANCHOR and anchor_revealed:
            result.append(clue)
    return result


## Applies a single clue's price effect to [param base] and returns the result.
## Dispatches on [member ClueData.effect_op]:
##   "flat" — sets the baseline price (anchor-only; currently same as "add"),
##   "add"  — adds [member ClueData.effect_amount] to [param base],
##   "mul"  — multiplies [param base] by [member ClueData.effect_amount].
## Unknown ops leave [param base] unchanged.
func _apply_price_effect(base: float, clue: ClueData) -> float:
    match clue.effect_op:
        "flat":
            return clue.effect_amount
        "add":
            return base + clue.effect_amount
        "mul":
            return base * clue.effect_amount
    return base


# Product of all hidden mul clues' multipliers.
func _hidden_mul_product() -> float:
    var mult := 1.0
    for clue: ClueData in _hidden_clues():
        if revealed_clue_ids.has(clue.clue_id):
            if clue.effect_op == "mul":
                mult *= clue.effect_amount
    return mult


# Sum of all hidden add clues' amounts.
func _hidden_add_sum() -> float:
    var add_sum := 0.0
    for clue: ClueData in _hidden_clues():
        if revealed_clue_ids.has(clue.clue_id):
            if clue.effect_op == "add":
                add_sum += clue.effect_amount
    return add_sum


## Single source of truth for estimated range + item_price.
func resolve_price() -> PriceView:
    var view := PriceView.new()
    if is_veiled() or not anchor_revealed:
        return view
    view.known = true
    var cond := get_condition_multiplier()
    if verified:
        var v := maxi(1, int(appraised_with_hidden() * cond))
        view.exact = true
        view.min_value = v
        view.max_value = v
        view.point_value = v
        return view
    var base := _raw_appraised_value()
    var spread := MAX_SPREAD * (1.0 - inspection_level)
    var offset := center_offset * (1.0 - inspection_level)
    view.min_value = maxi(1, int(base * (1.0 - spread + offset) * cond))
    view.max_value = maxi(1, int(base * (1.0 + spread + offset) * cond))
    view.point_value = maxi(1, int(base * cond))
    return view

# ══ Computed properties ═══════════════════════════════════════════════════════

# inspection_level based on surface clue reveal ratio.
var inspection_level: float:
    get:
        if not anchor_revealed:
            return 0.0
        var total := _total_surface_count()
        if total == 0:
            return 1.0
        return float(_revealed_surface_count()) / float(total)

var display_name: String:
    get:
        var pool := _naming_clue_pool()
        var best_prefix: ClueData = null
        var best_body: ClueData = null
        var best_suffix: ClueData = null

        for clue: ClueData in pool:
            var slot := clue.naming_slot
            if slot.is_empty():
                continue
            match slot:
                "prefix":
                    if best_prefix == null or clue.naming_priority > best_prefix.naming_priority:
                        best_prefix = clue
                "body":
                    if best_body == null or clue.naming_priority > best_body.naming_priority:
                        best_body = clue
                "suffix":
                    if best_suffix == null or clue.naming_priority > best_suffix.naming_priority:
                        best_suffix = clue

        var parts: Array[String] = []
        if best_prefix != null:
            parts.append(best_prefix.known_text)
        if best_body != null:
            parts.append(best_body.known_text)
        if best_suffix != null:
            parts.append(best_suffix.known_text)

        if parts.is_empty():
            return "Unknown Item"

        # No prefix or suffix revealed yet: the player knows the category (body)
        # but not the qualifying characteristic. Prepend "Unknown" to signal
        # partial identification — e.g. "Unknown Bow" while "Elven" is still hidden.
        var has_qualifier := (best_prefix != null or best_suffix != null)
        if not has_qualifier and best_body != null:
            return "Unknown " + best_body.known_text

        return " ".join(parts)


func get_condition_multiplier() -> float:
    if condition <= 0.25:
        return remap(condition, 0.0, 0.25, 0.25, 0.5)
    elif condition <= 0.5:
        return remap(condition, 0.25, 0.5, 0.5, 1.0)
    elif condition <= 0.75:
        return remap(condition, 0.5, 0.75, 1.0, 2.0)
    else:
        return remap(condition, 0.75, 1.0, 2.0, 4.0)


func get_known_condition_multiplier() -> float:
    if is_veiled():
        return 1.0
    return get_condition_multiplier()

# ── Bucket helpers ────────────────────────────────────────────────────────────


func is_fully_inspected() -> bool:
    return inspection_level >= 1.0


func is_price_converged() -> bool:
    return inspection_level >= 1.0

# ── Clue reveal mechanics ─────────────────────────────────────────────────────


func reveal_anchor() -> void:
    var anchor := _anchor_clue()
    if anchor == null:
        return
    if not revealed_clue_ids.has(anchor.clue_id):
        revealed_clue_ids.append(anchor.clue_id)
    anchor_revealed = true


func attempt_clue(clue: ClueData, attribute_bonus: int) -> bool:
    if clue == null or clue.type == ClueData.ClueType.ANCHOR:
        return false
    var success_chance := clampi((21 + attribute_bonus - clue.dc) * 5, 5, 95)
    var roll := randi() % 100 + 1
    var succeeded := roll <= success_chance
    if succeeded and not revealed_clue_ids.has(clue.clue_id):
        revealed_clue_ids.append(clue.clue_id)
        KnowledgeManager.add_category_points(
            item_data.category_data,
            item_data.rarity,
            KnowledgeManager.KnowledgeAction.REVEAL,
        )
    return succeeded


func get_inspection_clues() -> Array[ClueData]:
    if item_data == null:
        return []
    var result: Array[ClueData] = []
    for clue: ClueData in item_data.clues:
        if clue.type != ClueData.ClueType.ANCHOR and not revealed_clue_ids.has(clue.clue_id):
            result.append(clue)
    return result


func auto_reveal_all_surface() -> void:
    for clue: ClueData in _surface_clues():
        if not revealed_clue_ids.has(clue.clue_id):
            revealed_clue_ids.append(clue.clue_id)


func reveal_all_hidden() -> void:
    for clue: ClueData in _hidden_clues():
        if not revealed_clue_ids.has(clue.clue_id):
            revealed_clue_ids.append(clue.clue_id)


## Returns true if any hidden clue has not yet been revealed.
func has_unrevealed_hidden() -> bool:
    for clue: ClueData in _hidden_clues():
        if not revealed_clue_ids.has(clue.clue_id):
            return true
    return false


## Deterministic storage research: adds [param progress_amount] to the first
## unrevealed hidden clue's accumulated progress. Reveals the clue and grants
## REVEAL XP once progress >= clue.dc. Returns true when a clue is revealed.
## Never rolls — variance belongs at the on-site auction, not in storage.
func advance_research(progress_amount: int) -> bool:
    for clue: ClueData in _hidden_clues():
        if revealed_clue_ids.has(clue.clue_id):
            continue
        var current: int = int(research_progress.get(clue.clue_id, 0))
        current += progress_amount
        research_progress[clue.clue_id] = current
        if current >= clue.dc:
            revealed_clue_ids.append(clue.clue_id)
            KnowledgeManager.add_category_points(
                item_data.category_data,
                item_data.rarity,
                KnowledgeManager.KnowledgeAction.REVEAL,
            )
            return true
        return false
    return false


# Idempotent migration applied to every ItemEntry when it enters or is loaded
# from Storage. Replaced old advance_to_final_layer with auto-reveal surfaces.
func apply_storage_migration() -> void:
    auto_reveal_all_surface()

# ── Anchor value (int) ────────────────────────────────────────────────────────


func _anchor_flat_value() -> int:
    var anchor := _anchor_clue()
    if anchor == null:
        return 0
    return int(anchor.effect_amount)


func _base_value() -> int:
    if is_veiled() or not anchor_revealed:
        return 0
    return int(appraised_with_hidden()) if verified else _anchor_flat_value()

# ── Appraised value ────────────────────────────────────────────────────────────


# appraised_value = (anchor_flat + sum surface_add) * product surface_mul
func _raw_appraised_value() -> float:
    var add_sum := 0.0
    var mul_product := 1.0
    for clue: ClueData in _surface_clues():
        if revealed_clue_ids.has(clue.clue_id):
            match clue.effect_op:
                "add":
                    add_sum += clue.effect_amount
                "mul":
                    mul_product *= clue.effect_amount
    return (float(_anchor_flat_value()) + add_sum) * mul_product


## Full clue value: anchor + all surface + all hidden modifiers (add-then-mul).
## This is the item's true resolved value before condition/market factors.
func appraised_with_hidden() -> float:
    return (_raw_appraised_value() + _hidden_add_sum()) * _hidden_mul_product()


## Full potential value with ALL clues applied regardless of reveal state.
## Ignores revealed_clue_ids — use for debug overlays only, never in release UI.
func full_true_value() -> float:
    var s_add := 0.0
    var s_mul := 1.0
    for clue: ClueData in _surface_clues():
        match clue.effect_op:
            "add":
                s_add += clue.effect_amount
            "mul":
                s_mul *= clue.effect_amount
    var surface_val := (float(_anchor_flat_value()) + s_add) * s_mul
    var h_add := 0.0
    var h_mul := 1.0
    for clue: ClueData in _hidden_clues():
        match clue.effect_op:
            "add":
                h_add += clue.effect_amount
            "mul":
                h_mul *= clue.effect_amount
    return (surface_val + h_add) * h_mul


## Returns a simulated NPC price estimate for this item based on a random subset
## of surface clues the NPC happens to notice. Uses add-then-mul semantics:
## (anchor_flat + sum noticed_add) * product noticed_mul.
## sight_chance: per-clue probability the NPC notices each surface clue.
func roll_npc_estimate(sight_chance: float) -> int:
    var anchor := _anchor_clue()
    if anchor == null:
        return 0
    var add_sum := 0.0
    var mul_product := 1.0
    for clue: ClueData in _surface_clues():
        if randf() < sight_chance:
            match clue.effect_op:
                "add":
                    add_sum += clue.effect_amount
                "mul":
                    mul_product *= clue.effect_amount
    return int((float(_anchor_flat_value()) + add_sum) * mul_product)

# ── Estimated value (range) ────────────────────────────────────────────────────

var estimated_value_min: int:
    get:
        return resolve_price().min_value

var estimated_value_max: int:
    get:
        return resolve_price().max_value

# ── Display text helpers ──────────────────────────────────────────────────────


func estimated_value_text() -> String:
    var v := resolve_price()
    if not v.known:
        return UNKNOWN_TEXT
    if v.exact or v.max_value <= v.min_value:
        return "$%d" % v.min_value
    return "$%d - $%d" % [v.min_value, v.max_value]

## Resolved item price: appraised or verified value × condition multiplier.
## Veiled items should not use this — check anchor_revealed at call sites.
var item_price: int:
    get:
        return resolve_price().point_value

# ── Display colors ────────────────────────────────────────────────────────────

var condition_color: Color:
    get:
        if is_veiled():
            return Color(0.5, 0.5, 0.5)
        if condition >= 0.8:
            return Color.GOLD
        elif condition >= 0.6:
            return Color.GREEN_YELLOW
        elif condition >= 0.3:
            return Color.WHITE
        else:
            return Color.LIGHT_CORAL

const PRICE_COLOR := Color(0.4, 1.0, 0.5)
const PRICE_UNKNOWN_COLOR := Color(0.6, 0.6, 0.6)

var price_color: Color:
    get:
        return PRICE_COLOR if resolve_price().known else PRICE_UNKNOWN_COLOR

# ── Context-aware helpers ─────────────────────────────────────────────────────

# ── Per-column price getters ─────────────────────────────────────────────────


func estimated_value_sort_value() -> int:
    return resolve_price().min_value


func base_value_sort_value() -> int:
    return _base_value()


func condition_text() -> String:
    if is_veiled():
        return UNKNOWN_TEXT
    return "%d%%" % int(condition * 100)


func condition_secondary_text() -> String:
    if is_veiled():
        return ""
    return "x%.2f" % get_condition_multiplier()


func condition_detail_text() -> String:
    var text := condition_text()
    if text == UNKNOWN_TEXT:
        return ""
    return "Condition:  %s (%s)" % [text, condition_secondary_text()]


func base_value_text() -> String:
    var v := _base_value()
    if v == 0:
        return UNKNOWN_TEXT
    return "$%d" % v


func rarity_text() -> String:
    if is_veiled() or item_data == null:
        return ItemEntry.UNKNOWN_TEXT

    var r: int = item_data.rarity
    if r >= 0 and r < RARITY_NAMES.size():
        return RARITY_NAMES[r]

    return ItemEntry.UNKNOWN_TEXT


func weight_text() -> String:
    var category := category_data()
    if is_veiled() or category == null:
        return ItemEntry.UNKNOWN_TEXT
    return "%.1f kg" % category.weight


func grid_text() -> String:
    var category := category_data()
    if is_veiled() or category == null:
        return ItemEntry.UNKNOWN_TEXT
    return "%d  %s" % [category.get_cells().size(), category.shape_id]


func inspection_text() -> String:
    return ItemEntry.UNKNOWN_TEXT if is_veiled() or not anchor_revealed else "%d%%" % int(inspection_level * 100)


func price_display_color() -> Color:
    return price_color


func condition_display_color() -> Color:
    return condition_color


func display_name_color() -> Color:
    if is_veiled() or not verified or item_data == null:
        return Color.WHITE
    match item_data.rarity:
        ItemData.Rarity.UNCOMMON:
            return Color(0.4, 0.8, 0.4)
        ItemData.Rarity.RARE:
            return Color(0.3, 0.6, 1.0)
        ItemData.Rarity.EPIC:
            return Color(0.7, 0.4, 1.0)
        ItemData.Rarity.LEGENDARY:
            return Color(1.0, 0.75, 0.2)
        _:
            return Color(0.85, 0.85, 0.85)


func category_data() -> CategoryData:
    return item_data.category_data if item_data != null else null


func super_category_text() -> String:
    var category := category_data()
    if category == null or category.super_category == null:
        return ""
    return category.super_category.display_name


func category_text() -> String:
    var category := category_data()
    return category.display_name if category != null else ""


## Returns true if the item has any unrevealed surface or hidden clues available
## for inspection. False once all discoverable clues are revealed, or before
## the anchor has been revealed.
func has_inspection_clues() -> bool:
    if not anchor_revealed:
        return false
    if not all_surface_revealed():
        return true
    for clue: ClueData in _hidden_clues():
        if not revealed_clue_ids.has(clue.clue_id):
            return true
    return false


func sort_value(column: int) -> Variant:
    match column:
        ItemRow.Column.NAME:
            return display_name
        ItemRow.Column.CONDITION:
            if is_veiled():
                return 0.0
            return get_condition_multiplier()
        ItemRow.Column.ESTIMATED_VALUE:
            return estimated_value_sort_value()
        ItemRow.Column.BASE_VALUE:
            return base_value_sort_value()
        ItemRow.Column.RARITY:
            if item_data == null:
                return -1.0
            var verified_bonus := 10.0 if verified else 0.0
            return verified_bonus + float(item_data.rarity)
        ItemRow.Column.WEIGHT:
            var weight_category := category_data()
            return weight_category.weight if weight_category != null else 0.0
        ItemRow.Column.GRID:
            var grid_category := category_data()
            return grid_category.get_cells().size() if grid_category != null else 0
        ItemRow.Column.INSPECTION:
            return inspection_level
        _:
            push_warning("Unknown Column: %d" % column)
            return 0


func is_veiled() -> bool:
    return not anchor_revealed


## Player-triggered unveil. Reveals the anchor clue and grants REVEAL knowledge XP.
## For system-level pre-unveils (lot generation, migration), call reveal_anchor() directly.
func unveil() -> void:
    if not is_veiled():
        return
    reveal_anchor()
    if item_data != null and item_data.category_data != null:
        KnowledgeManager.add_category_points(
            item_data.category_data,
            item_data.rarity,
            KnowledgeManager.KnowledgeAction.REVEAL,
        )

# ══ Factory ═══════════════════════════════════════════════════════════════════


static func create(data: ItemData) -> ItemEntry:
    var entry := ItemEntry.new()
    entry.item_data = data

    entry.condition = randf()
    entry.center_offset = randf_range(-0.5, 0.5)
    entry.anchor_revealed = false

    return entry

# ══ Serialization ═════════════════════════════════════════════════════════════


func to_dict() -> Dictionary:
    return {
        "item_id": item_data.item_id,
        "id": id,
        "anchor_revealed": anchor_revealed,
        "condition": condition,
        "center_offset": center_offset,
        "verified": verified,
        "revealed_clue_ids": revealed_clue_ids.duplicate(),
        "research_progress": research_progress.duplicate(),
    }


static func from_dict(d: Dictionary) -> ItemEntry:
    var data: ItemData = ItemRegistry.get_item_by_id(d["item_id"])
    if data == null:
        push_error("ItemEntry: item not found for id '%s'" % d["item_id"])
        return null
    var entry := ItemEntry.new()
    entry.item_data = data
    # Legacy saves may have "inspected" without "anchor_revealed"; treat as unveiled.
    var legacy_inspected := bool(d.get("inspected", false))
    entry.anchor_revealed = bool(d.get("anchor_revealed", legacy_inspected))

    entry.condition = float(d["condition"])
    if d.has("center_offset"):
        entry.center_offset = float(d["center_offset"])

    if d.has("id"):
        entry.id = int(d["id"])
    if d.has("revealed_clue_ids"):
        var raw: Array = d["revealed_clue_ids"]
        for clue_id_value in raw:
            entry.revealed_clue_ids.append(String(clue_id_value))
    # Strip revealed_clue_ids that no longer exist in item_data.clues.
    # Handles renamed clue IDs across data pipeline regenerations (e.g. _veil_NN →
    # _anchor_NN in Phase 8b). Stale IDs are dropped; then reveal_anchor() re-adds
    # the current anchor ID when anchor_revealed is true, keeping price and naming
    # consistent without needing a manual migration table.
    if not entry.revealed_clue_ids.is_empty():
        var known_ids: Dictionary = { }
        for clue: ClueData in entry.item_data.clues:
            known_ids[clue.clue_id] = true
        var clean: Array[String] = []
        for cid: String in entry.revealed_clue_ids:
            if known_ids.has(cid):
                clean.append(cid)
        entry.revealed_clue_ids = clean

    # research_progress: clue_id → int accumulated progress (new in time-slot economy).
    # Old saves without this key start with no in-flight progress — their partial
    # research state is seeded at the SaveManager level during migration.
    if d.has("research_progress") and d["research_progress"] is Dictionary:
        for key: Variant in d["research_progress"]:
            if key is String and d["research_progress"][key] is float:
                entry.research_progress[key] = int(d["research_progress"][key])

    # Legacy migration: old saves stored verified as a bool flag without
    # populating revealed_clue_ids. reveal_all_hidden() is idempotent —
    # clue IDs already loaded above are guarded by has(), so no duplicates.
    if d.has("verified") and bool(d["verified"]):
        entry.reveal_all_hidden()
    return entry
