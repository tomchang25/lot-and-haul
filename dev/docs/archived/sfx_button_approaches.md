# HUD Button Default SFX — Current State & Alternative Approaches

## Background

GDScript Godot 4.6 專案，目前需要一個機制讓所有 HUD/UI 按鈕在被按下時自動播放預設的點擊音效（click SFX），不需要每個場景各自寫 code。部分按鈕需要播語義特定的音效（如 bid_confirm、reveal_good），此時應跳過預設 click。

## Current Approach: ClickBinder Autoload

已實作且在線。一個 autoload node，監聽 `SceneRouter.scene_changed`，每次場景切換時遞迴走訪整棵 scene tree，對每個 `Button` 節點連接 `pressed` signal 到一個共用的 `AudioManager.play_event(CLICK)` 調用。

### 檔案

- `global/autoloads/audio_manager/click_binder.gd` (31 lines)
- 註冊於 `project.godot` L29：`ClickBinder="*res://global/autoloads/audio_manager/click_binder.gd"`

### 運作原理

```
SceneRouter._navigate()
  → change_scene_to_packed()
  → scene_changed.emit()
    → ClickBinder._on_scene_changed()
      → _walk(scene_root)                # 遞迴遍歷整棵樹
        → if node is Button:
            if not meta("sfx_click_ignore"):
                pressed.connect(_on_click)  # idempotent (用 is_connected guard)
                    → AudioManager.play_event(CLICK)
```

### Opt-out 機制

需要語義特定音效的按鈕在 `_ready()` 裡設 `set_meta("sfx_click_ignore", true)`，然後在自己 handler 裡直接調 `AudioManager.play_event(SPECIFIC_EVENT)`。

目前 opt-out 的按鈕（3 處）：
- `game/run/auction/auction_scene.gd:102` — bid button → 自己播 BID_CONFIRM
- `game/run/reveal/reveal_scene.gd:47` — reveal button → 自己播 REVEAL_GOOD
- `game/run/reveal/reveal_scene.gd:49` — continue button

### 問題

1. **非 Godot 慣例**：按鈕發聲是完全隱式的 side effect，場景程式碼裡看不到任何音效連接。違反 Godot 的 explicit signal wiring 慣例。
2. **Opt-out 容易被遺忘**：meta key `sfx_click_ignore` 是一個字串合約，沒有編譯期檢查，新場景作者可能根本不知道這個機制存在。
3. **每次場景切換都遞迴走樹**：對小專案無感，但語義上「自動掃描整棵樹來補連接」是一個少見的 pattern。
4. **雙重連接的脆弱性**：ClickBinder 用 `is_connected` 防重複，但如果某個按鈕在場景載入後才動態生成，ClickBinder 不會再掃它（除非該場景自己又 emit scene_changed，但那個 signal 是給場景切換用的）。

## Alternative A: Custom SfxButton Class（推薦）

建立一個繼承 `Button` 的 class，在 `_ready()` 裡自己連接 `pressed`：

```gdscript
class_name SfxButton
extends Button

@export var sfx_event: UiAudioEvent = preload("res://data/tres/audio_events/click.tres")

func _ready() -> void:
    pressed.connect(_play_sfx)

func _play_sfx() -> void:
    if sfx_event != null:
        AudioManager.play_event(sfx_event)
```

### 使用方式

- 場景裡把 `Button` 節點 type 改成 `SfxButton`
- 預設自動播 click；需要不同音效的按鈕在 inspector 改 `sfx_event` export
- 想靜音的按鈕把 `sfx_event` 設為 null
- 移除 ClickBinder autoload 及 `project.godot` 註冊

### 優點

- Godot-native：export var + `_ready()` 連接是標準 pattern
- 可發現性：場景作者在 inspector 裡直接看到 `SfxEvent` 屬性
- 每個按鈕自己管自己，沒有隱式全域掃描
- 動態生成的 `SfxButton` 一樣會播（因為 `_ready()` 照常觸發）

### 成本

- 需要把全專案所有「應該有預設 click 的 Button」從 `Button` 改成 `SfxButton`
- 需要把現有 3 處 `set_meta("sfx_click_ignore", true)` 改成把按鈕的 `sfx_event` 設為 null（或自訂 event）

## Alternative B: Scene-Local Bulk Wiring

每個場景在 `_ready()` 裡自己對「只需預設 click」的按鈕批量連接一個 local callback：

```gdscript
func _ready() -> void:
    for btn: Button in [_hub_btn, _storage_btn, _sell_btn]:
        btn.pressed.connect(_on_default_click)

func _on_default_click() -> void:
    AudioManager.play_event(CLICK)
```

語義按鈕不加入這個陣列，自己播自己的。

### 優點

- 零額外 class，不需要改型別
- 顯式、易讀、落在場景檔案裡

### 缺點

- 每個場景都要手寫這段 boilerplate
- 容易漏接新加的按鈕

## Alternative C: Theme / AudioBusPlugin / SoundGroup

Godot 的 Theme 系統不支援音效屬性。`AudioBusPlugin` / `SoundGroup` 是 Godot 4.x 的音效分組功能，但目前沒有任何已知的 pattern 可以讓它「偵測 button press 並自動播 UI 音效」——這個機制不存在。

## Recommendation

方案 A（Custom `SfxButton`）最接近 Godot 慣例，且與專案現有架構一致（專案已有多個 custom node class，如 `ItemListPanel` 等）。方案 B 太容易出錯，方案 C 不可行。
