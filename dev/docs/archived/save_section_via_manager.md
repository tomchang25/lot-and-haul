# Save Section 改由 Manager 自報（to_dict / from_dict / migrate / validate）

Implementation spec — 見 `dev/standards/implementation_spec_standard.md`。

## Goal

把 `SaveManager` 的 section provider 從「七個 Store」換成「兩個 Manager」（`MetaManager`、`KnowledgeManager`）。Manager 對外實作 `to_dict / from_dict / migrate / validate`，內部 fan-out 到自己持有的 Store；各 Store 補上 `migrate() / validate()` hook。`SaveManager` 維持原本 `_sections` / `register_section(s)` 的機制與形狀，只是註冊對象與 dispatch 方式改成走 Manager。

## Scope

### Included

- `MetaManager`：實作 `to_dict()` / `from_dict()` / `migrate()` / `validate()`，fan-out 到 `_economy / _garage / _storage / _slot / _progress / _customers`；`_ready` 改成 `SaveManager.register_section(self)`。
- `KnowledgeManager`：實作 `to_dict()` / `from_dict()` / `migrate()` / `validate()`，fan-out 到 `_knowledge`；`_ready` 改成 `SaveManager.register_section(self)`。
- 各 Store（`common/gameplay/store/*.gd`，共 7 個）：補 optional `migrate()` / `validate()`。
- `SaveManager`：`_sections` 現在裝 Manager；`save()` 由「`section_id()` 當 key 逐一 assign」改為「`merge(section.to_dict())`」；`load()` 由「`get(section_id())` 取子 dict」改為「把整包 `sections_data` 交給 `section.from_dict()`，Manager 自己挑 key」。

### Excluded（其他不要動）

- 不新增 `StateCoordinator` 或任何新 autoload。
- 不動 `project.godot`、`game_manager.gd`、`registry_coordinator.gd`、`run_manager.gd`。
- 不改 on-disk 存檔結構：維持扁平 `sections` 佈局，Store 的 `section_id()` 仍是各 section 的 key。
- 不搬動 schema 1→2 的跨 section relocation——它留在 `SaveManager.load()` 原地。
- 不動任何 `SaveManager.save()` 呼叫點（Manager 內 ~14 處沿用）。

## 設計約束

**扁平佈局不變。** Manager 的 `to_dict()` 回傳的是「多個 section key 的 dict」（不是包一層 `{"meta": ...}`），`SaveManager` 用 `merge` 併進 `sections_out`。這樣磁碟格式與今天逐一註冊 Store 時完全一致，舊存檔免 migration。

**key 不碰撞，故 `from_dict` 收整包。** `SaveManager.load()` 把整個 `sections_data` 傳給每個 `Manager.from_dict()`，Manager 只讀自己的 key（`data.get("economy", {})` 等）。沿用既有「section key 跨 provider 不碰撞」的前提。

**順序在 Manager 內控制。** `from_dict` 內各 Store 的還原順序由 Manager 決定，Store 彼此不需知道對方。

## 方法契約

### Manager（`MetaManager` / `KnowledgeManager`）

```gdscript
## 併出自己所有 Store 的 section，回傳扁平多 key dict。
func to_dict() -> Dictionary:
    var out: Dictionary = {}
    out.merge(_economy.to_dict())   # 各 Store 既有 to_dict 仍回 { "<section_id>": payload }
    out.merge(_slot.to_dict())
    # ...其餘 Store
    return out

## 把整包 sections dict fan-out 給各 Store，順序在此控制。
func from_dict(data: Dictionary) -> void:
    _economy.from_dict(data.get("economy", {}))
    _slot.from_dict(data.get("slot", {}))
    # ...其餘 Store

## 聚合各 Store 的 migrate（idempotent）。跨 Store 的修正寫在這裡。
func migrate() -> void:
    _economy.migrate()
    # ...其餘 Store

## 聚合各 Store 的 validate，回傳是否全數通過。
func validate() -> bool:
    var ok := true
    ok = _economy.validate() and ok
    # ...其餘 Store
    return ok
```

注意：各 Store 現有的 `to_dict()` 回傳的是 `{ "cash": ... }` 這種「裸 payload」，**沒有**自己的 section key 外層。為了讓 Manager 能 `merge`，二選一（在實作前拍板，預設取 A）：

- **A（預設）**：Manager 自己加 key — `out[_economy.section_id()] = _economy.to_dict()`，`_economy.from_dict(data.get(_economy.section_id(), {}))`。Store 的 `to_dict/from_dict` 完全不動。
- B：把外層 key 下放進 Store 的 `to_dict`（改成回 `{ "economy": {...} }`）。會動到 7 個 Store 的序列化形狀，較大，不建議。

