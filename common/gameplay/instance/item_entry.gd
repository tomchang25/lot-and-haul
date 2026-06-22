# item_entry.gd
# Runtime context for one item within a single warehouse run.
class_name ItemEntry
extends RefCounted

# ══ Inner classes ═════════════════════════════════════════════════════════════

# A resolved value snapshot. All numbers already include condition multiplier.
class PriceView extends RefCounted:
    var known: bool = false # false when veiled
    var exact: bool = false # true when verified — single number, no range
    var min_value: int = 0
    var max_value: int = 0
    var point_value: int = 0 # the resolved item_price

# ── Pricing ──────────────────────────────────────────────────────────────────

const MAX_SPREAD: float = 0.5

# ── State ─────────────────────────────────────────────────────────────────────

var anchor: AnchorData = null
var surface_clues: Array[ClueData] = []
var hidden_clues: Array[ClueData] = []
var category_data: CategoryData = null

## Affixes assigned to this item at generation time. The affix set is the
## primary index for item naming (Spec B) and the knowledge dictionary (Spec C).
## Sourced from the affix draw; empty for plain items.
var affixes: Array[AffixData] = []

## The combination_id drawn for each affix, in the same order as [member affixes].
## Empty for plain items or when no affix was drawn.
var combination_ids: Array[String] = []

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

## Rarity equals the number of hidden clues on this instance.
var rarity: Economy.Rarity:
    get:
        return Economy.rarity_for_clue_count(hidden_clues.size())

# Computed: true when item is unveiled, all surface clues are revealed,
# and every hidden clue is in revealed_clue_ids.
# If item has no hidden clues, verified is true by default.
var verified: bool:
    get:
        if not unveiled:
            return false
        if not all_surface_revealed():
            return false
        if _get_hidden_clues().is_empty():
            return true
        for clue: ClueData in _get_hidden_clues():
            if not revealed_clue_ids.has(clue.clue_id):
                return false
        return true

## All clues on this item — surface and hidden combined, surface-first.
var all_clues: Array[ClueData]:
    get:
        var result: Array[ClueData] = []
        result.assign(_get_surface_clues() + _get_hidden_clues())
        return result

var revealed_clue_ids: Array[String] = []

## Accumulated research progress toward each hidden clue, keyed by clue_id.
## Each Research AP spend adds (5 + investigation attribute) to the target clue's
## entry. The clue reveals once progress >= clue.dc. Persists across slots and days.
var research_progress: Dictionary = { }

# inspection_level based on surface clue reveal ratio.
var inspection_level: float:
    get:
        if not unveiled:
            return 0.0
        var total := _total_surface_count()
        if total == 0:
            return 1.0
        return float(_revealed_surface_count()) / float(total)

var estimated_value_min: int:
    get:
        return resolve_price().min_value

var estimated_value_max: int:
    get:
        return resolve_price().max_value

## Resolved item price: appraised or verified value × condition multiplier.
## Veiled items should not use this — check is_veiled() at call sites.
var item_price: int:
    get:
        return resolve_price().point_value

# ══ Common API ════════════════════════════════════════════════════════════════


