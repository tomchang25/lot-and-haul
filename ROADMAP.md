# 核心循環重新設計 — Roadmap

## 起因

兩個待辦項同時指向同一個根本問題：Day Summary 的 Net 數字讓玩家覺得自己永遠在虧錢，而 Weekly Report 難以實作。根源在於買入和賣出之間的時間差——拍賣場大量買入、回家慢慢賣給商人，以「天」為單位的結算永遠呈現扭曲的畫面。拍賣日必然是大赤字，賣貨日小賺，但心理傷害已經造成。不像 Salvage Hunter 那種買一件賣一件即時閉合的模式，現有結構下任何每日結算都在說謊。

Commodity 系統已解決「跑一趟完全沒有正現金回饋」的痛點，但長期 item 變現路徑不夠透明、研究投入的回饋不明確。舊設計把 Inspection Research 與 Storage Research 都接到同一組 `layer_index / inspection_level`，導致短期判斷與長期投資互相取代，怎麼調數值都不自然。

新的核心拆分是：Inspection 只負責短時間取得 clues 並推進抽象 perceived identity；回 Hub 後自動進入 final perceived layer，讓玩家立刻看懂大概有沒有賺；Storage Research 改為 Authenticate，花長時間取得 verified 標記與 item 真實 base price，作為高回報變現準備。

---

## Design Principles

1. **Perceived identity ≠ Verified item value** — `identity_layers` 表示玩家推理出的抽象概念層，例如「古董花瓶」、「量產型瓷器」、「清朝花瓶」。`ItemData.item_name / base_price` 表示真實物件與 verified 後的價值。

2. **Inspection 是快速資訊回報** — 拍賣前花 AP 解 clues。Clues 用於推進 perceived layer，幫玩家決定是否出價、出多少、哪些 item 值得帶回家。

3. **Storage 是慢速高回報** — Storage 不再與 Inspection 搶同一個 layer advance。Storage 的核心回報是 Authenticate：完成後打上 `verified`，顯示 `ItemData.base_price`，並解鎖更好的變現機會。

4. **回 Hub 後揭露 final perceived layer** — 所有帶回家的 item 在進 Storage 前自動進入 final identity layer。玩家能立即知道大概賺賠，但 exact item base price 仍需 verified。

5. **Clues 是 knowledge layer，不是 content layer** — 每個 clue 讓玩家學到一件事。每層 clues 超過半數解鎖後推進 perceived layer。Clues 不直接等於真實 item price。

6. **真實價格只由 verified 揭露** — `ItemData.base_price` 暫時必須高於 final layer value。未 verified 前只顯示 layer value；verified 後才顯示 item base price。

7. **通路分工明確** — Player Shop、Quick Sell、Special Order 各自有生態位。Special Order 沿用現有 slot / pricing 架構，必要時加 verified gate，不重做成另一套經濟系統。

8. **資料語意主要由 YAML 決定** — `identity_layers` 改成 abstract perceived chain 主要是改 `data/yaml/items/*.yaml` 的內容與 generator，不是把 runtime data structure 大幅推倒重做。

---

## 已完成基礎（Phase 0–2）

| Phase | 內容                                                                     | Commit    |
| ----- | ------------------------------------------------------------------------ | --------- |
| 0     | Runtime Veil Cleanup — `inspected` bool、`is_veiled()` 相容層、Peek 移除 | `2d2a8b6` |
| 1     | Commodity 系統 — CommodityEntry、混排 lot_objects、自動變現與顯示        | `3113983` |
| 2     | AP Grid Inspection — 8×8 grid、search countdown、ADVANCE、review summary | `683ab8d` |

---

## Phase 計畫

### Phase 3 — Item Base Price + Abstract Identity Data

**Goal:** 建立 `ItemData` 的真實 item 資料，並把現有 identity layer data 轉成抽象 perceived chain。

**Design Decisions:**

- `ItemData` 新增 `item_name: String`
- `ItemData` 新增 `base_price: int`
- `base_price` 暫時必須高於該 item final identity layer 的 `base_value`
- `identity_layers[].base_value` 保留，作為未 verified 前的 perceived value anchor
- `identity_layers` 的語意改由 YAML data 表達：抽象概念層，而不是真實 item 名稱層
- 現有 `.tres` 仍由 YAML generator 產生，不手動維護生成檔

**Scope:**

- Included: `ItemData` 欄位、YAML schema、generator、validator、現有 item YAML migration
- Excluded: Inspection clue interaction、Storage Authenticate、Shop 整合

**Validation:**

- 每個 item 必須有 `item_name` 與 `base_price`
- 每個 item 的 `base_price > final_layer.base_value`
- 每個 item 的 final identity layer 仍必須是該 chain 最深 perceived layer

