# Localization Implementation

## Goal

Implement the localization architecture defined in `localization_architecture.sketch.md`: a YAML-to-CSV pipeline with locale × block file split, fallback chain resolution, CJK font support, language selector in settings, and systematic replacement of all hardcoded English strings with `tr("KEY")` calls.

## Relational Context

- **`project.godot` owns locale registration** — the `[internationalization]` section and translation resource paths. No other system reads or writes this.
- **`SettingsStore` is the single authority for the persisted locale** — it reads on boot, writes on change. No other system persists or owns the locale setting.
- **`TranslationServer` is the single runtime authority for active locale** — `SettingsStore` calls `TranslationServer.set_locale()`; no other system calls it. Scenes consume via `tr()` only.
- **`main_theme.tres` owns the CJK fallback font** — the font resource file and fallback references are part of the theme. Individual scenes and scripts never set fonts directly (per `theme_standard.md`).
- **Scenes and display helpers consume translations through `tr()` only** — they never reference translation files, `SettingsStore.locale`, or `TranslationServer` directly. This is a read-only consumer relationship.
- **Gameplay YAML → `.tres` pipeline (`yaml_to_tres.py`) must be updated** to pass through `display_name_key` / `description_key` fields as strings. These fields replace the current `display_name` / `description` / `known_text` fields in the generated `.tres` resources.
- **Display call sites** (scripts that currently read `display_name`, `known_text` etc. from data resources) switch to `tr(data.display_name_key)`. The data resource now carries a key string instead of a display string.
- **The tutorial system** (`ScriptDirector` → `tutorial_scripts.gd`) is a separate consumer: its long prose strings are extracted into `*_tutorial.csv` keys. `ScriptDirector` reads keys and calls `tr()` at display time. The `TutorialStep` data shape itself is not changed — only the text content is replaced with key references.
- **`ToastManager` calls** are player-visible only for `show_warning()` and `show_error()` — `show_info()` is debug-only and excluded from localization scope. The toast messages that are player-visible receive key-based text, but the toast system itself is unchanged: it accepts a plain string argument that now comes through `tr()`.
- **EventBus** does not participate in localization — no text passes through events that would need translation.

## Plan Friction

- Settled: No friction found between Plan and codebase. The existing `localization/` directory is empty, `project.godot` has no `[internationalization]` section, `SettingsStore` has no locale field, and no `tr()` calls exist in game code — all exactly as the sketch assumes.

## Design Gaps

- Settled: No outstanding design gaps — the sketch fully specifies all new elements including the fallback algorithm, file structure, key naming conventions, pipeline flow, and locale codes.

## Scope

### Included

1. Localization YAML source files under `localization/source/` for all three locales and all blocks (ui, tutorial, items, clues, locations, affixes, categories, commodities, perks, system).
2. `dev/tools/localization_yaml_to_csv.py` — the compilation script.
3. CJK fallback font integration into `main_theme.tres`.
4. Locale field in `SettingsStore` (persist/load) and language selector in `settings_overlay.tscn`/`.gd`.
5. `project.godot` `[internationalization]` section and translation resource registration.
6. Gameplay YAML field migration (`display_name` → `display_name_key`, etc.) across all YAML files and the `yaml_to_tres.py` pipeline.
7. `tr("KEY")` replacement across `.tscn` scene files and `.gd` scripts.

### Excluded

1. Translation quality — this spec covers the pipeline and code wiring, not authoring correct zh_TW/zh_CN text.
2. Runtime locale auto-detection — the user selects language manually via Settings.
3. Plurals / `ngettext` — not needed by current game strings.
4. Scene-specific layout adjustments for text expansion/shrinkage — deferred as a polish pass after translations exist.
5. `ToastManager.show_info()` strings — these are debug-only and excluded.

## Files to Change