## Restores an item entry from [param d]. Writes per-entry resolution failures
## to [param ctx] (required). Returns null when the anchor cannot be resolved —
## a kept entry with anchor = null is silent corruption.
static func from_dict(d: Dictionary, ctx: SaveLoadContext) -> ItemEntry:
    var entry := ItemEntry.new()

    # Composition form — all entries arrive here after StorageStore migration.
    var aid: String = d.get("anchor_id", "")
    if not aid.is_empty():
        entry.anchor = AnchorRegistry.get_anchor_by_id(aid)
        if entry.anchor == null:
            ctx.info("anchor '%s' not found — entry dropped" % aid)
            return null
    for cid: Variant in d.get("surface_ids", []):
        var clue := ClueRegistry.get_clue_by_id(String(cid))
        if clue != null:
            entry.surface_clues.append(clue)
        else:
            ctx.info("surface clue '%s' not found" % cid)
    for cid: Variant in d.get("hidden_ids", []):
        var clue := ClueRegistry.get_clue_by_id(String(cid))
        if clue != null:
            entry.hidden_clues.append(clue)
        else:
            ctx.info("hidden clue '%s' not found" % cid)
    var cat_id: String = d.get("category_id", "")
    if not cat_id.is_empty():
        entry.category_data = CategoryRegistry.get_category_by_id(cat_id)

    # Affix state (post-generation affix references; empty for pre-affix saves).
    for raw_aid: Variant in d.get("affix_ids", []):
        var affix_obj := AffixRegistry.get_affix_by_id(String(raw_aid))
        if affix_obj != null:
            entry.affixes.append(affix_obj)
        else:
            ctx.info("affix '%s' not found on load — dropped" % raw_aid)
    for cid: Variant in d.get("combination_ids", []):
        entry.combination_ids.append(String(cid))

    # Common fields
    entry.unveiled = bool(d.get("unveiled", false))
    entry.condition = float(d.get("condition", 1.0))
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
        for clue: ClueData in entry.all_clues:
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

    return entry


func to_dict() -> Dictionary:
    var d := {
        "id": id,
        "unveiled": unveiled,
        "condition": condition,
        "center_offset": center_offset,
        "revealed_clue_ids": revealed_clue_ids.duplicate(),
        "research_progress": research_progress.duplicate(),
        "anchor_id": _get_anchor().anchor_id if _get_anchor() != null else "",
        "surface_ids": [],
        "hidden_ids": [],
        "category_id": _get_category_data().category_id if _get_category_data() != null else "",
        "affix_ids": [],
        "combination_ids": [],
    }
    for c: ClueData in _get_surface_clues():
        d["surface_ids"].append(c.clue_id)
    for c: ClueData in _get_hidden_clues():
        d["hidden_ids"].append(c.clue_id)
    for a: AffixData in affixes:
        d["affix_ids"].append(a.affix_id)
    for cid: String in combination_ids:
        d["combination_ids"].append(cid)
    return d


func all_surface_revealed() -> bool:
    return _revealed_surface_count() >= _total_surface_count()


## Revealed clue ids that act as demand tags for the customer sell system.
## A clue's id IS its tag. Surface clues are revealed once the item is in storage
## hidden clues only after authentication (verified). The anchor is excluded —
## it is the base-value identity, not a demand tag.
func fit_tags() -> Array[String]:
    var tags: Array[String] = []
    for clue: ClueData in all_clues:
        if revealed_clue_ids.has(clue.clue_id):
            tags.append(clue.clue_id)
    return tags


## Anchor and affixes that contribute to display_name composition.
## The anchor is included when unveiled; affixes when unveiled.
func get_naming_clue_pool() -> Array:
    var result: Array = []
    var eff_anchor := _get_anchor()
    if unveiled and eff_anchor != null:
        result.append(eff_anchor)
    if unveiled:
        for affix: AffixData in affixes:
            result.append(affix)
    return result


func get_base_value() -> int:
    if is_veiled():
        return 0
    return int(appraised_with_hidden()) if verified else _anchor_base_value()


## Full clue value using the global add-then-mul formula:
##   (effective_base + Σ_surface_add + Σ_hidden_add) × Π_surface_mul × Π_hidden_mul
## effective_base = revealed override amount if any hidden override is revealed, else anchor base.
## This is the item's verified resolved value before condition/market factors.
func appraised_with_hidden() -> float:
    var base := float(_effective_base_value())
    var add_sum := 0.0
    var mul_product := 1.0
    for clue: ClueData in all_clues:
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
    for clue: ClueData in _get_hidden_clues():
        if clue.effect_op == "override":
            base = clue.effect_amount
            break
    var add_sum := 0.0
    var mul_product := 1.0
    for clue: ClueData in all_clues:
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
## [param rng] — optional seedable RNG for deterministic generation.
func roll_npc_estimate(sight_chance: float, rng: RandomNumberGenerator = null) -> int:
    var eff_anchor := _get_anchor()
    if eff_anchor == null:
        return 0
    var add_sum := 0.0
    var mul_product := 1.0
    for clue: ClueData in _get_surface_clues():
        if RandomUtils.randf(rng) < sight_chance:
            match clue.effect_op:
                "add":
                    add_sum += clue.effect_amount
                "mul":
                    mul_product *= clue.effect_amount
    return maxi(Economy.MIN_ITEM_VALUE, int((float(_anchor_base_value()) + add_sum) * mul_product))


