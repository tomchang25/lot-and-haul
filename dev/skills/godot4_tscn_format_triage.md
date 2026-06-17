# SKILL: Godot 4 .tscn Format Triage

## Problem

When a user says a `.tscn` file's "format" is broken, LLMs often over-focus on parser syntax and repeatedly re-read a scene that is already syntactically valid. In UI work, "format" often means the visual/layout formatting is broken: cramped labels, missing size flags, unstable container sizing, inconsistent placeholder text, or encoding-prone display markers.

---

## Triage Workflow

1. Read the target `.tscn`, its paired `.gd` script, and one or two nearby similar scene files.
2. Check structural basics once: `[gd_scene]`, `ext_resource` ids, node parent paths, node names used by `%UniqueName`, invalid `[connection]` blocks, and Color literals as described in [Color Literals](#color-literals).
3. Run the standards linter on the target scene.
4. If syntax and lint are clean, stop looping on parser-format theories. Reinterpret "format broken" as likely visual/layout formatting.
5. Make the smallest plausible layout-normalization pass.
6. Verify with the standards linter and `git diff --check`.

---

## Layout-Normalization Pass

Prefer small, explicit fixes that make a compact UI scene stable:

- Add explicit `custom_minimum_size` on compact cards, labels, icons, and fixed-width cells.
- Add relevant `size_flags_horizontal` and `size_flags_vertical` when a child should fill or expand inside a container.
- Add container `theme_override_constants/separation` and `alignment` when row/column spacing is ambiguous.
- Normalize placeholder text, usually `"-"` instead of padded variants like `" - "` unless the existing UI pattern requires padding.
- For any color-related scene edit, follow [Color Literals](#color-literals).
- Avoid non-ASCII UI markers in newly edited `.tscn` text unless the file or project already establishes that marker style.
- Keep signal wiring in `.gd`; do not add `[connection]` blocks to fix layout.

---

## Color Literals

In hand-authored `.tscn` edits, always write colors with an explicit alpha channel:

```tscn
Color(r, g, b, a)
```

Do not write three-channel colors in `.tscn` files:

```tscn
Color(r, g, b)
```

When a scene fails to open and Godot points at a line containing a color value, check for missing alpha before chasing unrelated `SubResource`, style override, UID, or parser theories.

---

## What Not To Do

- Do not repeatedly inspect raw bytes, line endings, and invisible characters after one clean check unless there is an actual parse/import error.
- Do not ask the user to clarify before making a reasonable layout-format fix when they explicitly ask you to fix it.
- Do not add broad compatibility code or rewrite the scene hierarchy if a few size/spacing properties solve the issue.

---

## Verification

Run:

```bash
python3 dev/tools/lint_standards.py --root /workspace --files /workspace/path/to/scene.tscn
git -C /workspace diff --check -- path/to/scene.tscn
```

If the change affects actual UI placement and the result remains uncertain, use the safe `/tmp` Godot screenshot procedure from `dev/agent_rules/godot_screenshot_check.md` rather than running Godot against the mounted workspace.

---

## Key Rule

After one clean syntax/lint pass, "`.tscn` format broken" should trigger a minimal visual layout normalization, not an endless parser-format investigation.
