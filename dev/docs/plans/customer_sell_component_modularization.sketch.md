# Customer Sell Component Modularization

## Goal

Split the nightly selling screen into inspectable, scene-backed UI components so redesign work and debugging no longer require editing one large scene script at once. The target is a thinner orchestrator with explicit component boundaries for customer selection, item rows, selected item detail, vehicle loading, offer strategy, and sale receipt behavior.

## Requirements

1. The screen must be decomposed into focused UI components, because customer selection, item inspection, packing, strategy selection, dice resolution, and sale confirmation currently change together even when only one surface is being edited.
2. Persistent interface structure must live in scene files rather than being built from script at runtime, because stable nodes should be inspectable in the editor and debuggable without stepping through construction code.
3. Runtime-generated nodes must be limited to data-variable children such as customer buttons, item rows, dice, and grid cells, because those counts depend on the night, storage contents, or dice pool.
4. Each component must expose a small public setup or refresh surface and emit user-intent signals, because parent code should coordinate state without reaching through child node trees.
5. The root selling screen must remain the transaction coordinator, because sale commitment still belongs behind the existing manager authority rather than inside a visual component.
6. The modularization must preserve current selling behavior while making the planned visual redesign easier to build, because this is a structural pass, not an economy or rule rewrite.

## Design

Use the screen as a set of sale-workflow surfaces: customer queue, customer profile, inventory ledger, selected item detail, vehicle loading bay, offer docket, and receipt. Each surface owns only its display and local interaction state. The parent screen owns which customer is active, which item is selected, what is loaded, what sale strategy is pending, and when a completed offer is committed.

The customer-facing surfaces should be editor-visible even when empty. Empty states can be placeholder labels or disabled panels, but the component tree should show the final layout before runtime data arrives. Data-variable lists should create children at runtime, but the list shell, scroll container, section title, hint copy, and empty-state holder should be persistent.

Signals should describe user intent rather than implementation details. Good signal semantics are customer selected, item selected, item placement requested, car clear requested, conservative offer requested, aggressive pitch requested, dice choice changed, pitch confirmed, and receipt confirmed. The parent can translate those intents into packing-grid calls, price math, pending sale state, and manager commits.

The first extraction should prioritize the most painful debug surfaces. Item list and offer strategy are higher value than extracting every decorative wrapper, because they currently mix display, selection state, dynamic child creation, and sale math feedback. The loading bay can keep using the shared packing behavior internally while gaining a selling-specific shell and summary surface.

## Sketch (non-normative)

Names and file shapes below are implementation hints only; the codebase wins any disagreement.

Suggested component split:

| Proposed component     | Responsibility                                                                                                             |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `CustomerQueuePanel`   | Rebuild customer appointment buttons, show active/served state, emit `customer_selected(index)`                            |
| `CustomerProfilePanel` | Show active customer name, demand chips, vehicle size, matched item count, and any derived visual identity                 |
| `SellingItemListPanel` | Own the scroll shell, empty state, runtime item row instances, row loaded/held/highlight state, and item selection signals |
| `SellingItemRow`       | Show one sellable item with selling-specific fit, value, verification, condition, shape, and loaded state                  |
| `SelectedItemPanel`    | Show the current item as persistent decision information, replacing hover-only item details as the primary read            |
| `CustomerCarPanel`     | Wrap the packing grid, car title, capacity summary, loaded count, placement feedback, and clear action                     |
| `DealPanel`            | Show conservative quote, aggressive pitch state, dice tray, pending total, and strategy actions                            |
| `SaleReceiptDialog`    | Show final receipt copy and emit confirm/cancel without owning sale commitment                                             |

Root-level state can stay compact:

```gdscript
var _customers: Array[CustomerEntry] = []
var _selected_customer_index := -1
var _selected_item: ItemEntry = null
var _pending_sale_price := 0
var _pending_strategy := ""
```

The parent screen can wire components in one direction:

```gdscript
func _ready() -> void:
    _customer_queue.customer_selected.connect(_on_customer_selected)
    _item_list.item_selected.connect(_on_item_selected)
    _item_list.item_pick_requested.connect(_on_item_pick_requested)
    _car_panel.placement_changed.connect(_on_car_placement_changed)
    _deal_panel.conservative_requested.connect(_on_conservative_requested)
    _deal_panel.aggressive_requested.connect(_on_aggressive_requested)
    _deal_panel.pitch_confirmed.connect(_on_pitch_confirmed)
    _receipt.confirmed.connect(_on_receipt_confirmed)
```

Suggested extraction order:

1. Extract the selling-specific item row first, because item information is the visible decision gap and it removes the cargo-row dependency from the selling screen.
2. Extract the selected item panel second, because it gives the redesign a stable primary information surface before the rest of the layout changes.
3. Extract the deal panel third, because conservative/aggressive state and dice UI are a natural component boundary and will carry the VFX pass.
4. Extract the customer queue/profile shell fourth, because customer tabs are simple but their visual identity should stop being raw buttons in the root script.
5. Wrap the existing packing grid in a customer car panel last, because the grid behavior can remain shared while the selling scene gains its own loading-bay presentation.
6. Move receipt formatting into its own component once the strategy and selected item surfaces are stable, because receipt copy depends on the final terminology.

Persistent nodes should be pre-placed in each component scene. Runtime creation should remain for data-variable item rows, customer appointment buttons, dice controls, and packing grid cells. If a node is always visible or always owned for the component lifetime, it should be a scene node with a placeholder value rather than created during setup.

Each component should follow the same apply pattern: `setup()` stores data, `_apply()` paints nodes after ready, and `refresh()` repaints current state. Parent code should not change child labels or styles directly after setup; it should update component state through public methods such as `set_selected_item()`, `set_loaded_items()`, or `set_pitch_state()`.

## Non-Goals

1. Turning the selling components into a generalized framework for other scenes. Extract only what this screen needs.
2. Changing save data, customer generation, item matching, sale formulas, or manager ownership.
3. Replacing the shared packing behavior. The selling screen needs a better shell around it, not a new grid algorithm.
4. Building the future shared modalized HUD. The selling screen can reserve safe space for global chrome without depending on that project.

## Acceptance Criteria

1. The selling screen can be edited by opening focused component scenes for customer display, item list, selected item detail, vehicle loading, and offer strategy instead of one monolithic scene.
2. The root screen script primarily coordinates active customer, selected item, loaded items, pending strategy, receipt confirmation, and sale commitment rather than painting every UI surface directly.
3. Stable layout structure is visible in scene files with placeholder content, while only runtime-variable lists and controls are created dynamically.
4. Item list behavior, selected item display, and offer strategy behavior can each be debugged independently by inspecting their component state and signals.
5. Existing customer selection, item loading, car clearing, conservative sale, aggressive sale, and sale confirmation behavior still work after the split.
