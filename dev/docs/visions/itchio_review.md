# Lot & Haul — 三階段上架評估

> **Level 1 (vision).** 全中文（特例）。專案預設語言為英文，但此評估讀者是中文母語的專案作者，為確保溝通精確度與效率，破例使用中文。內容為整個專案在三種不同發佈階段的完成度診斷，供作者判斷各階段的前置準備與資源投入方向。

---

## 三階段定義

| 階段                                | 目標                            | 受眾期待                                 | 鑑別標準                                             |
| ----------------------------------- | ------------------------------- | ---------------------------------------- | ---------------------------------------------------- |
| **Stage 1 — Itch.io 免費 Playtest** | 讓真人玩家認真玩過、給 feedback | 知道是 alpha，能玩、不 crash、看得出潛力 | 能跑完半引導 demo 流程、不噴 error、有 gameplay 可評 |
| **Stage 2 — Itch.io 販售 / Patron** | 有人願意付費                    | 內容物有所值、穩定、有基本打磨           | 玩家覺得花錢不後悔、能玩數小時不出戲                 |
| **Stage 3 — Steam Demo (Pre EA)**   | 累積願望清單、建立聲量          | 高完成度印象、前 30 分鐘驚豔             | 玩家願意把 Demo 推薦給朋友、主動 wishlist            |

---

## Stage 1 — Itch.io 免費 Playtest

核心目標：提供一段半引導的 3-run demo 體驗，讓 playtester 走完核心循環並給予有意義的回饋。

### Demo 流程：半引導 3-Run

基於 `dev/docs/plans/demo_summary.md` 的核心概念，適配當前系統。不修改 production scene，透過 Director System 從外部注入行為。

**Run 1 — 學循環**

- 大車、高 stamina，物品皆高價值低深度
- 第一 lot 由 Uncle 代標（強制教學），後續 lots 玩家自行操作
- 若 cargo 為空則阻擋離開，確保至少帶回一些物品
- Hub 引導：storage → knowledge → customer sell → 過夜
- 目標：玩家完整走過一次 run + hub 循環，帶著明確獲利結束

**Run 2 — 解鎖隱藏層**

- 開場贈送 X-Ray Perk（直接 unlock）
- 場上有 veiled items，X-Ray 可在競標前全部揭示
- 目標：讓玩家體驗資訊不對稱的核心 fantasy

**Run 3 — The Crown（情緒高潮 + reset）**

- X-Ray 揭露一個 crown，真實價值為目前現金數倍
- 起標價低得可疑，若玩家猶豫 Uncle 會代標
- Crown 強制進 cargo
- Hub 觸發 cutscene：黑衣人出現，宣稱 crown 為贓物。Uncle 被帶走，全部資產扣押
- 玩家以一台小車 + 歸零資產在新城市 restart
- 目標：帶著「這遊戲有意思」的印象離開，願意寫 feedback

#### 需要新增的 Demo 系統

| 系統                | 說明                                                                                                                                                            |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Director System** | 新 autoload。管理 demo 狀態，在 run 前注入固定 lot 內容、車輛、perks 到 RunStore。透過 signal hook 在 auction/cargo scene 加入強制行為。不修改 production scene |
| **Dialog System**   | DialogManager overlay autoload。線性對話優先（Uncle 分支第二）。data-driven，shared by demo 與正式版                                                            |
| **Demo Cutscene**   | 獨立 scene。Run 3 結尾的資產 wipe + 車輛 swap + 城市切換。完全隔離於 production                                                                                 |

### 技術阻擋（必須修才能上）

1. **Export Presets 未設定** — 沒有 build 可上傳，這是第零步
2. **`assert()` 在 release build 會變靜默 crash** — inspection/auction 多處 `assert(RunManager.lot != null)` 與類似 guard 在 export 後會被編譯器移除，變成 null pointer crash。必須換成 `if` + `push_error` + `return`
3. **New Game vs Continue 路徑相同** — 無法以NewGame開啟遊戲，除非手動刪除Savefile
4. **音效未接線** — `AudioManager` 完整但沒有任何場景呼叫它。競標無聲、檢查無聲、按鍵無聲，對 gameplay 體驗損害太大。至少 wire 關鍵互動（bid confirm、button click、item reveal）
5. **data/tres 被 gitignore** — 他人 clone 後 `data/tres/` 是空的，所有 registry 載入零資源，遊戲無法啟動。解法：補一鍵 bootstrap script

### 不擋的（Stage 1 可接受）

- ❌ 無自訂字型 → 預設字型夠用
- ❌ 無物品圖示 → 文字顯示即可
- ❌ 5 個分類空的 → demo 只用到有物品的分類
- ❌ 只有 35 件物品 → demo 夠用
- ❌ 無負面/覆蓋線索 → 簡化版機制仍可運作
- ❌ 無 loading screen → 場景小幾乎瞬移
- ❌ 車輛共用 placeholder → 功能完整，看得出來是 placeholder
- ❌ 開始畫面樸素 → 寫上 game title 就夠

