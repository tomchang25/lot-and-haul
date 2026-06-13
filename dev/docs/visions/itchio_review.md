# Lot & Haul — 三階段上架評估

> **Level 1 (vision).** 全中文（特例）。專案預設語言為英文，但此評估讀者是中文母語的專案作者，為確保溝通精確度與效率，破例使用中文。內容為整個專案在三種不同發佈階段的完成度診斷，供作者判斷各階段的前置準備與資源投入方向。
>
> **Last reviewed: 2026-06-12** — updated for Director + tutorial hint panel ship (commit `8601815`, 15 files, +721/−13 lines: Director autoload with code-built dim-overlay, four-rect hole cutout, hint/popup step display; hub + storage tutorial scripts with ProgressStore v2 persistence), CI headless run-loop suite (commit `1a35ced`, GUT plugin + CIPilot autoload + GitHub Actions workflow + 277-line unit test), packing-grid colour helper centralization (commit `26e0b37`), and 6 additional SFX events (commit `6c4851d`: rotate, grid lift/put-down, setting toggle, storage repair/restore/research).

---

## 三階段定義

| 階段                                | 目標                            | 受眾期待                                 | 鑑別標準                                             |
| ----------------------------------- | ------------------------------- | ---------------------------------------- | ---------------------------------------------------- |
| **Stage 1 — Itch.io 免費 Playtest** | 讓真人玩家認真玩過、給 feedback | 知道是 alpha，能玩、不 crash、看得出潛力 | 能跑完簡單教學 + 核心循環、不噴 error、有 gameplay 可評 |
| **Stage 2 — Itch.io 販售 / Patron** | 有人願意付費                    | 內容物有所值、穩定、有基本打磨           | 玩家覺得花錢不後悔、能玩數小時不出戲                 |
| **Stage 3 — Steam Demo (Pre EA)**   | 累積願望清單、建立聲量          | 高完成度印象、前 30 分鐘驚豔             | 玩家願意把 Demo 推薦給朋友、主動 wishlist            |

---

## Stage 1 — Itch.io 免費 Playtest

核心目標：提供可玩的核心循環 + 一段簡單版教學（無故事流程），讓 playtester 自己走完 run + hub 循環並給予有意義的回饋。

### 教學流程：簡單版（無故事）

教學從故事 demo 中拆出。原 3-run 半引導故事 demo（Uncle 代標、X-Ray、Crown cutscene）整段推遲到 Stage 3 —— 情緒鉤子的回報場景是 Steam demo 的前 30 分鐘，不是 alpha playtest。Stage 1 只做教學，等於把 Stage 2 的「小新手引導」提前。不修改 production scene。

- 第一 run 由 Director 骨架注入固定友善配置：大車、高 stamina，物品皆高價值低深度
- 教學提示面板循序引導：inspect → bid → cargo，若 cargo 為空則阻擋離開
- Hub 引導：storage → knowledge → customer sell → 過夜
- 之後玩家自由遊玩，無多 run 腳本
- 目標：玩家完整走過一次 run + hub 循環，帶著明確獲利結束，之後能自己玩下去

接受的 trade-off：沒有 Run 2 的 X-Ray 段落，playtester 不會被餵到資訊不對稱的核心 fantasy，只能靠正常流程的 hidden clue + authenticate 自己體驗。以 itch page 的 feedback 問題設計補償（例如直接問「你有沒有發現鑑定後價值會變」）。

#### 需要新增的系統

| 系統                | 狀態     | 說明                                                                                                                                                                                                       |
| ------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Director 骨架**   | ⬜ 部分 | Director autoload 已實作（教學引擎 + overlay 系統），但 run 前注入（固定 lot/車輛/stamina）與 cargo 阻擋 hook 尚未實作 —— 移至 Stage 1 殘留項目。完整多 run 狀態機/強制代標/perk 贈送留在 Stage 3 故事 demo |
| **教學提示面板**    | ✅ 完成 | Director autoload 已包含：hint（四邊形挖洞 dim + 錨點旁面板）與 popup（全屏 dim + 居中面板）兩種 step 類型，NEXT 與 SCENE_ENTERED 兩種推進模式。hub（3 steps）與 storage（9 steps）教學腳本已實作。正式版可直接沿用。完整 DialogManager 等 Stage 3 故事 demo 需要時再長出來 |

（原規劃的 Dialog System 與 Demo Cutscene 移至 Stage 3 故事 demo。）

### 技術阻擋（必須修才能上）

