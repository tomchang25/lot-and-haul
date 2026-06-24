# Item Hover Dismiss Ownership

## Goal

Make item hover previews and clue detail tooltips reachable by moving dismiss behavior from immediate trigger-exit to shared hover ownership between the trigger and the floating surface.

The issue has two independent layers: `ItemCardPopup` hides when leaving item rows/cards, and `ClueTooltip` hides when leaving `ClueTag` or `ValueRow`.

## Requirements

1. A user must be able to move from an item trigger into `ItemCardPopup` without the popup disappearing.
2. A user must be able to move from `ClueTag` or `ValueRow` into `ClueTooltip` without the tooltip disappearing.
3. `ClueTooltip` dismissal must stay centralized in `ClueTooltipManager`, because the manager is already the global singleton used by all clue tooltip callers.
4. Existing `ClueTag` and `ValueRow` call sites should keep their simple show/hide API shape where possible; today they call `show_for_*()` on enter and `hide_tooltip()` on exit.
5. `ItemCardPopup` should gain hover ownership internally, because today it only exposes `show_for()` and immediate `hide_popup()`.
6. Scene consumers should stop connecting hover-exit directly to hard hide. Reveal and run review currently wire dismiss directly to `_tooltip.hide_popup`.
7. Item row/card signal semantics should remain unchanged. `ItemRow`, `ItemListPanel`, and `ItemBrowserPanel` can continue emitting hover/unhover signals; the popup decides whether an unhover request actually hides.
8. The fix must preserve existing external-highlight guards in selling and cargo rows. Those guards are a precedent for conditional dismiss, but they are not the ownership model itself.

## Design

Use a shared ownership rule:

```text
visible while source_hovered OR floating_surface_hovered OR hide_grace_active
```

The short grace window is not the core behavior; it only bridges the small physical gap between trigger and popup/tooltip. Actual persistence comes from hover ownership once the cursor enters the floating surface.

For `ClueTooltip`, ownership lives in `ClueTooltipManager`:

- `show_for_clue()` / `show_for_anchor()` mark the source as hovered.
- `hide_tooltip()` becomes a requested hide from the source, not an immediate hard hide.
- `ClueTooltip` emits or reports mouse enter/exit.
- The manager hides only when both source and tooltip are unowned after the grace window.
- A later `show_for_*()` invalidates any pending hide from an older source.

For `ItemCardPopup`, ownership lives in the popup instance:

- `show_for(entry, anchor)` marks the source as hovered and shows/repositions the popup.
- New `request_hide()` marks the source as unhovered and schedules ownership-based hide.
- Existing `hide_popup()` remains as a hard hide for scene teardown, mode changes, or explicit force-close.
- Popup mouse enter/exit toggles `_popup_hovered`.
- Consumers connect row/card unhover signals to `request_hide()` instead of `hide_popup()`.

This keeps scene-level code thin and consistent with the current reusable UI component direction.

## Sketch (non-normative)

Names and file shapes below are implementation hints only; the codebase wins any disagreement.

### Phase 1 — `ClueTooltip` hover reporting

Update:

- `game/shared/item_display/clue_tooltip/clue_tooltip.gd`
- `game/shared/item_display/clue_tooltip/clue_tooltip.tscn`

Add:

```gdscript
signal hover_state_changed(hovered: bool)
```

In `_ready()`:

```gdscript
func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
```

Handlers:

```gdscript
func _on_mouse_entered() -> void:
    hover_state_changed.emit(true)


func _on_mouse_exited() -> void:
    hover_state_changed.emit(false)
```

Keep `hide_tooltip()` as the hard visual hide. The manager decides when to call it.

### Phase 2 — `ClueTooltipManager` ownership gate

Update:

- `global/autoloads/clue_tooltip_manager.gd`

Add state:

```gdscript
const HIDE_GRACE_SEC := 0.12

var _source_hovered := false
var _tooltip_hovered := false
var _hide_generation := 0
```

During `_ready()`:

```gdscript
_tooltip.hover_state_changed.connect(_on_tooltip_hover_state_changed)
```

Change show methods:

```gdscript
func show_for_clue(clue: ClueData, anchor: Rect2, revealed: bool = true, valued: bool = false) -> void:
    _source_hovered = true
    _hide_generation += 1
    if _tooltip != null:
        _tooltip.show_for_clue(clue, anchor, revealed, valued)
```

Use the same ownership pattern for `show_for_anchor()`.

Change `hide_tooltip()`:

```gdscript
func hide_tooltip() -> void:
    _source_hovered = false
    _queue_hide_if_unowned()
```

