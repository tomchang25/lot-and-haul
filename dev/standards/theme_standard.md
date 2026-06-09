# Theme Standard

The project uses a single centralized theme at `global/theme/main_theme.tres`, set as the project-level theme via `project.godot → [gui] theme/custom`. Every scene inherits it automatically.

## What the theme provides

**Colors** (Label, Button, RichTextLabel, Tooltip):

- Primary text: `Color(0.88, 0.88, 0.92, 1)` — cool off-white
- Hover text: `Color(1, 1, 1, 1)` — pure white
- Pressed text: `Color(0.75, 0.75, 0.8, 1)` — dimmed
- Disabled text: `Color(0.45, 0.48, 0.53, 1)` — muted slate
- Tooltip text: `Color(0.8, 0.8, 0.85, 1)` — slightly dimmer than primary

**Font sizes** — default 16. Scenes that need other sizes use `theme_override_font_sizes/font_size` on the specific node.

**Typography scale** (reference, not enforced by type variations yet):

| Token      | Size | Usage                    |
| ---------- | ---- | ------------------------ |
| display    | 48   | Banner titles            |
| title      | 32   | Page titles              |
| heading_1  | 28   | Major section headers    |
| heading_2  | 22   | Sub-section headers      |
| heading_3  | 20   | Minor section headers    |
| body_large | 18   | Primary body text        |
| body       | 16   | Default / secondary body |
| detail     | 14   | Card content, tooltips   |
| caption    | 13   | Small labels             |
| small      | 12   | Tooltip detail           |
| tiny       | 11   | Tiny labels              |
| micro      | 9    | Micro text, debug        |

**Container separation defaults**:

- HBoxContainer / VBoxContainer: 8
- GridContainer: h=6, v=6
- HSeparator / VSeparator: 8

**StyleBoxes**:

- `PanelContainer/panel` — dark surface (`0.15, 0.15, 0.18`), 1px border, 4px radius
- `Button` — all five states (normal, hover, pressed, disabled, focus)
- `TooltipPanel` — near-black (`0.1, 0.1, 0.12`), 3px radius
- `HSeparator/VSeparator` — 1px line matching border color

## Semantic color palette (for GDScript usage)

These colors appear repeatedly in code for gameplay state. They belong in GDScript constants, not in the theme resource, because they represent runtime state — not static UI style.

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

2. **GDScript `add_theme_*_override()` only for dynamic state.** Runtime state changes (cell turns green on valid drop, row highlights on hover, price changes color based on profit/loss) are the only legitimate use of code-level overrides. If a style is applied once in `_ready()` and never changes, it should move to the theme or the `.tscn` file.

3. **Prefer theme inheritance over per-node overrides.** Before adding `theme_override_*` to a node in a `.tscn` file, check whether the theme default already provides the value you want. If the value is close but not exact, consider whether the difference matters or whether the scene should just use the theme default.

4. **Type variations for component-level variants (future).** When a control needs a named variant (e.g. "HeaderLabel" = Label with font_size 28), define a type variation in the theme rather than overriding every instance. This is not yet implemented — for now, per-node overrides are acceptable until we build out variations.

5. **Never hardcode Color() literals for static UI.** If you need a new static color, add it to the semantic palette table above and use the named constant. If it's truly a one-off, add a `theme_override_colors/` in the `.tscn` file — not an inline `Color()` in GDScript.

## Migration approach

Scenes are migrated incrementally. When touching a scene for other work, check for overrides that now match theme defaults and remove them. Priority targets (highest override counts): `storage_scene`, `inspection_scene`, `cargo_scene`, `day_summary_scene`.
