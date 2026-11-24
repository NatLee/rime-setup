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

主方案：**注音Na+**（方案 id 是 `bopomo_onionplus`；id 沿用舊名是因為詞頻資料庫以它命名，改了使用者的用字習慣會歸零）。

---

## 🚦 動手前必讀的七條規則

1. **改完要「套用」；yaml 還要部署，lua 還要重啟 WeaselServer**
   lua 只在 WeaselServer 程序啟動時載入一次，**部署不會重讀 lua**。
   `pwsh scripts\rime-update.ps1 -SkipPull` 一次做完套用＋判斷要不要部署／重啟。

2. **驗證一律在沙盒，不要用「看起來對」當結論**
   `pwsh tools\rime-test.ps1 -Sync -Mode basic` → 黃金樣本（目前 59 條）必須全 PASS 才算沒退步。
   沙盒是 `%TEMP%\rime_sandbox`，用同一支 `rime-apply.ps1` 攤平，不碰使用者真實資料夾與詞庫。
   沙盒裡「開檔案／跑腳本」的動作一律只記錄、不執行，測試不會開瀏覽器也不會真的跑更新。
   動到套用腳本、安裝腳本的選項段、或 `weasel`／`default` 的檔案配置，再加跑 `-Mode gui`（33 條）。

3. **個人資料不進 repo**
   詞頻（`*.userdb/`、`sync/`）、個人短語（`bopomo_onionplus_phrase.txt`）、個人安裝選項（`na_style.custom.yaml`、`na_input.custom.yaml`、`na_menu.custom.yaml`）、
   `weasel.custom.yaml`、`default.custom.yaml`（見第 7 條）、
   `installation.yaml`、`user.yaml`、`build/` 都只存在使用者資料夾。repo 是公開的：
   信箱、機器名稱、個人路徑都不要寫進任何會提交的檔案（含 commit 訊息）。

4. **改上游方案檔請用 `*.custom.yaml` patch，不要直接改原檔**
   `bopomo_onionplus.schema.yaml` 等是上游檔案，直接改會在上游更新時衝突。

5. **改 lua 要以回歸擔保行為不變；沒人用的東西可以刪**
   這套 lua 有大量看似冗餘但有用的分支，動之前先確認真的沒人走到（`rime.lua` 沒綁、沒有方案掛、
   沒有模組 require），刪完跑回歸；重構則先存一份 `-Mode snapshot`，改完 diff 應該一字不差。`rime.lua` 只掛有方案在用的元件 —— 每一行 require 都是啟動成本。
   ⚠ 別為了「效能」去改 lua filter：實測每個按鍵 2.5～3.5 ms，把 lua filter 全拿掉也量不出差別
   （`pwsh tools\rime-test.ps1 -Mode bench`）。

6. **`rime/` 裡不同分類之間檔名不能重複；新增檔案要放進對的分類**
   除了 `lua/`、`opencc/`，其他分類都會被攤平到同一層，撞名的話 `rime-apply` 會直接報錯。
   不要在 `rime/` 根目錄直接放檔案（只有子資料夾裡的會被套用）。

7. **使用者資料夾裡「使用者的檔」只建立、不覆蓋；repo 不可以把內容放進去**
   `weasel.custom.yaml`、`default.custom.yaml` 是小狼毫「輸入法設定」對話框會寫的檔（配色、方案清單），
   所以歸使用者：裡面只有一行 `__include` 接上 repo 的 `na_weasel.yaml`／`na_default.yaml`，
   對話框與使用者寫的鍵蓋在上面。**要改候選窗或全域設定，改 `na_weasel.yaml`／`na_default.yaml`，
   不要在 `rime/` 裡新增 `weasel.custom.yaml`／`default.custom.yaml`。**
   個人檔的名字、格式、或「哪個檔歸使用者」一改，`rime-apply.ps1` 與 `.sh` 的**版面編號要一起加 1**
   —— 否則舊版的 clone 套用到新版面的資料夾，會把使用者的選項重置（原委見 GOTCHAS「設定一直被重置」）。

---

## 📁 `rime/` 的分類