**Dependencies:** Phase 0

---

### Phase 4 — Clues + AP Inspection Research

**Goal:** 用 clue-based inspection 取代目前固定 `1 AP = advance_layer()` 與 `inspection_level` 價格收斂邏輯。

**Design Decisions:**

- `IdentityLayer` 新增 clues
- 每個 clue 至少包含 `clue_id`、`text`、`ap_cost`
- Clue 可以有 auto-unlock 條件，例如 mastery、skill、perk、category rank
- 條件達成時可自動 unlock clue
- Inspection Research 花 AP 無視條件 unlock clue
- 手動 AP research 從目前 layer 的 locked clues 中依 `ap_cost` 由低到高解鎖
- 目前 layer 的 clues 解鎖數超過半數後，才 advance 到下一 perceived layer
- Inspection UI 不再把動作命名成 `ADVANCE`，避免回到「按一次就 layer+1」的舊模型

**Scope:**

- Included: clue data、`ItemEntry.revealed_clue_ids`、clue unlock threshold、Inspection AP cost flow、review summary 顯示 clue 回饋
- Excluded: Storage Authenticate、Player Shop、Special Order pricing migration

**Compatibility Notes:**

- 舊 `layer_index` 可先保留作為 perceived layer index 的 storage 欄位，再逐步 rename
- 舊 `inspection_level / scrutiny / price_convergence_ratio / center_offset` 可先標 deprecated，等 clue flow 穩定後 cleanup

**Dependencies:** Phase 3

---

### Phase 5 — Hub Final Layer Resolution + Save Migration

**Goal:** 所有帶回家的 item 在回 Hub / 進 Storage 前自動進入 final perceived layer，讓玩家立即理解大概價值，同時保留 verified 作為 exact price gate。

**Design Decisions:**

- Run resolve 時，所有進 Storage 的 item 自動設到 final identity layer
- `SaveManager.load()` 對既有 storage item 做 migration：如果不是 final layer，自動 advance 到 final layer
- Migration 不代表 verified，只代表玩家已經能辨認 final perceived identity
- 如果 Storage Authenticate 遇到非 final layer，先 `push_warning` 並拒絕或跳過該 action，不 crash

**Scope:**

- Included: run resolve auto-final、save/load migration、warning path、storage display 調整
- Excluded: Authenticate action 本身、Shop/Special Order 使用 verified 的邏輯

**Dependencies:** Phase 3

---

### Phase 6 — Storage Authenticate

**Goal:** 將 Storage 的長時間研究回報改為 Authenticate，與 Inspection 的 clue/layer 推進分工。

**Design Decisions:**

- 移除或停用 Storage `Unlock` 作為主要玩家入口
- 新增 `Authenticate` research action
- Authenticate 只允許 final layer item
- Authenticate 根據 rarity 花固定時間
- 完成後 `ItemEntry.verified = true`
- Verified 後顯示 `ItemData.item_name` 與 `ItemData.base_price`
- Verified item 可提供 Player Shop interest bonus 或縮短售出天數

**Scope:**

- Included: `ItemEntry.verified`、save/load、ResearchSlot action、MetaManager day tick、Storage UI button/status、detail panel 價格顯示
- Excluded: 贗品概念、專家鑑定分支、完整 Shop sale simulation

**Dependencies:** Phase 5

---

### Phase 7 — Special Order Verified Integration

**Goal:** 沿用現有 Special Order slot / pricing 架構，讓高階 order 可以要求 verified，避免從 order payout 反推 true price。

**Current Codebase Baseline:**

- `OrderSlot` 已有 category、rarity floor、condition floor
- `SpecialOrder` 已有 `buff` 與 `uses_condition / uses_knowledge / uses_market` pricing flags
- `allow_partial_delivery` 已可支援 bulk-style order

**Design Decisions:**

- 不重做 Special Order 架構
- Bulk / low-info order 繼續走現有 category slot + simple payout 路線
- Premium order 增加 verified gate
- Verified premium payout 使用 `ItemData.base_price * buff`
- 需要 exact base price 的 order 必須要求 verified
- 停用或遷移會從 `active_layer()` / perceived value 洩漏 true-ish price 的 pricing path

**Scope:**

- Included: verified gate、premium payout 使用 base_price、existing order data migration、fulfillment UI labels
- Excluded: 新 order 系統、複雜 pricing mode rewrite、贗品或鑑定失敗

**Dependencies:** Phase 6

---

### Phase 8 — Value Policy Cleanup

**Goal:** 在 codebase 中明確定義 verified / unverified item 的取值邏輯，避免價格規則散落在 scene 中。

