# Component Scene Standard

This document defines layout, previewability, default content, and data-source rules for reusable `.tscn` UI components.

Applies to:

- Reusable UI component scenes
- Panel/card/row/sidebar components instanced by block scenes
- Component-like child scenes under `game/` and `stage/`

Does **not** apply to:

- Full-screen block scene roots
- True overlays, popups, dialogs, and windows whose job is to cover or float above a scene
- Pure logic scripts with no `.tscn` owner

---

# 1. Component Ownership

A reusable component defines its own internal node tree and intrinsic minimum size. The parent scene decides where the component appears, how much extra space it receives, and whether it participates in a full-screen layout.

Component `.tscn` roots should use `custom_minimum_size` when they need a visible standalone footprint. Parent scene instances should use `layout_mode`, `size_flags_*`, parent-side `custom_minimum_size`, or anchors to place and expand the component in context.

Do not encode parent placement into the component root. A sidebar component should not know that it lives on the right side of a feature scene; a row component should not know that its list expands vertically; a car panel should not make itself full-screen because the parent scene has a full-screen main area.

---

# 2. Root Layout

Reusable component roots must not default to full-screen anchors.

Avoid these on non-overlay component roots:

```text
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
```

The exception is a component whose actual semantic role is full-screen or floating overlay UI: modal shells, tooltip popups, settings overlays, confirmation dialogs, or scene-level testbed wrappers.

Non-full-screen component roots should start at `(0,0)`. Do not use root `position`, `offset_*`, or margins to place a reusable component where one current parent happens to need it. If an instance needs a specific location, set that on the instance in the parent `.tscn`.

---

# 3. Previewable Defaults

Opening a component `.tscn` by itself should reveal what the component is for. It does not need real gameplay data, but it must not look blank, invisible, or full-screen by accident.

Every user-visible dynamic field needs a neutral placeholder in the `.tscn` or an immediately visible empty state. Good placeholders are explicit but not real data:

```text
text = "No item selected"
text = "Value: -"
text = "Car: ?x?"
text = "Item rows appear here"
text = "Receipt details will appear here."
```

Avoid blank strings for visible labels that `_apply()` will later populate. Blank labels make missed `_apply()` writes invisible during review and make standalone component previews useless.

Dynamic containers should show their structure before data arrives. Use a visible empty-state label, disabled placeholder controls, or a small placeholder grid when that makes the component understandable. The runtime rebuild path may remove or hide those placeholders once real rows, cells, or buttons are available.

---

# 4. Default Visibility

Reusable component roots and their primary structural sections should be visible in the `.tscn` by default.

Do not set a component root or main content container to `visible = false` just because the parent scene will later decide when to show it. If runtime state starts hidden, set that state in `_ready()`, `setup()`, `_apply()`, or `reset()` from the component's private state, not by making the editor/default artifact invisible.

Allowed `visible = false` cases:

- True popups, dialogs, overlays, and windows that are normally opened by `popup()` or a dedicated show method
- Optional child affordances whose hidden state is the meaningful neutral preview, such as an inactive badge next to visible surrounding content
- Debug-only nodes created by code behind `Debug.enabled`, per `dev/standards/debug_standard.md`

If most of a component is hidden by default, reviewers should treat that as a smell: either the component is really a popup/overlay, or it needs a visible neutral preview state.

---

# 5. Data Sources And Debuggability

Reusable components should be data-applied by their parent through `setup()` or a narrow public API. They should not fetch feature-manager state just to populate their normal view.

Component-level previewability comes from neutral `.tscn` placeholders, not production fake gameplay data. Full-flow module debug data belongs in a fixture or testbed beside the feature scene, such as `*_fixtures.gd` plus an entry in `stage/testbeds/testbed_registry.gd`.

Do not seed global managers from a production component script. If a component needs richer isolated debugging than placeholders can provide, create a dedicated preview/testbed scene that instantiates the component and feeds it fixture data.

---

# 6. Setup And Apply Contract

Reusable components must support `setup()` being called before or after `add_child()`.

Use the standard shape from `dev/standards/block_scene_architecture_standard.md`:

- `setup()` stores arguments into private state and does not touch `@onready` nodes directly
- `_ready()` connects signals first, then calls `_apply()` if private state was already supplied
- `_apply()` is the only function that paints node references from private state
- `refresh()` calls `_apply()` only when `is_node_ready()` is true

This keeps parent scenes free to instantiate, set up, connect, and add components in the safe order required by the block scene architecture standard.

---

# 7. Relationship To Other Standards

Node ownership and runtime `add_child()` exceptions are governed by `dev/standards/scene_node_source_standard.md`.

Theme resources, static style, and semantic colors are governed by `dev/standards/theme_standard.md`.

Component declaration order, signal connection order, and the `setup()` / `_apply()` pattern are governed by `dev/standards/block_scene_architecture_standard.md`.
