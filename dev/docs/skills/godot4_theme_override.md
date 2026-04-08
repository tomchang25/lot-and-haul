# SKILL: Godot 4 Theme Override Syntax

## Problem

LLMs (including Claude) commonly hallucinate an invalid slash-path syntax for theme overrides in GDScript:

```gdscript
# ❌ WRONG — this is NOT valid GDScript
node.theme_override_constants / separation = 12
node.theme_override_font_sizes / font_size = 14
```

This looks like it was copied from a `.tscn` file but incorrectly pasted into `.gd` code. It will **not compile**.

---

## GDScript (.gd) — Correct Syntax

Use the `add_theme_*_override(property_name: String, value)` methods at runtime.

### Constants (int)
```gdscript
node.add_theme_constant_override("separation", 12)
node.add_theme_constant_override("margin_left", 8)
```

### Font Sizes (int)
```gdscript
node.add_theme_font_size_override("font_size", 14)
```

### Colors (Color)
```gdscript
node.add_theme_color_override("font_color", Color(1, 0, 0))
node.add_theme_color_override("font_color", Color.RED)
```

### StyleBoxes (StyleBox)
```gdscript
var sb := StyleBoxFlat.new()
sb.bg_color = Color.BLUE
node.add_theme_stylebox_override("normal", sb)
```

### Fonts (Font)
```gdscript
node.add_theme_font_override("font", preload("res://fonts/MyFont.ttf"))
```

### Icons (Texture2D)
```gdscript
node.add_theme_icon_override("icon", preload("res://icon.png"))
```

---

## Scene File (.tscn) — Correct Syntax

In `.tscn` files the slash-path form **is** correct and is written directly as a property:

```ini
[node name="HBoxContainer" type="HBoxContainer"]
theme_override_constants/separation = 12

[node name="Label" type="Label"]
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(1, 0, 0, 1)
```

> ⚠️ This syntax is **only valid inside `.tscn` files**. Never write it in `.gd` scripts.

---

## Quick Reference Table

| Category    | GDScript method                            | .tscn property key                        |
|-------------|--------------------------------------------|--------------------------------------------|
| Constant    | `add_theme_constant_override("key", int)`  | `theme_override_constants/key = int`       |
| Font size   | `add_theme_font_size_override("key", int)` | `theme_override_font_sizes/key = int`      |
| Color       | `add_theme_color_override("key", Color)`   | `theme_override_colors/key = Color(...)`   |
| StyleBox    | `add_theme_stylebox_override("key", sb)`   | `theme_override_styles/key = SubResource(…)` |
| Font        | `add_theme_font_override("key", font)`     | `theme_override_fonts/key = ExtResource(…)` |
| Icon        | `add_theme_icon_override("key", tex)`      | `theme_override_icons/key = ExtResource(…)` |

---

## Corrected Example

The original broken snippet fixed:

```gdscript
func _make_price_row(entry: ItemEntry) -> HBoxContainer:
    var price_row := HBoxContainer.new()
    price_row.visible = false
    price_row.add_theme_constant_override("separation", 12)  # ✅

    var ask_lbl := Label.new()
    ask_lbl.text = "Ask: "
    ask_lbl.add_theme_font_size_override("font_size", 14)    # ✅
    price_row.add_child(ask_lbl)
    # ... rest of function
```

---

## Key Rule Summary

- **`.gd` file** → always use `add_theme_*_override(name, value)`
- **`.tscn` file** → use `theme_override_category/property = value`
- Never mix the two syntaxes