Add:

```gdscript
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
```

### Phase 3 — `ItemCardPopup` ownership gate

Update:

- `game/shared/item_display/item_card_popup.gd`
- `game/shared/item_display/item_card_popup.tscn`

Add state:

```gdscript
const HIDE_GRACE_SEC := 0.12

var _source_hovered := false
var _popup_hovered := false
var _hide_generation := 0
```

Add `_ready()`:

```gdscript
func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
```

Change `show_for()`:

```gdscript
func show_for(entry: ItemEntry, anchor: Rect2) -> void:
    if entry == null:
        return

    _source_hovered = true
    _hide_generation += 1

    _card.setup(entry)
    _position_near(anchor)
    show()
```

Extract current positioning body into:

```gdscript
func _position_near(anchor: Rect2) -> void:
    var vp_size := get_viewport_rect().size
    var target_x := anchor.position.x
    var target_y := anchor.position.y + anchor.size.y + 4.0

    if target_y + size.y > vp_size.y:
        target_y = anchor.position.y - size.y - 4.0
    if target_x + size.x > vp_size.x:
        target_x = vp_size.x - size.x - 4.0

    global_position = Vector2(maxf(4.0, target_x), maxf(4.0, target_y))
```

Add soft hide:

```gdscript
func request_hide() -> void:
    _source_hovered = false
    _queue_hide_if_unowned()
```

Keep hard hide:

```gdscript
func hide_popup() -> void:
    _source_hovered = false
    _popup_hovered = false
    _hide_generation += 1
    hide()
```

Add handlers:

```gdscript
func _on_mouse_entered() -> void:
    _popup_hovered = true
    _hide_generation += 1


func _on_mouse_exited() -> void:
    _popup_hovered = false
    _queue_hide_if_unowned()
```

Add gate:

```gdscript
func _queue_hide_if_unowned() -> void:
    if _source_hovered or _popup_hovered:
        return

    _hide_generation += 1
    var generation := _hide_generation

    await get_tree().create_timer(HIDE_GRACE_SEC).timeout

    if generation != _hide_generation:
        return
    if _source_hovered or _popup_hovered:
        return
    hide()
```

### Phase 4 — Replace direct popup dismiss wiring

Change direct hover-exit wiring from hard hide to soft hide.

Reveal:

```gdscript
_item_list_panel.tooltip_dismissed.connect(_tooltip.request_hide)
```

Run review:

```gdscript
_cargo_panel.tooltip_dismissed.connect(_tooltip.request_hide)
```

Cargo helper:

```gdscript
func _hide_tooltip() -> void:
    _hovered_item = null
    _tooltip.request_hide()
```

Any hard scene teardown, navigation, or explicit reset can still call `hide_popup()`.

### Phase 5 — Leave trigger components mostly unchanged

Do not rewrite these unless a compile/type issue appears:

- `ItemRow`
- `ItemListPanel`
- `ItemBrowserPanel`
- `ClueTag`
- `ValueRow`
- `SellingItemCard`
- `CargoItemRow`

Their current role is to announce enter/exit intent. The ownership-aware popup/manager should decide whether that exit becomes an actual hide.

## Non-Goals

1. No click-to-pin popup behavior.
2. No change to clue reveal state, item data, pricing, verification, cargo, or sale logic.
3. No rewrite of `ItemBrowserPanel` card/table behavior.
4. No replacement of `ClueTag` or `ValueRow`.
5. No scene-specific tooltip manager per screen.
6. No removal of `_ext_highlighted`; it remains cargo/selling highlight behavior, not tooltip ownership.

## Acceptance Criteria

1. Moving from an `ItemRow` into `ItemCardPopup` keeps the popup visible.
2. Moving from an item card in browser/card mode into `ItemCardPopup` keeps the popup visible.
3. Moving from `ClueTag` inside an item card into `ClueTooltip` keeps the clue tooltip visible.
4. Moving from `ValueRow` inside item detail panels into `ClueTooltip` keeps the clue tooltip visible.
5. Moving from one clue tag directly to another replaces tooltip content without an old pending hide closing the new tooltip.
6. Leaving both trigger and floating surface hides the popup/tooltip after the grace window.
7. Reveal and run review no longer connect `tooltip_dismissed` directly to `hide_popup()`.
8. `ClueTooltipManager` remains the only global clue tooltip ownership point.
9. Selling and cargo external highlight behavior still works.
10. Godot headless check uses the safe snapshot procedure, not direct headless execution against the mounted working tree.