| File                                                    | Size   | Purpose                                                                                                     |
| ------------------------------------------------------- | ------ | ----------------------------------------------------------------------------------------------------------- |
| `project.godot`                                         | Small  | Add `[internationalization]` section with translation resource paths                                        |
| `global/autoloads/settings_store.gd`                    | Small  | Add `locale` var, persist/load in save_settings/load_settings, add `locale_changed` signal                  |
| `game/shared/settings_overlay/settings_overlay.tscn`    | Small  | Add language `OptionButton` row to the settings panel                                                       |
| `game/shared/settings_overlay/settings_overlay.gd`      | Small  | Wire language selector to `TranslationServer.set_locale()`, emit `locale_changed`, connect to SettingsStore |
| `global/theme/main_theme.tres`                          | Small  | Add CJK fallback font resource as `default_font` with fallback chain (Noto Sans → Noto Sans CJK SC/TC)      |
| All `.tscn` files with `text="..."`                     | Medium | Replace hardcoded English text with `tr("UI_KEY")` — Godot inspector edit                                   |
| `game/shared/item_display/item_entry_display_helper.gd` | Medium | Replace all hardcoded strings (`"???"`, `"Unknown Item"`, format strings) with `tr()` calls                 |
| `global/constants/economy.gd`                           | Small  | Replace `RARITY_NAME` values with `tr()` calls via a static method                                          |
| `global/autoloads/director/tutorial_scripts.gd`         | Large  | Extract all hardcoded prose strings into `tr("TUT_KEY")` calls                                              |
| All gameplay YAML files (see below)                     | Medium | Replace `display_name`/`description`/`known_text` fields with `_key` variants                               |
| `dev/tools/yaml_to_tres.py`                             | Medium | Pass through `*_key` string fields to `.tres` resources                                                     |
| Various `.gd` display call sites                        | Large  | Replace `data.display_name` with `tr(data.display_name_key)` at all read points                             |
| New: `localization/source/en/*.yaml` (6+ files)         | Medium | English translation sources per block                                                                       |
| New: `localization/source/zh_TW/*.yaml` (6+ files)      | Medium | zh_TW translation sources per block                                                                         |
| New: `localization/source/zh_CN/*.yaml` (6+ files)      | Medium | zh_CN translation sources per block                                                                         |
| New: `dev/tools/localization_yaml_to_csv.py`            | Large  | YAML → CSV compilation script with fallback resolution and validation                                       |
| New: `localization/generated/` (directory)              | Small  | Output directory for compiled CSV files                                                                     |
| New: `localization/localization_config.yaml`            | Small  | Fallback chain config and block list                                                                        |

### Gameplay YAML files needing key migration

- `data/yaml/clues.yaml` — `known_text` → `known_text_key`
- `data/yaml/affixes.yaml` — `display_name` → `display_name_key`
- `data/yaml/category_data.yaml` — `display_name` → `display_name_key`
- `data/yaml/location_data.yaml` — `display_name` → `display_name_key`, `description` → `description_key`
- `data/yaml/commodity_data.yaml` — `display_name` → `display_name_key`
- `data/yaml/perk_data.yaml` — `display_name` → `display_name_key`, `description` → `description_key`

### Scene files needing `text=` → `tr()` replacement

```
game/meta/start/start_page_scene.tscn
game/meta/storage/storage_scene.tscn
game/meta/day_summary/day_summary_scene.tscn
game/meta/hub/hub_scene.tscn
game/meta/knowledge/knowledge_hub.tscn
game/meta/knowledge/attribute_view/attribute_view.tscn
game/meta/knowledge/perk_view/perk_view.tscn
game/meta/location_select/location_select.tscn
game/meta/location_select/location_card/location_card.tscn
game/meta/vehicle/vehicle_hub.tscn
game/meta/vehicle/car_shop/car_shop.tscn
game/meta/vehicle/car_select/car_select.tscn
game/meta/vehicle/car_card/car_card.tscn
game/meta/customer_sell/customer_sell_scene.tscn
game/run/auction/auction_scene.tscn
game/run/cargo/cargo_scene.tscn
game/run/inspection/inspection_scene.tscn
game/run/lot_browse/lot_browse_scene.tscn
game/run/lot_browse/lot_card/lot_card.tscn
game/run/reveal/reveal_scene.tscn
game/run/run_review/run_review_scene.tscn
game/run/location_entry/location_entry_scene.tscn
game/shared/item_display/item_card/item_card.tscn
game/shared/item_display/item_row/item_row.tscn
game/shared/settings_overlay/settings_overlay.tscn
game/shared/fatal_error/fatal_error.tscn
```

