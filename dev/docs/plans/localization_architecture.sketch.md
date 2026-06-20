# Localization Architecture

## Goal

Add a full localization pipeline to Lot & Haul supporting en, zh_TW, and zh_CN, with a P社-style locale × block file split, a YAML-backed translation source that compiles to Godot CSV, and a fallback chain resolution system so the player never sees a raw key.

## Requirements

1. Gameplay YAML files (clues, affixes, categories, locations, commodities, perks, tutorials) must store only stable translation keys, never human-readable text. The display text is resolved at runtime via `tr(key)`.

2. Translation source files follow a `{locale}/{locale}_{block}.yaml` structure inside `localization/source/` so that different locales and content blocks never collide in git and can be worked on independently.

3. A build pipeline (`localization_yaml_to_csv.py`) compiles the per-locale YAML blocks into Godot-ready CSV files under `localization/generated/`, applying a configurable fallback chain during compilation so every cell in the CSV has a non-empty value by generation time.

4. Missing keys and explicit-empty strings are distinct: a missing key triggers fallback resolution; an explicit `""` value means "intentionally blank for this locale, do not fallback, output empty string". Explicit empties propagate through the fallback chain — if locale A falls back to locale B and locale B has `""`, locale A gets `""`.

5. `en` is the root fallback locale with no fallback of its own. `zh_TW` falls back to `zh_CN` then `en`. `zh_CN` falls back to `zh_TW` then `en`.

6. Every locale × block must have identical key coverage after fallback resolution. If a key is missing from a locale and all its fallbacks, the pipeline fails.

7. A CJK-capable fallback font is registered in the theme so that zh_TW and zh_CN display correctly with no missing-glyph boxes.

8. A language selector is added to the Settings overlay. Changing the language calls `TranslationServer.set_locale()` and propagates `NOTIFICATION_TRANSLATION_CHANGED` to refresh on-screen text.

9. All hardcoded English strings in `.tscn` and `.gd` files are replaced with `tr("KEY")` calls using stable namespaced keys.

## Design

### Translation key namespace convention

Keys use a `BLOCK_SCOPE_DESCRIPTION` pattern with uppercase snake_case, namespace-prefixed by block to guarantee no collisions across blocks:

| Block       | Prefix   | Example                     |
| ----------- | -------- | --------------------------- |
| UI          | `UI_`    | `UI_SETTINGS_TITLE`         |
| Tutorial    | `TUT_`   | `TUT_HUB_INTRO_BODY`        |
| Items       | `ITEM_`  | `ITEM_LEATHER_HANDBAG_NAME` |
| Clues       | `CLUE_`  | `CLUE_HANDBAG_LEATHER_TEXT` |
| Locations   | `LOC_`   | `LOC_SUBURBAN_STORAGE_NAME` |
| Affixes     | `AFFIX_` | `AFFIX_RUSTIC_NAME`         |
| Categories  | `CAT_`   | `CAT_HANDBAG_NAME`          |
| Commodities | `CMD_`   | `CMD_USED_BUNDLE_NAME`      |
| Perks       | `PERK_`  | `PERK_DEALERS_EYE_NAME`     |
| System      | `SYS_`   | `SYS_UNKNOWN_ITEM`          |

A key is **never** the English text itself. `"Settings"` is not a key; `UI_SETTINGS_TITLE` is.

### Fallback chain

```
en:     []
zh_TW:  [zh_CN, en]
zh_CN:  [zh_TW, en]
```

### Resolution algorithm

```
resolve(locale, key):
  if locale source has key:
    return locale source[key]   # "" is a valid value, stop here

  for fallback_locale in fallback_chain[locale]:
    if fallback_locale source has key:
      return fallback_locale source[key]   # "" is a valid value, stop here

  fail generation
```

### Locale codes

| Internal | Godot locale | Display label |
| -------- | ------------ | ------------- |
| `en`     | `en`         | English       |
| `zh_TW`  | `zh_TW`      | 繁體中文      |
| `zh_CN`  | `zh_CN`      | 简体中文      |

### Pipeline

```
localization/source/{locale}/{locale}_{block}.yaml
    ↓
localization_yaml_to_csv.py
    ├── validates: no duplicate keys within a locale
    ├── validates: no null values
    ├── resolves fallback chain
    ├── validates: all locales have identical key sets after resolution
    ├── emits: localization/report.json (missing / explicit-empty / fallback-filled)
    └── emits: localization/generated/{block}.csv
    ↓
Godot import as .translation resources
    ↓
TranslationServer ↔ tr("KEY")
```

The pipeline source lives at `dev/tools/localization_yaml_to_csv.py` alongside the existing `yaml_to_tres.py`.

## Sketch (non-normative)

### Source file structure

```
localization/source/
  en/
    en_ui.yaml
    en_tutorial.yaml
    en_items.yaml
    en_clues.yaml
    en_locations.yaml
    en_system.yaml

  zh_TW/
    zh_TW_ui.yaml
    zh_TW_tutorial.yaml
    zh_TW_items.yaml
    zh_TW_clues.yaml
    zh_TW_locations.yaml
    zh_TW_system.yaml

  zh_CN/
    zh_CN_ui.yaml
    zh_CN_tutorial.yaml
    zh_CN_items.yaml
    zh_CN_clues.yaml
    zh_CN_locations.yaml
    zh_CN_system.yaml
```

### Example source YAML