| 資料夾 | 放什麼 |
|---|---|
| `rime/core/` | `na_default.yaml`（全域快捷鍵、方案清單、中英切換鍵）、`rime.lua`、安裝選項預設值 `na_style.yaml`（長相）／`na_input.yaml`（emoji、釋義）／`na_menu.yaml`（方案清單）、`cheatsheet.html` |
| `rime/theme/` | `na_weasel.yaml`（Windows）、`squirrel.custom.yaml`（macOS）：配色、字型、排版 |
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
| **安裝時可選的項目**（目前用哪個主題、直／橫排、emoji 預設、釋義語言、方案清單） | 預設值分三個檔：`rime/core/na_style.yaml`（主題、字型、字級、排列）、`na_input.yaml`（emoji、釋義語言）、`na_menu.yaml`（方案清單）—— **新選項要放進對的那個檔**，放錯會讓換主題也重編所有方案；詢問與寫檔 `install.ps1`＋`install.sh`（**兩支要同步改**，只重寫內容有變的檔）；個人值在使用者資料夾對應的 `na_*.custom.yaml`。**別把這些值寫死回 `na_weasel.yaml`／`squirrel.custom.yaml`／方案的 `*.custom.yaml`**，原委見 GOTCHAS「安裝腳本與安裝選項」 |
| 安裝／重新設定流程 | `install.ps1`（Windows，**UTF-8 無 BOM**）、`install.sh`（macOS，bash 3.2 相容）；本機重跑入口 `scripts/rime-setup.cmd`（使用者資料夾裡的 `na-setup.cmd` 會轉過來） |
| 檔案怎麼從 repo 進到使用者資料夾 | `scripts/rime-apply.ps1`／`rime-apply.sh`（攤平、只複製有變的、依 `na_manifest.txt` 清舊檔、建立使用者的 `weasel.custom.yaml`／`default.custom.yaml`、轉換舊版面的個人檔、產生啟動器） |
| 配色定義、字型、視窗排版（Windows） | `rime/theme/na_weasel.yaml`（使用者資料夾的 `weasel.custom.yaml` 用 `__include` 接它，見規則 7） |
| 配色、字型（macOS） | `rime/theme/squirrel.custom.yaml`（**格式與 Weasel 不同，勿互抄**） |
| 全域快捷鍵、方案清單 | `rime/core/na_default.yaml`（使用者資料夾的 `default.custom.yaml` 用 `__include` 接它，見規則 7） |
| 單按右 Shift 循環切換語言 | `rime/lua/processor_schema_cycle.lua`；跳過哪些方案：`na_default.yaml` 的 `schema_cycle/skip`；**每個選單方案**的 `*.custom.yaml` 都要掛 `lua_processor@schema_cycle` 在 processors 最前面 |
| 「把文字換成另一套字型／符號」的轉換（英文字母樣式、數字樣式） | 用 `rime/lua/filter_cand/projector.lua` 的工廠：`local x = projector("xlit|…|…|", …)`，不要再手寫「建 Projection → apply」的樣板 |
| processor 裡判斷按鍵（該略過？確認鍵？第幾個選字鍵？當頁起點？） | `rime/lua/p_components/p_key_util.lua`，不要各寫各的 |
| 注音主方案的按鍵調度（英文標點、掛接段落上屏修正、計算機小鍵盤） | `rime/lua/processor_mix_apc_s2rm_ltk.lua`；新增一種前綴掛接語言在檔頭的 `PREFIXED_SEGMENTS` 加一列 |
| 新增／移除一個 lua 元件 | `rime/core/rime.lua`（掛接表）＋方案的 `engine/*`＋ `rime/lua/` 的模組，三處一起 |
| 主方案行為（選字鍵、開關、filter/translator 掛載） | `rime/bopomofo/bopomo_onionplus.custom.yaml` |
| ⇧1~6 選字的按鍵與標籤 | 鍵：`p_select_keys/keys` ＋ `rime/lua/processor_p_select_keys.lua`；標籤：`menu/alternative_select_labels`（**別設** `alternative_select_keys`，macOS 標籤會壞） |
| 方案顯示名稱 | **直接改 `*.schema.yaml` 的 `schema/name`**（少數允許直接改上游檔的地方）。小狼毫的「輸入法設定」對話框讀的是原始名稱，不吃 custom 的 patch；只 patch 的話選單對了、對話框還是舊名 |
| emoji 聯想、字集過濾、符號標註的對照表 | `rime/opencc/*.txt` 是來源，輸入法讀的是編譯後的 `.ocd2`。**改了 .txt 要跑 `pwsh tools\opencc-build.ps1` 重編**（需要 Docker），兩個檔一起提交 |
| 候選字型（粉圓體／系統字型） | 預設值（系統字型）在 `rime/core/na_style.yaml` 的 `font_face`／`comment_font_face`／`mac_*`；安裝腳本選粉圓體時偵測或下載安裝字型，再把實際的字型名稱寫進個人選項檔。字型檔不進 repo |
| 新增一個主題 | 配色加進 `rime/theme/na_weasel.yaml` **和** `squirrel.custom.yaml` → `install.ps1`、`install.sh` 的主題清單與對照表 → `pwsh tools\theme-preview.ps1` 重產預覽圖 → README「主題」那張表加一格 |
| `'/setup`（選項畫面） | 就是安裝腳本的互動選單：`install.ps1`／`install.sh` 裡「目前的設定」那個迴圈。輸入法端的入口在 `p_run_pattern.lua` 的 `setup` 與 `mf_menu_data.lua` 的 `set` 選單。它開的視窗成功會自己關（`scripts/rime-setup.cmd`）。小狼毫對話框選的配色／方案清單怎麼跟選項並存：GOTCHAS「小狼毫設定對話框與 `*.custom.yaml`」 |
| 自訂詞（打 `email` 出信箱那種） | 個人的：使用者資料夾的 `bopomo_onionplus_phrase.txt`（改完要**部署**）；給新使用者的範本：`rime/bopomofo/bopomo_onionplus_phrase.sample.txt` |
| `'/` 開頭的多功能（日期／計算機／Unicode…） | `rime/lua/mf_components/` → 見 [架構文件](docs/ARCHITECTURE.md) |
| `'/ts`、`'/uuid`、`'/pw`、`'/rgb`、`'/cs` | `rime/lua/translator_devkit.lua` |
| 日文候選釋義（中／英／日） | `rime/lua/filter_gloss.lua` ＋ `rime/japanese/jpnin1_gloss*.dict.yaml` |
| 使用者速查表 | `rime/core/cheatsheet.html`（`'/h`＋空格開啟） |
| 一級指令代碼（`'/h` `'/git` `'/phrase` `'/cmd`） | `rime/lua/p_components/p_run_pattern.lua`（提示候選由 `mf_open_menu.register_direct` 產生，動作攔截在 `processor_p_run_files.lua`） |
| `'/` 分層選單內容（含 `'/dev`、`'/code` 子選單） | `rime/lua/mf_components/mf_menu_data.lua`（新增子選單記得在 `mf_open_menu.lua` `register_exact`） |
| `'/git` 實際跑的內容 | 使用者資料夾的 `na-update.cmd`／`na-update.command`（安裝時產生的啟動器）→ repo 的 `scripts/rime-update.cmd` → `rime-update.ps1`（Win；`.cmd` 負責挑 pwsh 或 powershell 5.1）／`scripts/rime-update.command`（Mac） |
| 從 lua 開檔案／程式／網址／批次檔 | 一律呼叫 `rime/lua/p_components/p_generic_open.lua`。**Windows 上不可以自己寫 `os.execute`**：它會等子行程結束，輸入法服務因此卡住五秒（原委與量測方法見 GOTCHAS「不可以用 `os.execute`」） |

