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
    var known: bool = false # false when veiled
    var exact: bool = false # true when verified — single number, no range
    var min_value: int = 0
    var max_value: int = 0
    var point_value: int = 0 # the resolved item_price

# ── State ─────────────────────────────────────────────────────────────────────

var item_data: ItemData = null

## True once the player has unveiled this item (revealed which anchor variant it is).
## Veiled items show only their cargo shape and weight; all identity data is masked.
## This is the sole authority for veil state — use is_veiled() to read it.
var unveiled: bool = false

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
        if item_data == null or item_data.hidden_clues.is_empty():
            return true
        for clue: ClueData in item_data.hidden_clues:
            if not revealed_clue_ids.has(clue.clue_id):
                return false
        return true

var revealed_clue_ids: Array[String] = []

## Accumulated research progress toward each hidden clue, keyed by clue_id.
## Each Research AP spend adds (5 + investigation attribute) to the target clue's
## entry. The clue reveals once progress >= clue.dc. Persists across slots and days.
var research_progress: Dictionary = { }

# ══ Clue helpers ══════════════════════════════════════════════════════════════


func _revealed_surface_count() -> int:
    var count := 0
    if item_data == null:
        return 0
    for clue: ClueData in item_data.surface_clues:
        if revealed_clue_ids.has(clue.clue_id):
            count += 1
    return count


func _total_surface_count() -> int:
    if item_data == null:
        return 0
    return item_data.surface_clues.size()


func all_surface_revealed() -> bool:
    return _revealed_surface_count() >= _total_surface_count()


## Revealed clue ids that act as demand tags for the customer sell system.
## A clue's id IS its tag. Surface clues are revealed once the item is in storage
## hidden clues only after authentication (verified). The anchor is excluded —
## it is the base-value identity, not a demand tag.
func fit_tags() -> Array[String]:
    var tags: Array[String] = []
    if item_data == null:
        return tags
    for clue: ClueData in item_data.all_clues:
        if revealed_clue_ids.has(clue.clue_id):
            tags.append(clue.clue_id)
    return tags


## Clues and the anchor that contribute to display_name composition.
## The anchor is included when unveiled; surface/hidden clues when in revealed_clue_ids.
func _naming_clue_pool() -> Array:
    # Returns a mixed array of AnchorData and ClueData entries that participate in naming.
    var result: Array = []
    if item_data == null:
        return result
    if unveiled and item_data.anchor != null:
        result.append(item_data.anchor)
    for clue: ClueData in item_data.all_clues:
        if clue.clue_id in revealed_clue_ids:
            result.append(clue)
    return result


## Applies a single clue's price effect to [param base] and returns the result.
## Dispatches on [member ClueData.effect_op]:
##   "add"      — adds [member ClueData.effect_amount] to [param base],
##   "mul"      — multiplies [param base] by [member ClueData.effect_amount],
##   "override" — hidden-only base replacement (handled upstream in _effective_base_value).
## Unknown ops leave [param base] unchanged.
func _apply_price_effect(base: float, clue: ClueData) -> float:
    match clue.effect_op:
        "add":
            return base + clue.effect_amount
        "mul":
            return base * clue.effect_amount
    return base

# ── Anchor value (int) ────────────────────────────────────────────────────────


func _anchor_base_value() -> int:
    if item_data == null or item_data.anchor == null:
        return 0
    return int(item_data.anchor.base_value)


func _base_value() -> int:
    if is_veiled():
        return 0
    return int(appraised_with_hidden()) if verified else _anchor_base_value()

# ── Appraised value ────────────────────────────────────────────────────────────


# appraised_value = (anchor.base_value + sum surface_add) * product surface_mul
func _raw_appraised_value() -> float:
    var add_sum := 0.0
    var mul_product := 1.0
    if item_data == null:
        return 0.0
    for clue: ClueData in item_data.surface_clues:
        if revealed_clue_ids.has(clue.clue_id):
            match clue.effect_op:
                "add":
                    add_sum += clue.effect_amount
                "mul":
                    mul_product *= clue.effect_amount
    return (float(_anchor_base_value()) + add_sum) * mul_product


## Returns the effective base value used in verified price resolution.
## If a revealed hidden clue carries effect_op "override" (base-replacement),
## its effect_amount replaces the anchor base value. Otherwise the anchor base value is used.
## Appraised (surface-only) math is unaffected — it always starts from the anchor.
func _effective_base_value() -> int:
    if item_data == null:
        return 0
    for clue: ClueData in item_data.hidden_clues:
        if clue.effect_op == "override" and revealed_clue_ids.has(clue.clue_id):
            return int(clue.effect_amount)
    return _anchor_base_value()


## Full clue value using the global add-then-mul formula:
##   (effective_base + Σ_surface_add + Σ_hidden_add) × Π_surface_mul × Π_hidden_mul
## effective_base = revealed override amount if any hidden override is revealed, else anchor base.
## This is the item's verified resolved value before condition/market factors.
func appraised_with_hidden() -> float:
    var base := float(_effective_base_value())
    var add_sum := 0.0
    var mul_product := 1.0
    if item_data != null:
        for clue: ClueData in item_data.all_clues:
            if revealed_clue_ids.has(clue.clue_id):
                match clue.effect_op:
                    "add":
                        add_sum += clue.effect_amount
                    "mul":
                        mul_product *= clue.effect_amount
                    # "override" already factored into _effective_base_value()
    return (base + add_sum) * mul_product