1. **Export Presets 未設定** — 沒有 build 可上傳，這是第零步
2. ~~**`assert()` 在 release build 會變靜默 crash**~~ — ✅ 已解決（commit `03bf457`）。引入三類錯誤防護系統（runtime guard / programmer error / precondition），所有 18 個 `assert()` 全數移除，改為 `if` + `push_error` + 依照類別使用 `ToastManager.show_error()` 或 `show_dev_error()`。涵蓋 11 個遊戲檔案與多個 autoload。
3. ~~**New Game vs Continue 路徑相同**~~ — ✅ 已解決。三槽存檔系統 (slot 0–2)，`NewGameButton` 呼叫 `SaveManager.init_slot()` 清空並重置，`LoadGameButton` 呼叫 `switch_to_slot()` 載入。Boot path 透過 `last_active` pointer 決定。合入 PR #115
4. ~~**音效未接線**~~ — ✅ 已解決（PR #116）。建立確定性合成管線（YAML → WAV + UiAudioEvent.tres）、17+ 種遊戲動作音效事件、SfxButton 元件取代 ClickBinder、所有場景關鍵互動已接線：競標確認、按鈕點擊、物品揭示、格子上架、庫存操作、設定切換等。76 檔案變更，+2400/−26 行。
5. ~~**data/tres 被 gitignore**~~ — ✅ 已解決。新增 `bootstrap.sh` 一鍵腳本，clone 後執行即可透過 YAML→TRES 管線生成全部 250 個資源並渲染 12 個音效事件，無需手動執行各管線。`data/tres/` 維持 gitignored。

### 不擋的（Stage 1 可接受）

- ❌ 無自訂字型 → 預設字型夠用
- ❌ 無物品圖示 → 文字顯示即可
- ❌ ~~分類空的~~ → ✅ 已補滿 12 分類（4 super-categories），每分類有對應的 anchors 與 clues
- ❌ ~~只有 35 件物品~~ → ✅ 已重寫為 runtime pool generation 模型（`ItemGenerator`），從 30 anchors + 184 clues 組合生成，不再依賴 authored items
- ❌ 無負面/覆蓋線索 → 簡化版機制仍可運作（hidden clues schema 已存在，可含 override/negative effects）
- ❌ 無 loading screen → 場景小幾乎瞬移
- ❌ 車輛共用 placeholder → 功能完整，看得出來是 placeholder
- ❌ ~~開始畫面樸素~~ → ✅ 已有 game title + 三槽存檔選擇 overlay
- ❌ ~~無自動化測試~~ → ✅ GUT plugin + CI pipeline（GitHub Actions）、RunManager 單元測試（277 lines）、CIPilot headless 煙霧測試已就位

### Stage 1 完成度：**82%**

（前一版 75%。教學提示面板 overlay + hub/storage step 兩個 checklist 項目完成 → +5%。包裝格 grid 色彩集中化、追加 6 組音效事件、CI 測試管線就緒 → +2%。主要殘留：Export Presets 未設定（第零步阻塞）、Director 注入骨架（固定第一 run 配置 + 空 cargo 阻擋）未實作、itch.io page 未建。）

### Target Checklist

