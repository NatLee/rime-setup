# CLAUDE.md — 本專案給 AI 助手的操作指南

**這個 repo 是「設定的來源」，不是 RIME 使用者資料夾本身。** 兩者是分開的兩個地方：

| | 位置 | 內容 |
|---|---|---|
| **repo**（你現在在這裡） | 一般使用者：`~/.na-plus`；維護者：任意 clone | `rime/` 底下按功能分類的來源檔＋腳本＋文件 |
| **RIME 使用者資料夾** | Windows 預設 `%APPDATA%\Rime`（維護者的機器設在 `C:\RIME`）／macOS `~/Library/Rime` | 輸入法實際讀的檔案（攤平的）＋使用者的個人資料 |

RIME 只認使用者資料夾**根目錄**的方案／設定檔，所以中間有一步「攤平套用」：
`scripts/rime-apply.ps1`／`.sh` 把 `rime/<分類>/*` 複製到使用者資料夾根目錄（`rime/lua`、`rime/opencc` 保留資料夾）。
**改了 repo 的檔案，輸入法不會自己變** —— 要套用（見下方常用指令）。

**這是公開 repo，別人會用一行指令安裝它**（`install.ps1`／`install.sh`，見 README）。所以：
路徑不可寫死（用腳本所在位置或 `rime_api.get_user_data_dir()`）、Windows 腳本要能在
PowerShell 5.1 跑、個人資料不可進版控。

