# CLAUDE.md — 本專案給 AI 助手的操作指南

**這個資料夾就是 RIME 輸入法的使用者資料夾本身**（Windows 小狼毫 `C:\RIME`／macOS 鼠鬚管 `~/Library/Rime`），同時是 git repo。修改這裡的檔案 = 直接修改使用者每天在用的輸入法。

主方案：**注音Na+**（`bopomo_onionplus`，基於 [Onion Rime Files](https://github.com/oniondelta/Onion_Rime_Files) 二次開發）。

---

## 🚦 動手前必讀的五條規則

1. **改完 yaml 要「部署」，改完 lua 要「重啟 WeaselServer」**
   lua 只在 WeaselServer 程序啟動時載入一次，**部署不會重讀 lua**。只部署不重啟 = 使用者看不到你的 lua 改動（這個坑踩過，別再踩）。

2. **驗證一律在沙盒，不要用「看起來對」當結論**
   `pwsh tools\rime-test.ps1 -Sync -Mode basic` → 23 條黃金樣本必須全 PASS 才算沒退步。沙盒是 `%TEMP%\rime_sandbox`，不碰使用者真實詞庫。

3. **絕不提交 `*.userdb/`、`sync/`、`build/`、`installation.yaml`、`user.yaml`**
   已在 `.gitignore`。使用者明確要求「打字紀錄不同步」，只同步設定。

4. **改上游方案檔請用 `*.custom.yaml` patch，不要直接改原檔**
   `bopomo_onionplus.schema.yaml` 等是上游檔案，直接改會在上游更新時衝突。

5. **改 lua 只做最小改動、保留註解掉的歷史程式碼**
   這套 lua 有大量看似冗餘但有用的分支；重構過三輪，每輪都以逐條回歸擔保行為不變。

---

## 🗺️ 我要改 X，該動哪個檔？

| 需求 | 檔案 |
|---|---|
| 配色、字型、視窗排版（Windows） | `weasel.custom.yaml` |
| 配色、字型（macOS） | `squirrel.custom.yaml`（**格式與 Weasel 不同，勿互抄**） |
| 全域快捷鍵、方案清單 | `default.custom.yaml` |
| 主方案行為（選字鍵、開關、filter/translator 掛載） | `bopomo_onionplus.custom.yaml` |
| ⇧1~6 選字的按鍵與標籤 | 鍵：`p_select_keys/keys` ＋ `lua/processor_p_select_keys.lua`；標籤：`menu/alternative_select_labels`（**別設** `alternative_select_keys`，macOS 標籤會壞） |
| 方案顯示名稱 | 各 `*.custom.yaml` 的 `"schema/name"` |
| 自訂詞（打 `email` 出信箱那種） | `bopomo_onionplus_phrase.txt`（改完要**部署**） |
| `'/` 開頭的多功能（日期／計算機／Unicode…） | `lua/mf_components/` → 見 [架構文件](docs/ARCHITECTURE.md) |
| `'/ts`、`'/uuid`、`'/pw`、`'/rgb`、`'/cs` | `lua/translator_devkit.lua` |
| 日文候選釋義（中／英／日） | `lua/filter_gloss.lua` ＋ `jpnin1_gloss*.dict.yaml` |
| 使用者速查表 | `cheatsheet.html`（`'/jh`＋空格開啟） |
| `'/j` 指令清單、`'/jgit` 更新指令 | `lua/p_components/p_run_pattern.lua`（清單算繪在 `p_run_menu.lua`，動作攔截在 `processor_p_run_files.lua`） |
| `'/` 分層選單內容（含 `'/dev`、`'/code` 子選單） | `lua/mf_components/mf_menu_data.lua`（新增子選單記得在 `mf_open_menu.lua` `register_exact`） |
| `'/jgit` 實際跑的內容 | `scripts/rime-update.command`（Mac）／`scripts/rime-update.ps1`（Win） |

---

## ⌨️ 常用指令

```powershell
# 部署（改 yaml 後）
& "C:\Program Files\Rime\weasel-0.17.4\WeaselDeployer.exe" /deploy

# 重啟服務（改 lua 後，務必！）
Stop-Process -Name WeaselServer -Force; Start-Process 'C:\Program Files\Rime\weasel-0.17.4\WeaselServer.exe'

# 回歸測試（改任何行為後）
pwsh tools\rime-test.ps1 -Sync -Mode basic     # 23 條黃金樣本
pwsh tools\rime-test.ps1 -Mode gloss           # 三語釋義
pwsh tools\rime-test.ps1 -Mode cands  -InputSeq "6sakura"    # 看全部候選＋註解
pwsh tools\rime-test.ps1 -Mode commit -InputSeq "'/uuid "    # 看上屏結果

# 雙機同步（設定走 GitHub，打字紀錄不同步）
pwsh scripts\rime-sync.ps1
```

macOS（鼠鬚管）對應指令：

```bash
# 部署（改 yaml 後）；鼠鬚管沒有獨立 Deployer，reload 會一併重載 lua
"/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" --reload

# 雙機同步
bash ~/Library/Rime/scripts/rime-sync.sh

# 部署日誌（部署失敗時看這裡，會指出是哪個 yaml 出錯）
ls -t /tmp/rime.squirrel.* | head; tail -50 "$(ls -t /tmp/rime.squirrel.ERROR* | head -1)"
```

⚠ `tools/rime-test.ps1` 的沙盒回歸測試目前**只有 Windows 版**。在 Mac 上改了行為，
要嘛推到 Windows 那台跑測試，要嘛在 Mac 上實機驗證後才算數——不要用「應該可以」結案。

---

## 📚 延伸文件（需要時再讀，別預先全載）

- [docs/KEYMAP.md](docs/KEYMAP.md) — **鍵位與代碼總表（自動產生）**。「這個鍵／這個 `'/` 代碼現在是誰在用？」先查這裡，別再從頭調查。
  過期就重跑 `pwsh tools/keymap-dump.ps1`（讀 `build/`，所以要先部署）。
- [docs/GOTCHAS.md](docs/GOTCHAS.md) — **踩過的坑與反直覺事實**。遇到「明明改了卻沒效果」「按鍵沒反應」先查這裡，能省下大量重複調查。
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — lua 模組圖、資料流、如何新增一個代碼／日期格式。
- [docs/HISTORY.md](docs/HISTORY.md) — 已完成的重大變更與**已知未修的原版瑕疵**（避免把「已知現象」當成新 bug 重查）。
- [lua/mf_components/README.md](lua/mf_components/README.md) — 多功能家族的資料驅動架構細節。

## 🎯 使用者偏好

- 溝通用**繁體中文**。
- 重視**先驗證再上線**：使用者說過「請驗證後再做」。做完要能拿出實測輸出，不要只說「應該可以」。
- 不喜歡「洋蔥」字眼出現在使用者可見處（上游品牌），但 README 保留出處連結。