→ 採 A：Store 的 `to_dict/from_dict/section_id` 維持原樣，Manager 用 `section_id()` 當 key 組裝。

### Store（7 個）

```gdscript
## 就地遷移自己 domain 內的欄位／格式。idempotent。預設 no-op。
func migrate() -> void:
    pass

## 檢查自身不變量，回傳是否通過。預設恆真。
func validate() -> bool:
    return true
```

本次無 Store 需要實質 migrate 內容（schema 1→2 是跨 section，留在 SaveManager）；先補空 hook 當未來欄位演進的家。`validate()` 可放各自合理的不變量（例：`EconomyStore.cash >= ?`、`SlotStore` 的 slot 範圍）——範圍由實作者判斷，無則 `return true`。

### SaveManager

```gdscript
func save() -> void:
    var sections_out: Dictionary = {}
    for section: Object in _sections:        # section 現在是 Manager
        sections_out.merge(section.to_dict())
    # 其餘（schema_version 包裝、寫檔）不變

func load() -> void:                          # 內部 _read_save_file
    # schema 1→2 relocation 不動，仍在 dispatch 前對 sections_data 動手
    for section: Object in _sections:
        section.from_dict(sections_data)      # 整包傳入，Manager 自挑 key
```

`register_section` / `register_sections` / `_sections` 機制與簽名**不變**；只是 `MetaManager` / `KnowledgeManager` 改成註冊 `self`，不再註冊 Store。

## migrate / validate 的呼叫者（一個待拍板點）

本 plan 只負責**實作**這些方法。誰來驅動：

- `migrate()`：建議在 `SaveManager.load()` dispatch 後的迴圈順帶 `section.migrate()`（SaveManager 本就擁有 load 生命週期）。若要嚴守「SaveManager 只碰 to_dict/from_dict」，則此呼叫留作後續，本 plan 僅備妥方法。
- `validate()`：`KnowledgeManager` 目前的 `validate()` 由 `RegistryCoordinator` 驅動（檢 perk/attribute registry）。新的 state 聚合 `validate()` 與它語意不同——**拍板點**：是否合併、或讓 state validate 另尋驅動者。預設：本 plan 不改驅動路徑，只實作方法；驅動接線另開。

> 此點需在開工前確認，避免 scope 外溢。

## Files to Change

| File | 變更 | 說明 |
| --- | --- | --- |
| `global/autoloads/managers/meta_manager.gd` | Medium | 新增 4 方法；`_ready` 改 `register_section(self)` |
| `global/autoloads/managers/knowledge_manager.gd` | Small | 新增 4 方法；`_ready` 改 `register_section(self)`；header docstring 更新 |
| `common/gameplay/store/economy_store.gd` | Small | 補 `migrate()` / `validate()` |
| `common/gameplay/store/garage_store.gd` | Small | 同上 |
| `common/gameplay/store/storage_store.gd` | Small | 同上 |
| `common/gameplay/store/slot_store.gd` | Small | 同上 |
| `common/gameplay/store/progress_store.gd` | Small | 同上 |
| `common/gameplay/store/customers_store.gd` | Small | 同上 |
| `common/gameplay/store/knowledge_store.gd` | Small | 同上 |
| `global/autoloads/save_manager.gd` | Small | `save()` 改 `merge`；`load()` 改傳整包；header docstring 更新 |

## Edge Cases

| Case | Expected |
| --- | --- |
| 舊存檔（扁平 sections） | 不受影響——佈局與 key 不變，`merge` / 整包 dispatch 還原結果等價 |
| schema 1 legacy flat save | `SaveManager` 既有 legacy 分支不動，仍整包丟給每個 section（現為 Manager），Manager 自挑 key |
| schema 1→2（economy→knowledge 搬 key） | 留在 `SaveManager.load()`；在 dispatch 給 Manager 前已重整完成 |
| `merge` key 碰撞 | 不會發生——七個 Store 的 `section_id()` 互不重複 |

## Acceptance Criteria

1. `MetaManager` / `KnowledgeManager` 各有 `to_dict / from_dict / migrate / validate`，內部 fan-out 到其 Store。
2. 七個 Store 各有 `migrate()` / `validate()`（可為 no-op / `return true`）。
3. `SaveManager._sections` 註冊的是兩個 Manager；`save()` 用 `merge`，`load()` 傳整包；`register_section(s)` 機制不變。
4. 存檔 round-trip byte 等價：舊存檔載入後再存出，`sections` 內容與原本一致。
5. `其他不要動` 清單中的檔案無 diff。
6. `python dev/tools/lint_standards.py --files <changed>` 通過；Godot reload 無未解析型別。