## Full potential value with ALL clues applied regardless of reveal state.
## Ignores revealed_clue_ids — use for debug overlays only, never in release UI.
## Uses override base if any hidden override exists (first one wins).
func full_true_value() -> float:
    var base := float(_anchor_base_value())
    if item_data != null:
        for clue: ClueData in item_data.hidden_clues:
            if clue.effect_op == "override":
                base = clue.effect_amount
                break
    var add_sum := 0.0
    var mul_product := 1.0
    if item_data != null:
        for clue: ClueData in item_data.all_clues:
            match clue.effect_op:
                "add":
                    add_sum += clue.effect_amount
                "mul":
                    mul_product *= clue.effect_amount
                # "override" already handled above
    return (base + add_sum) * mul_product


## Returns a simulated NPC price estimate for this item based on a random subset
## of surface clues the NPC happens to notice. Uses add-then-mul semantics:
## (anchor.base_value + sum noticed_add) * product noticed_mul.
## sight_chance: per-clue probability the NPC notices each surface clue.
func roll_npc_estimate(sight_chance: float) -> int:
    if item_data == null or item_data.anchor == null:
        return 0
    var add_sum := 0.0
    var mul_product := 1.0
    for clue: ClueData in item_data.surface_clues:
        if randf() < sight_chance:
            match clue.effect_op:
                "add":
                    add_sum += clue.effect_amount
                "mul":
                    mul_product *= clue.effect_amount
    return int((float(_anchor_base_value()) + add_sum) * mul_product)

# ══ Computed properties ═══════════════════════════════════════════════════════

# inspection_level based on surface clue reveal ratio.
var inspection_level: float:
    get:
        if not unveiled:
            return 0.0
        var total := _total_surface_count()
        if total == 0:
            return 1.0
        return float(_revealed_surface_count()) / float(total)

var display_name: String:
    get:
        var pool := _naming_clue_pool()
        var best_prefix_text: String = ""
        var best_prefix_prio: int = -1
        var best_body_text: String = ""
        var best_body_prio: int = -1
        var best_suffix_text: String = ""
        var best_suffix_prio: int = -1

        for entry in pool:
            var slot: String
            var priority: int
            var text: String
            if entry is AnchorData:
                slot = "body"
                priority = (entry as AnchorData).naming_priority
                text = (entry as AnchorData).known_text
            elif entry is ClueData:
                slot = (entry as ClueData).naming_slot
                priority = (entry as ClueData).naming_priority
                text = (entry as ClueData).known_text
            else:
                continue
            if slot.is_empty():
                continue
            match slot:
                "prefix":
                    if priority > best_prefix_prio:
                        best_prefix_prio = priority
                        best_prefix_text = text
                "body":
                    if priority > best_body_prio:
                        best_body_prio = priority
                        best_body_text = text
                "suffix":
                    if priority > best_suffix_prio:
                        best_suffix_prio = priority
                        best_suffix_text = text

        var parts: Array[String] = []
        if not best_prefix_text.is_empty():
            parts.append(best_prefix_text)
        if not best_body_text.is_empty():
            parts.append(best_body_text)
        if not best_suffix_text.is_empty():
            parts.append(best_suffix_text)

        if parts.is_empty():
            return "Unknown Item"

        # No prefix or suffix revealed yet: the player knows the category (body)
        # but not the qualifying characteristic. Prepend "Unknown" to signal
        # partial identification — e.g. "Unknown Bow" while "Elven" is still hidden.
        var has_qualifier := (not best_prefix_text.is_empty() or not best_suffix_text.is_empty())
        if not has_qualifier and not best_body_text.is_empty():
            return "Unknown " + best_body_text

        return " ".join(parts)


## Single source of truth for estimated range + item_price.
func resolve_price() -> PriceView:
    var view := PriceView.new()
    if is_veiled():
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


func attempt_clue(clue: ClueData, attribute_bonus: int) -> bool:
    if clue == null:
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


## Returns all surface and hidden clues not yet revealed. Used by inspection scene
## to populate the clue-attempt action list.
func get_inspection_clues() -> Array[ClueData]:
    if item_data == null:
        return []
    var result: Array[ClueData] = []
    for clue: ClueData in item_data.all_clues:
        if not revealed_clue_ids.has(clue.clue_id):
            result.append(clue)
    return result


func auto_reveal_all_surface() -> void:
    if item_data == null:
        return
    for clue: ClueData in item_data.surface_clues:
        if not revealed_clue_ids.has(clue.clue_id):
            revealed_clue_ids.append(clue.clue_id)