- [ ] Export Presets 設定（Windows + Linux）
- [x] 所有 `assert()` 換成 release-safe error handling — commit `03bf457`
- [x] ~~New Game 路徑修正~~ — ✅ Done (save slot refactor, PR #115)
- [x] 關鍵音效 wire（競標確認、物品揭示、按鈕點擊）— PR #116
- [x] data/tres 提交 or bootstrap script — `bootstrap.sh`
- [ ] itch.io page 建立（screenshots + 操作說明）
- [~] Director 注入骨架（固定第一 run 配置 + 空 cargo 阻擋） — 框架（autoload + overlay）已實作，注入與 cargo hook 殘留
- [x] 教學提示面板 overlay — commit `8601815`（Director dim-overlay + hint/popup 系統）
- [x] 教學 step 內容配置與測試 — hub 3 steps + storage 9 steps with ProgressStore v2
- [x] 自動化測試基礎設施 — GUT + CIPilot + GitHub Actions CI（commit `1a35ced`）

---

## Stage 2 — Itch.io 販售 / Patron

在 Stage 1 的 demo 基礎上，將遊戲擴充為值得付費的完整產品。

### 額外需求

#### 視覺 Identity

- **自訂字型** — 至少一組正文字型 + 標題字型。最簡單能大幅提升 perceived quality 的投資
- **開始畫面 basic branding** — 加入 game title 美術字 + 簡單背景／動畫
- **物品圖示** — 每個分類至少一個 placeholder icon，不能全文字

#### 內容擴充

- ~~**補滿 12 分類**~~ — ✅ 已完成（4 super-categories, 12 categories）。每個分類已有 anchors + clues，透過 runtime pool generation 自動產生物品，不再需要每分類手寫 3-5 件
- **增加稀有度變化** — 導入 rarity 0-4，`ItemGenerator.draw()` 已實作 rarity 維度（0=common 到 4=legendary），lot 生成時依分類權重決定
- **加入負面線索** — hidden clues schema 已支援 `override` / `add` / `mul` 的負值效果，但全量 hidden clue content 還未完成
- **至少 4-6 個地點** — 當前僅 2 個 location resources。需要擴充
- **至少 10-15+ lots** — 當前僅 6 個 lot resources。需要擴充
- **每台車有獨立視覺** — 4 台車的 data resources 已到位，但視覺仍是共用 placeholder

#### 穩定度與 UX

- **小新手引導** — 付費用戶需要能自己搞懂怎麼玩。至少一段「Welcome to Lot & Haul」文字引導核心循環
- **邊界情況處理** — 空 storage、空客戶、連續 pass 所有 lots 等 edge case 要有合理反應
- **Perk effects 實作** — `perk_effects.gd` 目前是 stub，至少 wire 現有 4 個 perks 的實際效果

### Stage 2 完成度：**30%**

與 Stage 1 的差距主要在：地點/lots 擴充（從 2→6 地點、6→15 lots）、hidden clue content 補完、perk effects 實作、與視覺打磨（字型、圖示、車輛獨特視覺）。分類與物品生成底層已就緒，不必從零開始。

---

## Stage 3 — Steam Demo (Pre EA)

在 Stage 1 的 demo content 與 Stage 2 的內容基底之上，加上 Steam 平台要求的品質標準。

### 額外需求

- **音樂** — 至少 title theme + hub ambience
- **場景轉場** — 主要階段切換加上 fade transition（Director 可控制是否跳過）
- **Steam API 整合** — overlay、基本的 achievement 框架
- **3-run 故事 demo** — Stage 1 拆出去的完整半引導流程在此回歸：Run 1 Uncle 代標教學、Run 2 X-Ray 揭示資訊不對稱、Run 3 Crown cutscene + 資產 reset。需要 Director 完整 hook（多 run 狀態機、強制代標、perk 贈送）、Dialog System（DialogManager overlay，線性優先、Uncle 分支第二）、Demo Cutscene scene（資產 wipe + 車輛 swap + 城市切換，完全隔離於 production）
- **完整新手教學** — 從 Stage 1 的提示面板擴充，整合進 gameplay（可利用 Director System 擴充）
- **解析度選項 + 視窗設定** — Steam 使用者的基本期待
- **Crash reporter / error handling** — Steam 版不能靜默失敗
- **Demo 專用內容曲線打磨** — 3-run 故事流程要在最有張力的 cliffhanger 結束
- **性能 optimization** — Steam 用戶硬體 range 大
- **Loading screen / preloader** — 至少簡單的 loading indicator
- **Mastery Gate** — Location browse 的 mastery rank 檢查，用於鎖定高階拍賣場（若 Stage 2 已實作）

### Stage 3 完成度：**10%**

Steam 是另一個層級的戰場。Steam API、音樂、效能優化、crash reporter 都是從零開始。Stage 1 交付了 Director 基礎教學引擎（autoload + overlay + hub/storage tutorial），但 Dialog System、Demo Cutscene、完整 3-run 故事 demo（含 Director 完整 hook 多 run 狀態機）都落在此階段，加上 platform polish。

---

## 建議路線圖

```
Stage 1 (Itch.io free playtest)
  │  技術阻擋清除 + Director 骨架 + 簡單教學（無故事）
  │  約 2-3 週
  │  → 收集 playtest feedback
  ▼
Stage 2 (Itch.io paid / Patron)
  │  內容擴充（補分類、稀有度、負面線索）+ 視覺打磨（字型、圖示、車）
  │  約 2-3 個月，與 Stage 1 feedback 疊代並行
  │  → 累積玩家評價 + 社群
  ▼
Stage 3 (Steam Demo)
  │  Steam API + 音樂 + 效能 + crash reporter + 3-run 故事 demo（Director 完整 hook / Dialog / Cutscene）
  │  約 1.5-2 個月
  │  → 導流 wishlist
  ▼
Steam EA Release（未來）
```

注意 Stage 1 → 2 不一定要完全 serial：一旦 Stage 1 的 build 出去、feedback 開始回流，內容擴充就可以並行進行。Director 骨架（教學引擎 + overlay）與教學提示面板已設計為正式版可復用（Director 本身即 production autoload，hub/storage tutorial 直接整合於場景），避免 demo-only code 被拋棄；完整 Dialog System 等 Stage 3 故事 demo 需要時再從提示面板長出來。

Stage 1 殘留項目目前聚集在：Export Presets（第零步 build 阻擋）、Director 注入骨架（固定第一 run RunStore 注入 + cargo 阻擋 hook）、以及 run-phase tutorial steps（inspect → bid → cargo 引導）。若注入骨架被視為可選（教學面板仍能在沒有固定配置的情況下引導玩家），則唯一真正的硬阻擋僅剩 Export Presets —— 設定完成即可出 build。