### Stage 1 完成度：**55%**

（65% 基礎完成度 × 扣除三個新系統的權重。Director + Dialog + Cutscene 需新建。）

### Target Checklist

- [ ] Export Presets 設定（Windows + Linux）
- [ ] 所有 `assert()` 換成 release-safe error handling
- [ ] New Game 路徑修正（清存檔 or 確認對話框）
- [ ] 關鍵音效 wire（競標確認、物品揭示、按鈕點擊）
- [ ] data/tres 提交 or bootstrap script
- [ ] itch.io page 建立（screenshots + 操作說明）
- [ ] Director System autoload
- [ ] Dialog System overlay
- [ ] Demo Cutscene scene
- [ ] 3-run 內容配置與測試

---

## Stage 2 — Itch.io 販售 / Patron

在 Stage 1 的 demo 基礎上，將遊戲擴充為值得付費的完整產品。

### 額外需求

#### 視覺 Identity

- **自訂字型** — 至少一組正文字型 + 標題字型。最簡單能大幅提升 perceived quality 的投資
- **開始畫面 basic branding** — 加入 game title 美術字 + 簡單背景／動畫
- **物品圖示** — 每個分類至少一個 placeholder icon，不能全文字

#### 內容擴充

- **補滿 12 分類** — 每個分類至少 3-5 件物品
- **增加稀有度變化** — 導入 rarity 0-4，lot 生成時依權重決定物品稀有度，讓「抽到寶物」的 fantasy 真正存在
- **加入負面線索** — 鑑定有風險，authenticate 後價值可能比 appraised 低，強化核心 tension
- **至少 4-6 個地點** — 提供 progression 感
- **至少 10-15+ lots** — 增加 replayability
- **每台車有獨立視覺** — 至少顏色/裝飾 variant，不必全重新繪製

#### 穩定度與 UX

- **小新手引導** — 付費用戶需要能自己搞懂怎麼玩。至少一段「Welcome to Lot & Haul」文字引導核心循環
- **邊界情況處理** — 空 storage、空客戶、連續 pass 所有 lots 等 edge case 要有合理反應
- **Perk effects 實作** — `perk_effects.gd` 目前是 stub，至少 wire 現有 4 個 perks 的實際效果

### Stage 2 完成度：**25%**

與 Stage 1 的差距主要在內容量（補分類、稀有度、負面線索）與視覺（字型、圖示）。這是工作量最大的階段。

---

## Stage 3 — Steam Demo (Pre EA)

在 Stage 1 的 demo content 與 Stage 2 的內容基底之上，加上 Steam 平台要求的品質標準。

### 額外需求

- **音樂** — 至少 title theme + hub ambience
- **場景轉場** — 主要階段切換加上 fade transition（Director 可控制是否跳過）
- **Steam API 整合** — overlay、基本的 achievement 框架
- **完整新手教學** — 不再是文字 overlay，要整合進 gameplay（可利用 Director System 擴充）
- **解析度選項 + 視窗設定** — Steam 使用者的基本期待
- **Crash reporter / error handling** — Steam 版不能靜默失敗
- **Demo 專用內容曲線打磨** — 3-run 流程要在最有張力的 cliffhanger 結束
- **性能 optimization** — Steam 用戶硬體 range 大
- **Loading screen / preloader** — 至少簡單的 loading indicator
- **Mastery Gate** — Location browse 的 mastery rank 檢查，用於鎖定高階拍賣場（若 Stage 2 已實作）

### Stage 3 完成度：**10%**

Steam 是另一個層級的戰場。Steam API、音樂、效能優化、crash reporter 都是從零開始。Director/Dialog 已在 Stage 1 完成，此階段 focus 在 platform polish。

---

## 建議路線圖

```
Stage 1 (Itch.io free playtest)
  │  技術阻擋清除 + 3 個 demo 系統（Director/Dialog/Cutscene）
  │  約 3-4 週
  │  → 收集 playtest feedback
  ▼
Stage 2 (Itch.io paid / Patron)
  │  內容擴充（補分類、稀有度、負面線索）+ 視覺打磨（字型、圖示、車）
  │  約 2-3 個月，與 Stage 1 feedback 疊代並行
  │  → 累積玩家評價 + 社群
  ▼
Stage 3 (Steam Demo)
  │  Steam API + 音樂 + 效能 + crash reporter
  │  約 1 個月
  │  → 導流 wishlist
  ▼
Steam EA Release（未來）
```

注意 Stage 1 → 2 不一定要完全 serial：一旦 Stage 1 的 demo build 出去、feedback 開始回流，內容擴充就可以並行進行。Director/Dialog 系統應設計為正式版可復用，避免 demo-only code 被拋棄。