### Script files needing `.text =` → `tr(` replacement

Key scripts (non-exhaustive, same pattern across all game scripts):

```
game/meta/run_review/run_review.gd
game/meta/storage/service_panel.gd
game/meta/storage/storage_slot.gd
game/meta/day_summary/day_summary.gd
game/meta/customer_sell/customer_sell.gd
game/meta/location_select/location_select.gd
game/run/auction/auction.gd
game/run/auction/auction_player_panel.gd
game/run/cargo/cargo.gd
game/run/inspection/inspection.gd
game/run/lot_browse/lot_browse.gd
game/run/lot_browse/lot_card/lot_card.gd
game/run/reveal/reveal.gd
game/run/run_review/run_review.gd
game/run/location_entry/location_entry.gd
game/shared/item_display/item_entry_display_helper.gd
game/shared/settings_overlay/settings_overlay.gd
global/autoloads/director/tutorial_scripts.gd
global/constants/economy.gd
```

## Implementation Notes

### phase_order

The work is ordered so that the pipeline and infrastructure land first, then content migration proceeds block by block. This prevents a state where en strings are already removed from code but translations cannot be loaded yet.

**Phase 0 — Pipeline & Infrastructure**

1. Create `localization/localization_config.yaml`:

   ```yaml
   locales:
     - id: en
       fallbacks: []
       label: English
     - id: zh_TW
       fallbacks: [zh_CN, en]
       label: 繁體中文
     - id: zh_CN
       fallbacks: [zh_TW, en]
       label: 简体中文
   blocks:
     - ui
     - tutorial
     - items
     - clues
     - locations
     - affixes
     - categories
     - commodities
     - perks
     - system
   ```

2. Implement `dev/tools/localization_yaml_to_csv.py`:
   - Read `localization_config.yaml`
   - For each locale × block, load the YAML source
   - Validate: no duplicate keys per locale, no null values
   - Validate: all locales have identical key sets after resolution
   - Resolve fallback chain per the algorithm in the sketch
   - Write `localization/generated/{block}.csv`
    - Write `localization/report.json`

3. Create empty/seed YAML source files for all locales × blocks under `localization/source/`.

4. Add CJK fallback font:
   - Download or place Noto Sans (or similar) and Noto Sans CJK SC/TC in `global/theme/fonts/`
   - Create a `DynamicFont` with Noto Sans as primary, Noto Sans CJK SC as first fallback, Noto Sans CJK TC as second fallback
   - Reference this font in `main_theme.tres` as `default_font`

5. Update `project.godot` — add:

   ```ini
   [internationalization]
   locale/translation_remotes=enabled
   locale/test="en"
   ```

6. Import the generated CSVs as `.translation` resources in the Godot editor (or register paths in `project.godot`).

**Phase 1 — Settings & Locale Wiring**

7. Add `locale` field to `SettingsStore`:

   ```gdscript
   var locale: String = "en":
       set(value):
           if locale == value: return
           locale = value
           TranslationServer.set_locale(value)
           get_tree().propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
   ```

   Persist in `save_settings()` and load in `load_settings()`.

8. Add language `OptionButton` to `settings_overlay.tscn` — a new row below the audio section with label "Language" and options for English/繁體中文/简体中文, storing locale code in item metadata.

9. Wire in `settings_overlay.gd`.

**Phase 2 — UI Block Translation**

10. Extract all `text="..."` from `.tscn` files in `game/shared/settings_overlay/` and `game/meta/start/` and replace with `tr("UI_*")`.

11. Add corresponding keys to `localization/source/en/en_ui.yaml`, `zh_TW/zh_TW_ui.yaml`, `zh_CN/zh_CN_ui.yaml`.

12. Repeat for remaining scene files.

**Phase 3 — Display Helpers & Constants**

13. `economy.gd`: Replace `RARITY_NAME` dictionary values with a static method:

    ```gdscript
    static func rarity_display_name(rarity: Economy.Rarity) -> String:
        match rarity:
            Economy.Rarity.COMMON: return tr("SYS_RARITY_COMMON")
            ...
    ```