## Single source of truth for estimated range + item_price.
func resolve_price() -> PriceView:
    var view := PriceView.new()
    if is_veiled():
        return view
    view.known = true
    var cond := get_condition_multiplier()
    if verified:
        var v := maxi(Economy.MIN_ITEM_VALUE, int(appraised_with_hidden() * cond))
        view.exact = true
        view.min_value = v
        view.max_value = v
        view.point_value = v
        return view
    var base := _raw_appraised_value()
    var spread := MAX_SPREAD * (1.0 - inspection_level)
    var offset := center_offset * (1.0 - inspection_level)
    view.min_value = maxi(Economy.MIN_ITEM_VALUE, int(base * (1.0 - spread + offset) * cond))
    view.max_value = maxi(Economy.MIN_ITEM_VALUE, int(base * (1.0 + spread + offset) * cond))
    view.point_value = maxi(Economy.MIN_ITEM_VALUE, int(base * cond))
    return view


func get_condition_multiplier() -> float:
    if condition <= 0.5:
        return remap(condition, 0.0, 0.5, 0.75, 1.0)
    return remap(condition, 0.5, 1.0, 1.0, 1.5)


func get_known_condition_multiplier() -> float:
    if is_veiled():
        return 1.0
    return get_condition_multiplier()


func is_fully_inspected() -> bool:
    return inspection_level >= 1.0


func is_price_converged() -> bool:
    return inspection_level >= 1.0


func attempt_clue(clue: ClueData, attribute_bonus: int, rng: RandomNumberGenerator = null) -> bool:
    if clue == null:
        return false
    var success_chance := clampi((21 + attribute_bonus - clue.dc) * 5, 5, 95)
    var roll := RandomUtils.randi(rng) % 100 + 1
    var succeeded := roll <= success_chance
    if succeeded and not revealed_clue_ids.has(clue.clue_id):
        revealed_clue_ids.append(clue.clue_id)
    return succeeded


## Returns all surface and hidden clues not yet revealed. Used by inspection scene
## to populate the clue-attempt action list.
func get_inspection_clues() -> Array[ClueData]:
    var result: Array[ClueData] = []
    for clue: ClueData in all_clues:
        if not revealed_clue_ids.has(clue.clue_id):
            result.append(clue)
    return result


func auto_reveal_all_surface() -> void:
    for clue: ClueData in _get_surface_clues():
        if is_veiled():
            unveil()

        if not revealed_clue_ids.has(clue.clue_id):
            revealed_clue_ids.append(clue.clue_id)


func reveal_all_hidden() -> void:
    for clue: ClueData in _get_hidden_clues():
        if not revealed_clue_ids.has(clue.clue_id):
            revealed_clue_ids.append(clue.clue_id)


## Returns true if any hidden clue has not yet been revealed.
func has_unrevealed_hidden() -> bool:
    for clue: ClueData in _get_hidden_clues():
        if not revealed_clue_ids.has(clue.clue_id):
            return true
    return false


## Deterministic storage research: adds [param progress_amount] to the first
## unrevealed hidden clue's accumulated progress. Reveals the clue once progress
## >= clue.dc. Returns true when a clue is revealed.
## Never rolls — variance belongs at the on-site auction, not in storage.
func advance_research(progress_amount: int) -> bool:
    for clue: ClueData in _get_hidden_clues():
        if revealed_clue_ids.has(clue.clue_id):
            continue
        var current: int = int(research_progress.get(clue.clue_id, 0))
        current += progress_amount
        research_progress[clue.clue_id] = current
        if current >= clue.dc:
            revealed_clue_ids.append(clue.clue_id)
            return true
        return false
    return false