func reveal_all_hidden() -> void:
    if item_data == null:
        return
    for clue: ClueData in item_data.hidden_clues:
        if not revealed_clue_ids.has(clue.clue_id):
            revealed_clue_ids.append(clue.clue_id)


## Returns true if any hidden clue has not yet been revealed.
func has_unrevealed_hidden() -> bool:
    if item_data == null:
        return false
    for clue: ClueData in item_data.hidden_clues:
        if not revealed_clue_ids.has(clue.clue_id):
            return true
    return false


## Deterministic storage research: adds [param progress_amount] to the first
## unrevealed hidden clue's accumulated progress. Reveals the clue and grants
## REVEAL XP once progress >= clue.dc. Returns true when a clue is revealed.
## Never rolls — variance belongs at the on-site auction, not in storage.
func advance_research(progress_amount: int) -> bool:
    if item_data == null:
        return false
    for clue: ClueData in item_data.hidden_clues:
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
## Veiled items should not use this — check is_veiled() at call sites.
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


## Returns the item's weight in kg, sourced from the anchor. 0.0 if no anchor.
## Weight is observable even when veiled (needed for cargo packing systems).
func get_weight() -> float:
    if item_data == null or item_data.anchor == null:
        return 0.0
    return item_data.anchor.weight_kg


## Returns the cargo shape_id from the anchor. "s1x1" if no anchor or empty.
## Shape is observable even when veiled (cargo grid placement before unveil).
func get_shape_id() -> String:
    if item_data == null or item_data.anchor == null or item_data.anchor.shape_id.is_empty():
        return "s1x1"
    return item_data.anchor.shape_id


## Returns cargo grid cells from the anchor's shape_id. Empty array if no anchor.
func get_cells() -> Array[Vector2i]:
    return CargoShapes.get_cells(get_shape_id())


func weight_text() -> String:
    if is_veiled():
        return ItemEntry.UNKNOWN_TEXT
    return "%.1f kg" % get_weight()


func grid_text() -> String:
    if is_veiled():
        return ItemEntry.UNKNOWN_TEXT
    return "%d  %s" % [get_cells().size(), get_shape_id()]


func inspection_text() -> String:
    return ItemEntry.UNKNOWN_TEXT if is_veiled() else "%d%%" % int(inspection_level * 100)


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
## for inspection. False once all discoverable clues are revealed, or before unveiling.
func has_inspection_clues() -> bool:
    if not unveiled:
        return false
    if not all_surface_revealed():
        return true
    for clue: ClueData in item_data.hidden_clues:
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
            return get_weight()
        ItemRow.Column.GRID:
            return get_cells().size()
        ItemRow.Column.INSPECTION:
            return inspection_level
        _:
            push_warning("Unknown Column: %d" % column)
            return 0


func is_veiled() -> bool:
    return not unveiled


## Player-triggered unveil. Marks the item as unveiled and grants REVEAL knowledge XP.
## For system-level pre-unveils (lot generation, migration), set unveiled = true directly.
func unveil() -> void:
    if not is_veiled():
        return
    unveiled = true
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
    entry.unveiled = false

    return entry

# ══ Serialization ═════════════════════════════════════════════════════════════


func to_dict() -> Dictionary:
    return {
        "item_id": item_data.item_id,
        "id": id,
        "unveiled": unveiled,
        "condition": condition,
        "center_offset": center_offset,
        "verified": verified,
        "revealed_clue_ids": revealed_clue_ids.duplicate(),
        "research_progress": research_progress.duplicate(),
    }


static func from_dict(d: Dictionary) -> ItemEntry:
    var data: ItemData = ItemRegistry.get_item_by_id(d["item_id"])
    if data == null:
        push_warning("ItemEntry: item_id '%s' not found — entry dropped" % d["item_id"])
        return null
    var entry := ItemEntry.new()
    entry.item_data = data

    # Accept legacy keys: old saves used "anchor_revealed"; older saves used "inspected".
    var legacy_anchor_revealed := bool(d.get("anchor_revealed", false))
    var legacy_inspected := bool(d.get("inspected", false))
    entry.unveiled = bool(d.get("unveiled", legacy_anchor_revealed or legacy_inspected))

    entry.condition = float(d["condition"])
    if d.has("center_offset"):
        entry.center_offset = float(d["center_offset"])

    if d.has("id"):
        entry.id = int(d["id"])

    if d.has("revealed_clue_ids"):
        var raw: Array = d["revealed_clue_ids"]
        for clue_id_value in raw:
            entry.revealed_clue_ids.append(String(clue_id_value))

    # Strip stale clue ids (e.g. old anchor ids, renamed clue ids).
    # Build known-id set from surface + hidden clues only (anchors are no longer clues).
    if not entry.revealed_clue_ids.is_empty():
        var known_ids: Dictionary = { }
        for clue: ClueData in entry.item_data.all_clues:
            known_ids[clue.clue_id] = true
        var clean: Array[String] = []
        for cid: String in entry.revealed_clue_ids:
            if known_ids.has(cid):
                clean.append(cid)
        entry.revealed_clue_ids = clean

    # research_progress: clue_id → int accumulated progress (new in time-slot economy).
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