14. `item_entry_display_helper.gd`: Replace `UNKNOWN_TEXT`, `"Unknown Item"`, `"Unknown %s"`, `"Condition: %s (%s)"`, `"%.1f kg"`, `"%d  %s"`, `"%d%%"` with `tr("SYS_*")` calls.

**Phase 4 — Gameplay YAML Migration**

15. For each YAML file, rename display text fields to key fields:
    - `display_name` → `display_name_key`
    - `description` → `description_key`
    - `known_text` → `known_text_key`

16. Update `dev/tools/yaml_to_tres.py` to pass through `*_key` string fields into the `.tres` resource.

17. Add key values to `en_*` localization YAML, matching the exact keys used in gameplay YAML.

18. Update all `.gd` call sites that read `display_name`/`description`/`known_text` to use `tr(data.display_name_key)` etc.

**Phase 5 — Tutorial Block**

19. Extract all hardcoded strings from `tutorial_scripts.gd` into `tr("TUT_*")` calls. Each tutorial step's text becomes a key.

20. Add keys to `en_tutorial.yaml`. The tutorial text is large (~150 translatable lines), so this block is the biggest single extraction pass.

**Phase 6 — Compilation & Verification**

21. Run `localization_yaml_to_csv.py` end-to-end. Verify:
    - All blocks generate valid CSV
    - No hard-missing keys
    - `localization/report.json` is produced

22. Boot the game with `locale/test="zh_TW"` in `project.godot`. Verify CJK text renders, Settings overlay shows 繁體中文, and navigation works.

23. Boot with `locale/test="zh_CN"` and repeat.

## Edge Cases

| Case                                                           | Expected Handling                                                                                                                           |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Missing key in en (root locale)                                | Pipeline fails — en defines the canonical key set                                                                                           |
| Key present in en but empty `""`                               | Pipeline outputs empty string for en, propagates to fallback locales                                                                        |
| Fallback locale has `""`, locale explicitly defines the key    | Locale's own definition wins — fallback is only consulted for missing keys                                                                  |
| `null` value in YAML source                                    | Pipeline validator rejects and fails                                                                                                        |
| Duplicate key within a single locale YAML                      | Pipeline validator rejects and fails                                                                                                        |
| Different key sets across locales (locale A has keys en lacks) | Pipeline validator rejects and fails — en defines the canonical set                                                                         |
| Language switch during gameplay                                | `NOTIFICATION_TRANSLATION_CHANGED` propagates; existing scenes translate their current text. Open overlay remains open with updated labels. |
| Language selector shows current saved locale                   | `SettingsStore.locale` read on `_ready()` of settings overlay; `_language_option.select()` matches stored value                             |
| New scene added after localization is complete                 | Author must use `tr("KEY")` from the start — no hardcoded text                                                                              |
| Font file not found                                            | Godot falls back to default font silently; CJK characters may not render. This is a missing-asset error caught by the CI check.             |
| Empty YAML source file for a locale × block                    | Pipeline treats as "this locale has no keys for this block" — 0 keys contributed. If final key set is incomplete vs en, pipeline fails.     |

## Acceptance Criteria

1. Running `dev/tools/localization_yaml_to_csv.py` with complete source YAML files generates valid CSV files under `localization/generated/` with no errors, and produces a `localization/report.json`.

2. Running the script with a missing key in a non-en locale triggers a warning in `report.json` showing fallback resolution. Running with a missing key in en fails the script.

3. Setting language to 繁體中文 in Settings shows zh_TW text throughout the game (title screen, settings, storage, auction, inspection, cargo, lot browse, knowledge, vehicles, customer sell, day summary, tutorial).

4. Setting language to 简体中文 shows zh_CN text throughout the game, falling back to zh_TW then en for missing entries.

5. When zh_TW has `""` for a key, that text is blank in both zh_TW and zh_CN modes, and the English text appears correctly in en mode.

6. The language selection persists across game restarts.

7. CJK characters display correctly with no missing-glyph boxes (□) in any UI element.

8. The game boots and is fully playable in all three locales without crashes or missing-text errors.

9. No hardcoded English player-visible text remains in `.tscn` or `.gd` files — verified by searching `text = "` in `.tscn` files and `\.text = "` in `.gd` files for strings that are not wrapped in `tr()`.