# Idempotent migration applied to every ItemEntry when it enters or is loaded
# from Storage. Replaced old advance_to_final_layer with auto-reveal surfaces.
func apply_storage_migration() -> void:
    auto_reveal_all_surface()


## Returns the item's weight in kg, sourced from the anchor. 0.0 if no anchor.
## Weight is observable even when veiled (needed for cargo packing systems).
func get_weight() -> float:
    var eff_anchor := _get_anchor()
    if eff_anchor == null:
        return 0.0
    return eff_anchor.weight_kg


## Returns the cargo shape_id from the anchor. "s1x1" if no anchor or empty.
## Shape is observable even when veiled (cargo grid placement before unveil).
func get_shape_id() -> String:
    var eff_anchor := _get_anchor()
    if eff_anchor == null or eff_anchor.shape_id.is_empty():
        return "s1x1"
    return eff_anchor.shape_id


## Returns cargo grid cells from the anchor's shape_id. Empty array if no anchor.
func get_cells() -> Array[Vector2i]:
    return CargoShapes.get_cells(get_shape_id())


func super_category_text() -> String:
    var cat := _get_category_data()
    if cat == null or cat.super_category == null:
        return ""
    return TranslationServer.translate(cat.super_category.display_name_key)


func category_text() -> String:
    var cat := _get_category_data()
    if cat == null:
        return ""
    return TranslationServer.translate(cat.display_name_key)


## Returns true if the item has any unrevealed surface or hidden clues available
## for inspection. False once all discoverable clues are revealed, or before unveiling.
func has_inspection_clues() -> bool:
    if not unveiled:
        return false
    if not all_surface_revealed():
        return true
    for clue: ClueData in _get_hidden_clues():
        if not revealed_clue_ids.has(clue.clue_id):
            return true
    return false


func is_veiled() -> bool:
    return not unveiled


## Player-triggered unveil. Marks the item as unveiled.
## Returns true when the flag actually flipped (false if already unveiled).
## For system-level pre-unveils (lot generation, migration), set unveiled = true directly.
func unveil() -> bool:
    if not is_veiled():
        return false
    unveiled = true
    return true


## Applies trailer damage: reduces condition by [param ratio], clamped at 0.0.
## Replaces direct condition field writes from scenes.
func apply_damage(ratio: float) -> void:
    condition = maxf(0.0, condition - ratio)

# ══ Price helpers ═════════════════════════════════════════════════════════════


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


func _anchor_base_value() -> int:
    var eff_anchor := _get_anchor()
    if eff_anchor == null:
        return 0
    return int(eff_anchor.base_value)


# appraised_value = (anchor.base_value + sum surface_add) * product surface_mul
func _raw_appraised_value() -> float:
    var add_sum := 0.0
    var mul_product := 1.0
    for clue: ClueData in _get_surface_clues():
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
    for clue: ClueData in _get_hidden_clues():
        if clue.effect_op == "override" and revealed_clue_ids.has(clue.clue_id):
            return int(clue.effect_amount)
    return _anchor_base_value()

# ══ Clue helpers ══════════════════════════════════════════════════════════════


func _revealed_surface_count() -> int:
    var count := 0
    for clue: ClueData in _get_surface_clues():
        if revealed_clue_ids.has(clue.clue_id):
            count += 1
    return count


func _total_surface_count() -> int:
    return _get_surface_clues().size()

# ══ Private data access helpers ═══════════════════════════════════════════════


func _get_anchor() -> AnchorData:
    return anchor


func _get_surface_clues() -> Array[ClueData]:
    return surface_clues


func _get_hidden_clues() -> Array[ClueData]:
    return hidden_clues


func _get_category_data() -> CategoryData:
    return category_data