主方案：**注音Na+**（`bopomo_onionplus`，基於 [Onion Rime Files](https://github.com/oniondelta/Onion_Rime_Files) 二次開發）。

---

## 🚦 動手前必讀的六條規則

1. **改完要「套用」；yaml 還要部署，lua 還要重啟 WeaselServer**
   lua 只在 WeaselServer 程序啟動時載入一次，**部署不會重讀 lua**。
   `pwsh scripts\rime-update.ps1 -SkipPull` 一次做完套用＋判斷要不要部署／重啟。

2. **驗證一律在沙盒，不要用「看起來對」當結論**
   `pwsh tools\rime-test.ps1 -Sync -Mode basic` → 黃金樣本（目前 53 條）必須全 PASS 才算沒退步。
   沙盒是 `%TEMP%\rime_sandbox`，用同一支 `rime-apply.ps1` 攤平，不碰使用者真實資料夾與詞庫。

3. **個人資料不進 repo**
   詞頻（`*.userdb/`、`sync/`）、個人短語（`bopomo_onionplus_phrase.txt`）、個人安裝選項（`na_options.custom.yaml`）、
   `installation.yaml`、`user.yaml`、`build/` 都只存在使用者資料夾。repo 是公開的：
   信箱、機器名稱、個人路徑都不要寫進任何會提交的檔案（含 commit 訊息）。

4. **改上游方案檔請用 `*.custom.yaml` patch，不要直接改原檔**
   `bopomo_onionplus.schema.yaml` 等是上游檔案，直接改會在上游更新時衝突。

5. **改 lua 只做最小改動、保留註解掉的歷史程式碼**
   這套 lua 有大量看似冗餘但有用的分支；重構過三輪，每輪都以逐條回歸擔保行為不變。

6. **`rime/` 裡不同分類之間檔名不能重複；新增檔案要放進對的分類**
   除了 `lua/`、`opencc/`，其他分類都會被攤平到同一層，撞名的話 `rime-apply` 會直接報錯。
   不要在 `rime/` 根目錄直接放檔案（只有子資料夾裡的會被套用）。

---

## 📁 `rime/` 的分類

| 資料夾 | 放什麼 |
|---|---|
| `rime/core/` | `default.custom.yaml`（全域快捷鍵、方案清單）、`rime.lua`、`na_options.yaml`（安裝選項預設值）、`cheatsheet.html` |
| `rime/theme/` | `weasel.custom.yaml`、`squirrel.custom.yaml`（配色、字型、排版） |
| `rime/bopomofo/` | 注音主方案 `bopomo_onionplus*`、中文詞庫、語言模型 `.gram`、注音文 `allbpm`、符號 `symbols_bpmf`、倉頡反查、短語範本 |
| `rime/japanese/` | `jpnin1*`（含三語釋義詞典 `jpnin1_gloss*`）、日文詞庫 |
| `rime/korean/` | `hangeul*`、韓文詞庫 |
| `rime/english/` | `easy_en_*`、英文詞庫 |
| `rime/european/` | 拉丁 `latinin1`、希臘 `greek`、俄文 `cyrillic` |
| `rime/fullshape/` | 全形 |
| `rime/lua/` | 全部 lua（安裝時保留資料夾結構） |
| `rime/opencc/` | opencc 對照表（安裝時保留資料夾結構） |

## 🗺️ 我要改 X，該動哪個檔？

| 需求 | 檔案 |
|---|---|
| **安裝時可選的項目**（目前用哪個主題、直／橫排、emoji 預設、釋義語言、方案清單） | 預設值 `rime/core/na_options.yaml`；詢問與寫檔 `install.ps1`＋`install.sh`（**兩支要同步改**）；個人值在使用者資料夾的 `na_options.custom.yaml`。**別把這些值寫死回 `*.custom.yaml`**，原委見 GOTCHAS「安裝腳本與安裝選項」 |
| 安裝／重新設定流程 | `install.ps1`（Windows，**UTF-8 無 BOM**）、`install.sh`（macOS，bash 3.2 相容）；本機重跑入口 `scripts/rime-setup.cmd`（使用者資料夾裡的 `na-setup.cmd` 會轉過來） |
| 檔案怎麼從 repo 進到使用者資料夾 | `scripts/rime-apply.ps1`／`rime-apply.sh`（攤平、只複製有變的、依 `na_manifest.txt` 清舊檔、產生啟動器） |
| 配色定義、字型、視窗排版（Windows） | `rime/theme/weasel.custom.yaml` |
| 配色、字型（macOS） | `rime/theme/squirrel.custom.yaml`（**格式與 Weasel 不同，勿互抄**） |
| 全域快捷鍵、方案清單 | `rime/core/default.custom.yaml` |
| 主方案行為（選字鍵、開關、filter/translator 掛載） | `rime/bopomofo/bopomo_onionplus.custom.yaml` |
| ⇧1~6 選字的按鍵與標籤 | 鍵：`p_select_keys/keys` ＋ `rime/lua/processor_p_select_keys.lua`；標籤：`menu/alternative_select_labels`（**別設** `alternative_select_keys`，macOS 標籤會壞） |
| 方案顯示名稱 | 各 `*.custom.yaml` 的 `"schema/name"` |
| 自訂詞（打 `email` 出信箱那種） | 個人的：使用者資料夾的 `bopomo_onionplus_phrase.txt`（改完要**部署**）；給新使用者的範本：`rime/bopomofo/bopomo_onionplus_phrase.sample.txt` |
| `'/` 開頭的多功能（日期／計算機／Unicode…） | `rime/lua/mf_components/` → 見 [架構文件](docs/ARCHITECTURE.md) |
| `'/ts`、`'/uuid`、`'/pw`、`'/rgb`、`'/cs` | `rime/lua/translator_devkit.lua` |
| 日文候選釋義（中／英／日） | `rime/lua/filter_gloss.lua` ＋ `rime/japanese/jpnin1_gloss*.dict.yaml` |
| 使用者速查表 | `rime/core/cheatsheet.html`（`'/h`＋空格開啟） |
| 一級指令代碼（`'/h` `'/git` `'/phrase` `'/cmd`） | `rime/lua/p_components/p_run_pattern.lua`（提示候選由 `mf_open_menu.register_direct` 產生，動作攔截在 `processor_p_run_files.lua`） |
| `'/` 分層選單內容（含 `'/dev`、`'/code` 子選單） | `rime/lua/mf_components/mf_menu_data.lua`（新增子選單記得在 `mf_open_menu.lua` `register_exact`） |
| `'/git` 實際跑的內容 | 使用者資料夾的 `na-update.cmd`／`na-update.command`（安裝時產生的啟動器）→ repo 的 `scripts/rime-update.cmd` → `rime-update.ps1`（Win；`.cmd` 負責挑 pwsh 或 powershell 5.1）／`scripts/rime-update.command`（Mac） |

---

## ⌨️ 常用指令

```powershell
# 套用到這台的輸入法（改 yaml 或 lua 後都用這個）
#   把 rime\ 攤平複製到使用者資料夾 → 有變動才部署／重啟 → 用 /quit 優雅停服務、
#   並等編譯真的跑完才回報完成。沒變動時完全不碰輸入法。加 -Force 強制部署＋重啟。
#   ⚠ 別再直接叫 WeaselDeployer /deploy —— 服務活著時部署，IME 收鍵不回字
#     ＝使用者體感的「卡死」；而且 deployer 回傳不代表編譯完成。
#     完整原委見 docs/GOTCHAS.md「部署會讓 IME 卡死」那幾條。
pwsh scripts\rime-update.ps1 -SkipPull

# 只複製檔案、不碰輸入法
pwsh scripts\rime-apply.ps1

# 重跑安裝流程重選選項（用這份 repo、不連網）
scripts\rime-setup.cmd
scripts\rime-setup.cmd -Theme dark -Langs ja,en -Yes

# 回歸測試（改任何行為後）
pwsh tools\rime-test.ps1 -Sync -Mode basic     # 黃金樣本須全 PASS
pwsh tools\rime-test.ps1 -Mode gloss           # 三語釋義
pwsh tools\rime-test.ps1 -Mode cands  -InputSeq "6sakura"    # 看全部候選＋註解
pwsh tools\rime-test.ps1 -Mode commit -InputSeq "'/uuid "    # 看上屏結果

# 多機同步（pull → 套用 → commit → push）—— 只有維護者用
pwsh scripts\rime-sync.ps1
```

⚠ 測試安裝腳本時**一定要設 `NA_NO_DEPLOY=1`，並把 `NA_RIME_DIR`、`NA_HOME` 都指到臨時資料夾**，
否則它會真的停掉使用者的輸入法服務、搬走使用者資料夾。`NA_REPO` 可以指到本機 repo（`file:///…`）。
（`rime-update.ps1` 另有一道防呆：目標不是小狼毫登錄的資料夾又沒加 `-NoDeploy` 會直接拒絕。）

macOS（鼠鬚管）對應指令：

```bash
# 套用到這台＋有變動才重新部署（鼠鬚管沒有獨立 Deployer，reload 會一併重載 lua）
bash scripts/rime-update.command --skip-pull

# 重跑安裝流程重選選項（用這份 repo、不連網）
bash install.sh --local

# 多機同步（維護者用）
bash scripts/rime-sync.sh

# 部署日誌（部署失敗時看這裡，會指出是哪個 yaml 出錯）
ls -t /tmp/rime.squirrel.* | head; tail -50 "$(ls -t /tmp/rime.squirrel.ERROR* | head -1)"
```

⚠ `tools/rime-test.ps1` 的沙盒回歸測試目前**只有 Windows 版**。在 Mac 上改了行為，
要嘛推到 Windows 那台跑測試，要嘛在 Mac 上實機驗證後才算數——不要用「應該可以」結案。

---

## 📚 延伸文件（需要時再讀，別預先全載）

- [docs/KEYMAP.md](docs/KEYMAP.md) — **鍵位與代碼總表（自動產生）**。「這個鍵／這個 `'/` 代碼現在是誰在用？」先查這裡，別再從頭調查。
  過期就重跑 `pwsh tools/keymap-dump.ps1`（讀使用者資料夾的 `build/`，所以要先套用並部署）。
- [docs/GOTCHAS.md](docs/GOTCHAS.md) — **踩過的坑與反直覺事實**。遇到「明明改了卻沒效果」「按鍵沒反應」先查這裡，能省下大量重複調查。
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — lua 模組圖、資料流、如何新增一個代碼／日期格式。
- [docs/HISTORY.md](docs/HISTORY.md) — 已完成的重大變更與**已知未修的原版瑕疵**（避免把「已知現象」當成新 bug 重查）。
- [rime/lua/mf_components/README.md](rime/lua/mf_components/README.md) — 多功能家族的資料驅動架構細節。

文件裡沒寫資料夾的檔名（例如 `weasel.custom.yaml`、`lua/xxx.lua`）指的是**使用者資料夾裡攤平後的名字**；
在 repo 裡要到 `rime/<分類>/` 底下找（`lua/…` 對應 `rime/lua/…`）。

## 🎯 使用者偏好

- 溝通用**繁體中文**。
- 這個 repo 是**公開**的，文件與腳本的讀者是不認識維護者環境的一般使用者。
- 重視**先驗證再上線**：使用者說過「請驗證後再做」。做完要能拿出實測輸出，不要只說「應該可以」。
- 不喜歡「洋蔥」字眼出現在使用者可見處（上游品牌），但 README 保留出處連結。