**Design Decisions:**

- 未 verified display value 使用 final perceived layer value
- Verified display value 使用 `ItemData.base_price`
- Quick Sell 可按目前可見價值打折
- Player Shop 可用 verified 狀態影響 interest / sale days
- Special Order premium path 使用 verified base price

**Scope:**

- Included: 集中 value helper、現有 caller migration、單元測試或最小驗證場景
- Excluded: UI 全面重設、Shop 新功能完整實作

**Dependencies:** Phase 6、Phase 7

---

### Phase 9 — Player Shop

**Goal:** 以 Player Shop 取代 pawn shop negotiation 作為主要賣出管道，提供透明的定價與市場回饋。

**Design Decisions:**

- 有限 listing slot（初始 3 個，可擴充）
- 玩家自訂價格，未 verified 用 perceived value 作參考，verified 用 item base price 作參考
- Sale roll 以 list price、visible value、verified bonus、market demand 決定
- UI 不顯示精確售出機率，改為粗略興趣等級
- Quick Sell 按鈕：一口價 instant 出清，不需 negotiation
- Verified item 有額外 shop interest 或縮短售出天數

**Scope:**

- Included: 上架 UI、定價、interest label、day-tick sale resolution、Quick Sell、listing slot 管理
- Excluded: Merchant negotiation 刪除、market demand 深度重做

**Dependencies:** Phase 8

---

### Phase 10 — Garage Auction + Merchant Deprecation

**Goal:** 新增 Garage Auction 進貨渠道，將 negotiation engine 從賣方轉移到買方 context；逐步 deprecate pawn shop negotiation。

**Design Decisions:**

- Garage Auction：玩家多選 items → NPC 報 bundle price → negotiation（player = buyer）
- 現有 negotiation engine 保留但參數 rename：`seller_patience`、`floor_price`、`concession_rate`
- 玩家可以從 Storage 選取多個 items 發起 garage auction（不限於一 lot）
- Pawn shop negotiation dialog 標記 deprecated，UI 入口隱藏；Quick Sell 取代其功能
- Merchant hub 保留作為 Special Order 入口

**Scope:**

- Included: Garage Auction 場景、item multi-select UI、negotiation adapter、merchant sell flow deprecation
- Excluded: Quick Sell 功能重做

**Dependencies:** Phase 9

---

### Phase 11 — Day Summary 簡化

**Goal:** 解決 Net 數字造成的心理負面感受。

**Design Decisions:**

- Net 可以保留或拿掉，取決於 Player Shop / Quick Sell 上線後的 cash flow 感受
- Commodity Sales + verified item sale pipeline 應該讓跑完一趟的經濟回饋更清楚
- 非拍賣日可考慮跳過 summary 直接回 hub

**Scope:**

- Included: Day Summary UI 調整
- Excluded: 週系統、Weekly Report、固定扣額 Game Over

**Dependencies:** Phase 9

---

## 設計前提

1. **Identity layers 是 perceived chain** — 主要由 YAML data 呈現抽象概念，不再把 final layer 當成 item 真實價格來源。
2. **ItemData 承載真實 item value** — `item_name` 與 `base_price` 是 verified 後才顯示的資料。
3. **base_price > final layer value** — 暫時強制真實 item base price 高於 final perceived layer，避免 verified 沒有經濟回報。
4. **Inspection 不再與 Storage 共用核心回報** — Inspection 解 clues；Storage authenticate。
5. **回 Hub auto-final 不等於 verified** — 玩家知道大概物件與 perceived value，但不知道 exact base price。
6. **Special Order 沿用現有架構** — 只補 verified gate 與 base_price payout，不重寫 slot/order system。
7. **Special Order 結算前不繞過 verified 揭露 true price** — 需要 exact base price 的 order 必須要求 verified。
8. **週系統、固定扣額 Game Over 不實作** — Commodity auto-sale 與後續 sale pipeline 已足夠解決利潤斷裂問題。

---

## Phase 依賴圖

```
Phase 0（已完成）
  └─ Phase 3（ItemData base price + abstract identity data）
       ├─ Phase 4（Clue Inspection）
       └─ Phase 5（Hub final resolution + migration）
            └─ Phase 6（Storage Authenticate）
                 ├─ Phase 7（Special Order verified integration）
                 └─ Phase 8（Value Policy Cleanup）
                      └─ Phase 9（Player Shop）
                           ├─ Phase 10（Garage Auction）
                           └─ Phase 11（Day Summary）
```

Phase 4 與 Phase 5 可在 Phase 3 完成後平行進行。Phase 7 與 Phase 8 可在 Phase 6 完成後平行進行。
