# Theme Standard

The project uses a single centralized theme at `global/theme/main_theme.tres`, set as the project-level theme via `project.godot → [gui] theme/custom`. Every scene inherits it automatically.

## What the theme provides

**Colors** (Label, Button, RichTextLabel, Tooltip):

- Primary text: `Color(0.88, 0.88, 0.92, 1)` — cool off-white
- Hover text: `Color(1, 1, 1, 1)` — pure white
- Pressed text: `Color(0.75, 0.75, 0.8, 1)` — dimmed
- Disabled text: `Color(0.45, 0.48, 0.53, 1)` — muted slate
- Tooltip text: `Color(0.8, 0.8, 0.85, 1)` — slightly dimmer than primary

**Font sizes** — default 24 (scaled from 16 for 1920x1080). Named type variations defined in `main_theme.tres` cover all common sizes. Set `theme_type_variation = "TokenName"` on any node; override only when the size is truly dynamic (runtime parameter).

**Typography scale** (enforced as theme type variations in `main_theme.tres`):

| Token      | Size | Usage                    |
| ---------- | ---- | ------------------------ |
| display    | 72   | Banner titles            |
| title      | 48   | Page titles              |
| heading_1  | 42   | Major section headers    |
| heading_2  | 33   | Sub-section headers      |
| heading_3  | 30   | Minor section headers    |
| body_large | 27   | Primary body text        |
| body       | 24   | Default / secondary body |
| detail     | 21   | Card content, tooltips   |
| caption    | 20   | Small labels             |
| small      | 18   | Tooltip detail           |
| tiny       | 17   | Tiny labels              |
| compact    | 16   | Compact card labels      |
| micro      | 14   | Micro text, debug        |

**Container separation defaults**:

- HBoxContainer / VBoxContainer: 8
- GridContainer: h=6, v=6
- HSeparator / VSeparator: 8

**StyleBoxes**:

- `PanelContainer/panel` — dark surface (`0.15, 0.15, 0.18`), 1px border, 4px radius
- `Button` — all five states (normal, hover, pressed, disabled, focus)
- `TooltipPanel` — near-black (`0.1, 0.1, 0.12`), 3px radius
- `HSeparator/VSeparator` — 1px line matching border color

## Component state StyleBoxes

When a `Control` has a fixed set of visual states that belong to one reusable component (`default`, `hovered`, `selected`, `available`, `blocked`, `loaded`, `holding`), define those `StyleBox` resources in `global/theme/main_theme.tres` under a component-specific theme type. The theme type should match the component class name when one exists, e.g. `CargoItemRow/styles/default`, `CargoItemRow/styles/hovered`, `CargoItemRow/styles/holding`, `CargoItemRow/styles/loaded`.

GDScript may still choose which themed style applies because the selected state is runtime data. The script should fetch the named style from the theme, e.g. `get_theme_stylebox(&"loaded", &"CargoItemRow")`, then apply it with `add_theme_stylebox_override(&"panel", style)` or remove the override when returning to an inherited base style. Do not create `StyleBoxFlat.new()` in GDScript for fixed component states.

GDScript-built `StyleBox` resources are only acceptable when style values are genuinely computed at runtime, such as grid cells colored by a valid drop target, debug overlays, or one-off ephemeral controls that cannot be represented by a finite named state set.

## Semantic color palette (for GDScript usage)

These colors appear repeatedly in code for gameplay state. Use them for dynamic color choices that are not whole themed control states, such as price deltas, condition labels, warning text, and placeholder text. Fixed component state `StyleBox` resources belong in the theme instead, with GDScript only selecting the named state style.

| Name           | Value                        | Usage                            |
| -------------- | ---------------------------- | -------------------------------- |
| profit_green   | `Color(0.4, 1.0, 0.5)`       | Price gain, positive change      |
| loss_red       | `Color(1.0, 0.4, 0.4)`       | Price loss, negative change      |
| warning_yellow | `Color(0.95, 0.75, 0.3)`     | Warnings, caution                |
| accent_gold    | `Color(0.92, 0.72, 0.18, 1)` | Auction highlight, active accent |
| unknown_gray   | `Color(0.55, 0.58, 0.63, 1)` | Unverified / placeholder         |
| disabled_gray  | `Color(0.45, 0.48, 0.53, 1)` | Disabled controls, muted text    |
| text_secondary | `Color(0.7, 0.7, 0.7, 1)`    | Secondary labels                 |
| text_hint      | `Color(0.6, 0.6, 0.6, 1)`    | Hint / caption text              |

## Rules

1. **Theme-level styling only for static appearance.** Font sizes, default colors, panel backgrounds, button states, container spacing — anything that defines the resting visual identity goes in `main_theme.tres`.

2. **GDScript `add_theme_*_override()` only for dynamic state selection or computed style values.** Runtime state changes may select a named style from the theme (row highlights on hover, selected cargo row, loaded cargo row) or apply a genuinely computed style (cell turns green on valid drop, price changes color based on profit/loss). If a style is applied once in `_ready()` and never changes, it should move to the theme or the `.tscn` file.

3. **Prefer theme inheritance over per-node overrides.** Before adding `theme_override_*` to a node in a `.tscn` file, check whether the theme default already provides the value you want. If the value is close but not exact, consider whether the difference matters or whether the scene should just use the theme default.

4. **Type variations for component-level variants.** When a control needs a named variant (e.g. "HeaderLabel" = Label with font_size 30), define a `theme_type_variation` in the `.tscn` file that matches an entry in `main_theme.tres`. This is preferred over per-node `theme_override_font_sizes/font_size`. Dynamic runtime sizes (parameterized components, ephemeral tooltip nodes) may still use `add_theme_font_size_override()` in GDScript.

5. **Never hardcode `Color()` literals for static UI in GDScript.** Theme resources may define the actual color values for theme-owned styles. If GDScript needs a repeated dynamic semantic color, add it to the semantic palette table above and use the named constant. If it is truly a one-off static node color, add a `theme_override_colors/` in the `.tscn` file, not an inline `Color()` in GDScript.

## Migration approach

Scenes are migrated incrementally. When touching a scene for other work, check for overrides that now match theme defaults and remove them. Priority targets (highest override counts): `storage_scene`, `inspection_scene`, `cargo_scene`, `day_summary_scene`.
