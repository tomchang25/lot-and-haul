# Lot & Haul — Docs Index

文件總覽與快速跳轉。分類沿用 [README](README.md) 的三層結構（L1 vision / L2 systems・plans / L3 程式碼註解）。歸檔文件不列於此。

> 用瀏覽器的 Markdown Viewer 開啟時，點下列連結即可跳轉並繼續渲染（需開啟擴充套件的「允許存取檔案網址 / Allow access to file URLs」）。

---

## 🧭 從這裡開始

- [README — 文件系統規則](README.md) — 三層 doc layering、TODO/plans/CHANGELOG 分工、成熟度量表、各資料夾規則。
- [CLAUDE.md — 專案總覽](../../CLAUDE.md) — 核心循環、關鍵概念、自動載入順序、資料管線、慣例速查。

## 📌 追蹤（repo 根目錄）

- [TODO.md](../../TODO.md) — 唯一的前瞻面：Active 進行中流程、Plan/Chore/Bug 一行待辦、Draft 概念區。
- [CHANGELOG.md](../../CHANGELOG.md) — 只增不刪的出貨紀錄，唯一的「已完成」歷史。

---

## L1 — Vision（願景，幾乎不變）

- [核心概念 core_concept](visions/core_concept.md) — 一次讀懂整個遊戲的點子，不含機制細節。
- [資料架構 data_architecture](visions/data_architecture.md) — 設計資源 vs 執行期型別的兩層原則、擁有權鏈、為何要分離。
- [三階段上架評估 itchio_review](visions/itchio_review.md) — ⚠️ 全中文（特例）。Stage 1 Playtest / Stage 2 販售 / Stage 3 Steam Demo 各自的完成度與阻擋條件，含半引導 3-run demo 規劃。

## L2 — Systems（系統設計，present-tense 常青）

### 跨階段 / 核心循環

- [物品系統 item_system](systems/item_system.md) — 物品從設計到執行期檢查、研究、販售的生命週期與跨切面不變式。
- [拍賣與跑單 lot_auction_run](systems/lot_auction_run.md) — 選地點→逛 lot→AP 格檢查→清單→拍賣→揭示/落敗→裝貨→跑單回顧。
- [顧客販售 customer_sell](systems/customer_sell.md) — 唯一的販售路徑：夜間顧客帶需求標籤與車格，保守 vs 激進策略。
- [日程與行動點 day_slot_economy](systems/day_slot_economy.md) — 一天三時段的分配、儲藏與檢查的 AP 池、夜間顧客數量的縮放。
- [物品顯示 item_display](systems/item_display.md) — ItemRow / ItemCard / ItemListPanel 跨場景渲染元件。
- [自動載入 autoloads](systems/autoloads.md) — 跨切面的開機、持久化、Hub 導覽基礎設施。

### Meta（Hub 階段子系統）

- [Hub 與家 hub_home](systems/meta/hub_home.md) — Hub 導覽、時段托盤、儲藏，以及販售/車輛/知識的入口。
- [知識 knowledge](systems/meta/knowledge.md) — 玩家成長：類別精通、五項屬性、Perks。
- [車輛 vehicle](systems/meta/vehicle.md) — 多種車輛設定（耐力、貨格、油耗、額外槽位），於 Hub 購買選用。

## L2 — Plans（標準/工作文件，前瞻可變）

- [Demo 摘要 demo_summary](plans/demo_summary.md) — 6 天目標版本。⚠️ 標記為 stale，留作設計參考。
- [車庫拍賣 garage_sale_auction](plans/garage_sale_auction.md) — 未排程；同時是商人議價機制的備份。
- [車輛修復 vehicle_restoration](plans/vehicle_restoration.md) — 收藏型子系統：拍賣中收集車輛零件、組裝、販售成品車。

---

## 📐 Standards（編碼慣例，`dev/standards/`）

- [專案結構 project_structure](../standards/project_structure.md)
- [命名慣例 naming_conventions](../standards/naming_conventions.md)
- [Runtime type archetypes](../standards/runtime_type_archetypes.md)
- [Registry 標準 registries](../standards/registries.md)
- [Scene node source 標準 scene_node_source_standard](../standards/scene_node_source_standard.md)
- [GDScript 結構 gdscript_structure_standard](../standards/gdscript_structure_standard.md)
- [Error guard 標準 error_guard_standard](../standards/error_guard_standard.md)
- [標準強制執行 standards_enforcement](../standards/standards_enforcement.md)
- [Debug 標準 debug_standard](../standards/debug_standard.md)
- [Theme 標準 theme_standard](../standards/theme_standard.md)
- [Test data 標準 test_data](../standards/test_data.md)

## 🛠 Skills（AI 編碼參考，`dev/skills/`）

- [Conventional Commits](../skills/conventional_commits.md)
- [語意化版本 semantic_versioning](../skills/semantic_versioning.md)
- [GDScript 抽象類別 gdscript_abstract](../skills/gdscript_abstract.md)
- [Godot 4 Theme Override](../skills/godot4_theme_override.md)
- [Godot 4 TSCN Node Properties](../skills/godot4_tscn_node_properties.md)