---

## ⌨️ 常用指令

```powershell
# 套用到這台的輸入法（改 yaml 或 lua 後都用這個）
#   把 rime\ 攤平複製到使用者資料夾 → 有變動才部署（服務保持運作，等部署器真的結束）
#   → lua 有變才用 /quit 優雅重啟服務。沒變動時完全不碰輸入法。加 -Force 強制部署＋重啟。
#   ⚠⚠ 改這支腳本的流程之前先讀 docs/GOTCHAS.md「部署時不可以先把服務停掉」：
#     「先停服務再部署」會讓所有用輸入法的程式一起沒回應（出過兩次事）。
#     這類錯沙盒抓不到，改完一定要對實機跑三種情境：沒變動、只有 yaml 變動、-Force，
#     而且要用 Windows PowerShell 5.1 跑（有只在 5.1 才出現的錯）。
pwsh scripts\rime-update.ps1 -SkipPull

# 只複製檔案、不碰輸入法
pwsh scripts\rime-apply.ps1

# 重跑安裝流程重選選項（用這份 repo、不連網）
scripts\rime-setup.cmd
scripts\rime-setup.cmd -Theme dark -Langs ja,en -Yes

# 回歸測試（改任何行為後）
pwsh tools\rime-test.ps1 -Sync -Mode basic     # 黃金樣本須全 PASS
pwsh tools\rime-test.ps1 -Mode gloss           # 三語釋義
pwsh tools\rime-test.ps1 -Mode cycle           # 單按右 Shift 循環切換語言
pwsh tools\rime-test.ps1 -Mode gui             # 小狼毫設定對話框改的配色／方案清單：會生效、更新不蓋掉、'/setup 能取代
pwsh tools\rime-test.ps1 -Mode bench           # 每個按鍵的處理時間
pwsh tools\rime-test.ps1 -Mode load            # 切換到注音方案要多久（目前約 60 ms）
pwsh tools\rime-test.ps1 -Sync -Mode snapshot > before.txt   # 重構護欄：全候選＋上屏快照，改完再跑一次 diff
pwsh tools\rime-test.ps1 -Mode cands  -InputSeq "6sakura"    # 看全部候選＋註解
pwsh tools\rime-test.ps1 -Mode commit -InputSeq "'/uuid "    # 看上屏結果

# 多機同步（pull → 套用 → commit → push）—— 只有維護者用
pwsh scripts\rime-sync.ps1
```

