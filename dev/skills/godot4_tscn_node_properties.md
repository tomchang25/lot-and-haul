# SKILL: Godot 4 .tscn Node Property Placement

## Problem

LLMs commonly put node flags like `unique_name_in_owner` inside the `[node ...]` header line. This is wrong — Godot 4 only allows `name`, `type`, `parent`, `instance`, and `unique_id` as header attributes. Everything else is a property and must appear on its own line below the header.

---

## unique_name_in_owner

Enables `%NodeName` access from the owner scene. Must be a **property line**, not a header attribute.

```
# ❌ WRONG — attribute in header
[node name="PlayButton" type="Button" parent="RootVBox/ButtonsVBox" unique_name_in_owner=true unique_id=1100000006]
custom_minimum_size = Vector2(280, 56)

# ✅ CORRECT — property on its own line
[node name="PlayButton" type="Button" parent="RootVBox/ButtonsVBox" unique_id=1100000006]
unique_name_in_owner = true
custom_minimum_size = Vector2(280, 56)
```

---

## Valid header attributes (exhaustive)

| Attribute      | Example                          |
|----------------|----------------------------------|
| `name`         | `name="MyNode"`                  |
| `type`         | `type="Control"`                 |
| `parent`       | `parent="RootVBox/Footer"`       |
| `instance`     | `instance=ExtResource("1_scn")`  |
| `unique_id`    | `unique_id=1100000006`           |

Everything else — `unique_name_in_owner`, `script`, `layout_mode`, `visible`, and all other node properties — goes **below** the header as `key = value`.

---

## Key Rule

> If it is not `name`, `type`, `parent`, `instance`, or `unique_id` → it is a property, not an attribute. Put it on its own line.