```yaml
# localization/source/en/en_locations.yaml
en:
  LOC_SUBURBAN_STORAGE_NAME: Suburban Storage
  LOC_SUBURBAN_STORAGE_DESC: A quiet self-storage facility on the edge of town.
```

```yaml
# localization/source/zh_TW/zh_TW_locations.yaml
zh_TW:
  LOC_SUBURBAN_STORAGE_NAME: 郊區倉儲
  LOC_SUBURBAN_STORAGE_DESC: ""
```

```yaml
# localization/source/zh_CN/zh_CN_locations.yaml
zh_CN:
  LOC_SUBURBAN_STORAGE_NAME: 郊区仓储
  # LOC_SUBURBAN_STORAGE_DESC missing → fallback to zh_TW → ""
```

### Generated CSV

```csv
keys,en,zh_TW,zh_CN
LOC_SUBURBAN_STORAGE_NAME,Suburban Storage,郊區倉儲,郊区仓储
LOC_SUBURBAN_STORAGE_DESC,A quiet self-storage facility on the edge of town.,,
```

zh_CN gets `""` because its fallback `zh_TW` has explicit empty `""`.

### Generated report

```json
{
	"missing_filled": {
		"zh_CN": {
			"LOC_SUBURBAN_STORAGE_DESC": { "from": "zh_TW", "value": "" }
		}
	},
	"explicit_empty": {
		"zh_TW": ["LOC_SUBURBAN_STORAGE_DESC"]
	},
	"hard_missing": []
}
```

### Changes to gameplay YAML

```yaml
# Before (data/yaml/location_data.yaml)
- id: suburban_storage
  display_name: Suburban Storage
  description: A quiet self-storage facility on the edge of town.

# After
- id: suburban_storage
  display_name_key: LOC_SUBURBAN_STORAGE_NAME
  description_key: LOC_SUBURBAN_STORAGE_DESC
```

The pipeline script `yaml_to_tres.py` stores the key string in the `.tres` resource. At display time:

```gdscript
# Before
label.text = location.display_name

# After
label.text = tr(location.display_name_key)
```

### Changes to display helper

```gdscript
# item_entry_display_helper.gd, before
const UNKNOWN_TEXT := "???"
# ...
return "Unknown Item"
return "Unknown " + body_text
return "Condition:  %s (%s)" % [text, condition_secondary_text(entry)]

# After
const UNKNOWN_TEXT := tr("SYS_UNKNOWN_PLACEHOLDER")
# ...
return tr("SYS_UNKNOWN_ITEM")
return tr("SYS_UNKNOWN_FORMAT") % body_text
return tr("SYS_CONDITION_FORMAT") % [text, condition_secondary_text(entry)]
```

### Changes to settings overlay

```gdscript
# settings_overlay.gd, new language selector handler
func _on_language_selected(index: int) -> void:
    var locale := _language_option.get_item_metadata(index)
    TranslationServer.set_locale(locale)
    SettingsStore.locale = locale
    SettingsStore.save_settings()
    get_tree().call_deferred("propagate_notification",
        NOTIFICATION_TRANSLATION_CHANGED)
```

### Theme font setup

```gdscript
# Font resource: a dynamic font with Noto Sans as base and Noto Sans CJK SC/TC as fallback
# Registered in main_theme.tres as default_font
```

### Compilation report validation

```python
# dev/tools/localization_yaml_to_csv.py

FALLBACK_CHAIN = {
    "en": [],
    "zh_TW": ["zh_CN", "en"],
    "zh_CN": ["zh_TW", "en"],
}

def resolve(locale, key, sources):
    if key in sources[locale]:
        return sources[locale][key]
    for fb in FALLBACK_CHAIN[locale]:
        if key in sources[fb]:
            return sources[fb][key]
    raise KeyError(f"Hard missing: {locale}/{key}")
```

## Non-Goals

1. Runtime language switching without scene reload — Godot's `NOTIFICATION_TRANSLATION_CHANGED` is sufficient for Phase 1. Scene-by-scene polish is deferred.

2. Translation quality or completeness for any locale beyond en — the pipeline produces valid CSVs for zh_TW and zh_CN but does not guarantee the translations themselves are correct. That is an editorial concern.

3. Runtime locale auto-detection from system settings — the user picks their language in Settings explicitly. Auto-detect is a future quality-of-life addition.

4. Per-locale font switching — one CJK-capable font serves all three locales. Different fonts per locale would add unnecessary complexity for a 3-locale scope.

5. Plurals / `ngettext` — Godot's CSV format has limited plural support and none of the current game strings require it. If needed later, it can be added per-key.

## Acceptance Criteria

1. Every translatable string in the game uses `tr("KEY")` — no hardcoded English text remains in `.tscn` or `.gd` files visible to the player.

2. Setting the language to 繁體中文 shows zh_TW translations throughout the game, with missing keys resolved via zh_CN first, then en.

3. Setting the language to 简体中文 shows zh_CN translations throughout the game, with missing keys resolved via zh_TW first, then en.

4. An explicit empty string `""` in zh_TW causes that specific text to appear blank when either zh_TW or zh_CN (via fallback) is selected.

5. A key missing from all three locales causes the build pipeline to fail with a clear error message.

6. The Settings overlay has a language dropdown that persists across sessions.

7. The game displays CJK characters (Chinese text) without missing-glyph boxes.

8. All gameplay YAML files store `display_name_key` / `description_key` etc. instead of raw display text.