⚠ 測試安裝腳本時**一定要設 `NA_NO_DEPLOY=1`，並把 `NA_RIME_DIR`、`NA_HOME` 都指到臨時資料夾**，
否則它會真的停掉使用者的輸入法服務、搬走使用者資料夾。`NA_REPO` 可以指到本機 repo（`file:///…`）。
（`rime-update.ps1` 另有一道防呆：目標不是小狼毫登錄的資料夾又沒加 `-NoDeploy` 會直接拒絕。）
`-Mode gui` 已經照這個方式把安裝腳本對著沙盒跑過一輪，改選項段的邏輯先看它夠不夠用。

⚠ **這台電腦可能有兩份 clone**（安裝指令放的 `~/.na-plus` ＋ 你正在改的這份）。誰最後套用，
使用者資料夾裡的 `na-setup.cmd`／`na-update.cmd` 就指向誰 —— 也就是說，你從這份 repo 套用之後，
使用者打 `'/setup`、`'/git` 跑的是**這份還沒提交的程式**；反過來，使用者回報「`'/setup` 的行為」時，
先看 `na-setup.cmd` 指向哪一份，別對著錯的那份除錯。

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

文件裡沒寫資料夾的檔名（例如 `na_weasel.yaml`、`lua/xxx.lua`）指的是**使用者資料夾裡攤平後的名字**；
在 repo 裡要到 `rime/<分類>/` 底下找（`lua/…` 對應 `rime/lua/…`）。

## 🎯 使用者偏好

- 溝通用**繁體中文**。
- 這個 repo 是**公開**的，文件與腳本的讀者是不認識維護者環境的一般使用者。
- 重視**先驗證再上線**：使用者說過「請驗證後再做」。做完要能拿出實測輸出，不要只說「應該可以」。
- 出處統一放在 README 的「來源與致謝」：這套設定的基礎來自洋蔥注音，那一段要留著；各檔案開頭不再逐一署名。
  其他第三方資料的來源與授權聲明（JMdict、WordNet、ECDICT、sc-dictionary、倉頡的發明人…）留在各檔頭，不要動。
