# 踩過的坑（Gotchas）

> 這份文件的目的：**讓後來的人／AI 不必重新調查一次**。每一條都是實際花時間查出來的。

## 部署與生效

### lua 改了卻沒效果 → 要重啟 WeaselServer
lua 只在 **WeaselServer 程序啟動時**載入一次。「重新部署」只重編 yaml/詞典，**不會重讀 lua**。
```powershell
Stop-Process -Name WeaselServer -Force; Start-Process 'C:\Program Files\Rime\weasel-0.17.4\WeaselServer.exe'
```
`scripts\rime-sync.ps1` 已自動處理（偵測到 lua 變更就重啟）。

### 沙盒測試看到舊行為 → build 陳舊
沙盒的 `build\` 不會自動重編。改了 yaml 必須 `-Sync`（會跑 `RimeStartMaintenance(full_check)`）或砍掉沙盒 build。
**曾因此誤判**「patch 沒生效」，其實正式環境從頭就是好的。

### 詞典要被編譯，必須有人「引用」它
新增 `xxx.dict.yaml` 不會自動編譯。需要：
1. 一個最小 stub schema（`jpnin1_gloss.schema.yaml` 就是這種），**且**
2. 被某個啟用中的方案 `schema/dependencies` 引用（或列入 `schema_list`）。
否則 `reverse_lookup_filter` 會找不到 `.reverse.bin`。

### lua 檔存在 ≠ 有掛載 → 「畫得出選單、按下去沒反應」
`lua/processor_p_run_files.lua` 一直躺在 repo 裡，但 `bopomo_onionplus.custom.yaml` 的
`engine/processors` **從來沒有列它**。結果是：translator 照樣把 `'/j` 的選單畫出來，
但按空白鍵什麼也不會發生 —— 因為執行動作的那半邊根本沒被載入。
`'/jh` 打不開速查表、`'/git` 不跳終端機、選單 Enter 進不去，全是同一個原因。

librime **不會**因為 `lua/` 底下多了一個檔就自動掛載，元件一定要出現在
`engine/processors`／`engine/filters`／`engine/translators` 裡。
一分鐘診斷法 —— 直接看部署後的合併結果：

```bash
python3 -c "import yaml;print(yaml.safe_load(open('build/bopomo_onionplus.schema.yaml'))['engine']['processors'])"
```

順序也有講究：要攔空白鍵就得排在 `express_editor` 之前，要攔選字鍵（`!@#$%^`）
就得排在 `p_select_keys`／`selector` 之前。`p_run_files` 放在**鏈首**（連
`mix_apc_s2rm_ltk` 都要排在它後面）；⇧1~6 選字本身則是另一個元件 `p_select_keys`
（排在 `recognizer` 之後、`speller` 之前，理由見本文後面兩條選字鍵的段落）。

⚠ 補列進 yaml 之後**仍然沒生效**，是因為還缺 `rime.lua` 那半邊 —— 見下一條。

### 選字鍵給的是「當頁第幾個」，不是絕對序號
`seg.selected_index` 是**絕對**索引（第 8 列就是 7），但使用者按 `⇧1`～`⇧6`
指的是**這一頁**的第幾列。選單超過一頁時，兩者不換算就會選錯：
```lua
local ps = env.page_size   -- 讀 menu/page_size，別寫死
n = ps * math.floor((seg.selected_index or 0) / ps) + n
```
專案內 `processor_zhuyin_space.lua`、`processor_mix_zhs_ltk.lua` 也是同樣寫法（那邊是 9）。

### 選單只顯示第一列 → uniquifier 把候選文字相同的列合併了
`engine/filters` 末端掛著 `uniquifier`，它**以候選文字去重**。
選單類候選若把文字留空（想讓選中時不上屏任何東西），六列會被併成一列。
上游把 ①②③ 塞進候選文字就是為了閃這個，不是為了好看。
→ 本專案改成把「該列的代碼」（`'/dt`、`'/f`…）當候選文字：天然唯一，
而且看得到代碼、下次可以直接打。

### 掛在 `engine/processors` ≠ 會被載入 → `rime.lua` 還要 bind 元件名
`lua_processor@p_run_files` 這個名字，librime-lua 是去 **Lua 全域表**找 `p_run_files`，
而那個全域變數只在 `rime.lua` 建立。`rime.lua` 裡那行一直是註解掉的：

```lua
-- p_run_files = require("processor_p_run_files")   -- ← 這樣等於 yaml 那行沒寫
```

結果：元件建不出來，**不會報錯、不會少任何候選**，只是整段 `'/` 動作邏輯從未執行。
症狀是「選單畫得出來，選中卻把候選文字本身上屏」（打 `'/` 按 ⇧1 → 文件裡出現 `'/dt`）。
`docs/GOTCHAS.md` 先前那條「lua 檔存在 ≠ 有掛載」只講了 yaml 那一半，**兩邊都要對**。

診斷：yaml 掛了某個 `lua_*@name`，就到 `rime.lua` 搜 `name =`，確認不是註解。

### `'/` 選單按空白沒反應／吐字面代碼 → 被 `mix_apc_s2rm_ltk` 搶先
`mix_apc_s2rm_ltk` 對 `#input == caret_pos` 的空白／Enter 一律
`context:confirm_current_selection()`。它排在 `p_run_files` 前面時，選單的空白鍵
永遠到不了 `p_run_files`，於是「選中」變成「把候選文字上屏」。
→ `p_run_files` 必須排在 **processor 鏈的最前面**（在 `mix_apc_s2rm_ltk`、
`selector`、`speller`、`express_editor` 全部之前）。
⚠ 排到鏈首後，第一個按鍵時 `composition` 可能是空的，`comp:back()` 要先用
`not comp:empty() and comp:back() or nil` 擋掉。

### `register_exact` 是「後註冊覆蓋前註冊」→ `'/c` 指令選單被靜默吃掉
`mf_components/core/registry.lua` 就是 `exact[code] = handler`，沒有衝突檢查。
`translator_multifunction_translator.lua` 的註冊順序是
`mf_open_menu`(24) → … → `mf_unicode`(29)，所以 `mf_unicode` 的
`register_exact("c", 內碼十進制)` 會**蓋掉** `mf_open_menu` 的 `register_exact("c", 指令選單)`。
畫面上 `'/c` 顯示的是【內碼十進制】▶，指令選單根本進不去，而且**沒有任何錯誤訊息**。

→ 指令命名空間固定用 **`j`**（上游沿用的字母，`'/` 底下沒有任何以 j 開頭的代碼）。
曾經改成 `c`（command，比較好記）造成三重撞碼，已改回：

| 代碼 | 原本就有的用途 | 命名空間用 `c` 時的衝突 |
|---|---|---|
| `'/c` | Unicode 十進制內碼（`'/c20013`→中） | 指令選單被覆蓋，永遠打不開 |
| `'/cs…` | devkit 命名風格轉換（`'/cshello.world`） | 與「指令 `c` ＋開啟碼 `s`」同形 |
| `'/ca` | `c`＋hex 字元 `a`，被內碼 matcher 吃掉 | 計算機子選單被迫改名 `'/num` |
| `'/cc` | — | 「命名空間 c ＋開啟碼 c（編輯自訂短語）」疊字 |

新增 `'/` 代碼前，先確認它不在 `mf_open_menu`／`mf_letters`／`mf_unicode`／
`dt_specs_*`／`translator_devkit` 已註冊的集合裡。

### 新增 `'/` 代碼前先查 `docs/KEYMAP.md`
`tools/keymap-dump.ps1` 會從**部署後的 `build/`** 與 lua 原始碼倒出「哪個鍵、哪個代碼
現在是誰在用」。這份表存在的目的就是省掉重複調查 —— 改完快捷鍵或代碼記得重跑：

```powershell
pwsh tools\keymap-dump.ps1     # 讀 build\，所以要先部署
```

### `'/j<字首>` 前綴搜尋：完整代碼一定要回 nil
`mf_menu_data.lookup` 對 `'/jg` 這種「打不完整」的碼回傳過濾後的選單，
但對剛好等於某一列的完整碼（`'/jt`、`'/jh`…）**必須回 nil**。
否則選中那一列會 `push_input` 回同一串輸入 → 畫面沒變、看起來像當掉。
「完整＝直接執行、不完整＝列出候選」正好就是 slash command 的語義。

### 沙盒回歸測試不能寫死候選字
沙盒的 `*.userdb` 不隨 `-Sync` 覆蓋（robocopy 有排除），會**跨次累積學習**：
每上屏一次就把那個字往前推，候選順序跟著漂移。
於是「⇧2 應該選到妳」這種斷言會時綠時紅，浪費一整輪調查。
→ `rime-test.ps1` 用 `(cand:N)` 標記，在**上屏之前**當場問引擎第 N 個候選是什麼再比。
⚠ 換算一定要在 `Get-Commit` 之前做：上屏本身就會改變順序，事後再問已經來不及。

### 指令選單的每一列「選中即執行」——測試不要按下去
`'/j` 那一頁選中會真的開檔案／開瀏覽器，主選單 ⇧2 會真的跑
`scripts/rime-update.ps1`（git pull → 部署 → 重啟服務）。
測試期間誤觸過兩次（`git pull --ff-only` 因本機有未提交變更而失敗，沒造成損害）。
→ 選單相關的回歸一律用 `Get-Preedit` 驗編碼列，只有 `'/dt`、`'/num` 這種
純跳轉的列才可以用 `Get-Commit`。

### 詞典有、schema 沒有 → 乾淨環境部署直接壞
`cangjie5.dict.yaml` 曾經只有詞典、沒有 `cangjie5.schema.yaml`，但五個方案的
`schema/dependencies` 都列了它、並用 `dictionary: cangjie5` 做倉頡反查（前綴 `=`）。
舊機器看起來正常，是因為 `build/` 裡還躺著陳年的 `cangjie5.*.bin`；
**在乾淨環境（macOS 首次 clone）反查會直接查不到**。
→ 已補上反查掛載用的 `cangjie5.schema.yaml`。
⚠ 這種掛載 stub **不可**照抄 `jpnin1_gloss.schema.yaml` 的 `algebra: erase/^.+$/`——
那會把 prism 清空，用倉頡碼反查就查不到了；只有「純粹為了編譯詞典」的掛載才能那樣寫。

## macOS（鼠鬚管）專屬

### F1~F4／F4 在 Mac 上按了沒反應 → 被系統當媒體鍵吃掉
macOS 預設 F1~F4 是亮度／調度中心／Spotlight，**即使按住 Ctrl+Shift 也不會傳到輸入法**。
所以 `switcher/hotkeys` 的 `F4` 和 `Ctrl+Shift+F1~F4` 在 Mac 預設狀態下全是死的。
→ 兩個解法：系統設定 → 鍵盤開啟「將 F1、F2 等按鍵作為標準功能鍵」，
或改用已備援的 `Ctrl+` `` ` ``（方案選單）與 `Ctrl+Opt+1~4`（直接切方案）。
`Ctrl+Opt` 在 Windows 等同 AltGr、小狼毫本來就不轉送，兩邊綁在同一個檔案不會打架。

### 候選標籤顯示成 `!@#$%^` 而不是 `⇧1~⇧6` → patch 把整個 style 節點取代掉了
**RIME 的 `patch` 是「整個節點取代」，不是逐鍵合併。** 寫成巢狀區塊：

```yaml
patch:
  style:            # ← 這樣寫會把前端內建 squirrel.yaml 的整個 style 節點蓋掉
    font_point: 17
```

你沒寫的預設值會一起消失，其中包含 `candidate_format: '[label]. [candidate] [comment]'`。
鼠鬚管拿不到 `candidate_format` 就退回內建 fallback，標籤直接印選字鍵，
於是 `menu/alternative_select_labels` 設的 `⇧1~⇧6` 全被無視。

診斷方法（這招對任何「patch 好像沒生效」都管用）——直接看編譯後的合併結果：

```bash
python3 -c "import yaml;print(yaml.safe_dump(yaml.safe_load(open('build/squirrel.yaml'))['style'],allow_unicode=True))"
```

若輸出的鍵**剛好等於你 custom 裡寫的那些**、前端預設值一個都不在，就是踩到這個坑。

→ 改用路徑鍵逐鍵覆寫：`"style/font_point": 17`、`"preset_color_schemes/NatMatcha": {...}`。
`squirrel.custom.yaml` 已改寫完成。⚠ `weasel.custom.yaml` 目前仍是巢狀寫法，
Windows 端能動是因為小狼毫的 fallback 剛好可接受，但同樣在默默丟棄內建預設值。

### 【已解】macOS 標籤顯示 `!@#$%^` 而不是 `⇧1~⇧6` → 兩邊前端的取用優先序是反的
症狀：Windows 顯示 `⇧1.`～`⇧6.`，macOS 顯示**選字鍵本身** `!. @. #. $. %. ^.`，
改 `menu/alternative_select_labels` 完全沒反應（曾被記為「鼠鬚管的 bug、未解」）。

真正原因在 librime 與兩個前端的分工。`RimeGetContext` 會**同時**交出兩份資料
（`src/rime_api_impl.h`）：

```cpp
const string& select_keys(schema->select_keys());          // menu/alternative_select_keys
if (!select_keys.empty()) context->menu.select_keys = ...;
an<ConfigList> select_labels = config->GetList("menu/alternative_select_labels");
if (select_labels && (size_t)page_size <= select_labels->size())   // ← 數量要 ≥ page_size
  context->select_labels = ...;
```

而兩個前端挑哪一份用，順序剛好相反：

| 前端 | 程式碼 | 優先序 |
|---|---|---|
| 小狼毫 | `RimeWithWeasel.cpp` | `select_labels` → 沒有才 `select_keys` |
| 鼠鬚管 | `sources/SquirrelInputController.swift` | **`select_keys`** → 沒有才 `select_labels` |

```swift
if let select_keys = ctx.menu.select_keys {          // ← 有值就到此為止
  labels = String(cString: select_keys).map { String($0) }
} else if let select_labels = ctx.select_labels { ... }
```

所以只要 `menu/alternative_select_keys` 有值，macOS 就永遠看不到 labels。
而且它是**一個字元一個標籤**，塞不進 `⇧1` 這種兩字元的標籤。

→ 解法：**`menu/alternative_select_keys` 一律不設**（欄位為 NULL，兩邊都只剩 labels
可用），選字改由 `lua_processor@p_select_keys` 自己比對按鍵、呼叫 `context:select()`。
選字鍵字串放在 `p_select_keys/keys`（`p_run_files` 的 `'/` 選單共用同一個設定）。

驗證方式（Windows 上就能驗 macOS 的顯示，因為讀的是同兩個欄位）：

```powershell
pwsh tools\rime-test.ps1 -Mode labels -InputSeq su3
#   menu.select_keys = [(null)]              ← 必須是 null
#   select_labels    = [⇧1 ⇧2 ⇧3 ⇧4 ⇧5 ⇧6]
```

試過但**行不通**的作法，別再走一遍：
- `key_binder` 把 `Shift+exclam…` 轉 `KP_1~KP_6` 丟給 selector（selector 對小鍵盤數字
  有獨立分支，keycode ≥ 0x7f 不比對 select_keys）—— 看似漂亮，但 `mix_apc_s2rm_ltk`
  會在 `'/` 計算機／純數字模式把 `KP_n` 當成「用小鍵盤打數字」塞進輸入：
  `'/12345` 按 ⇧2 變成 `'/123452`，選不到「12,345」。回歸測試 T28 就是釘這件事。
- 只改 `style/candidate_format`：標籤內容不是前端算的，改格式救不了。

### 選字鍵會被 `recognizer` 搶走 → ⇧2 在注音輸入時選不到字
`recognizer` 排在 selection 之前，**只要「目前輸入＋這個鍵」還符合某條 pattern，
它就把鍵吃下去接進輸入**。於是有兩個選字鍵在特定情境是死的（改用 p_select_keys
之前就如此，不是本專案改出來的）：

| 鍵 | 吃掉它的 pattern | 死在哪 |
|---|---|---|
| `@`（⇧2） | `email_url_translator: ^[a-z][-_.0-9a-z]*@.*$` | 輸入以英文字母開頭時 —— 注音 `su3` 按 ⇧2 → 輸入變 `su3@` |
| `^`（⇧6） | `mf_translator: '/[-+*^/.,'();0-9a-z]*$` | `'/` 算式裡 —— `'/12345` 按 ⇧6 → 輸入變 `'/12345^` |

其餘情境都正常：`6sakura`（日文，開頭是數字）、`3app`（英文，開頭是 `3`）、
`'/u4e2d`、`'/` 分層選單（由 p_run_files 在鏈首接走）按 ⇧2 都選得到。
要讓 ⇧2 在注音也能選字，只能把 `p_select_keys` 移到 `recognizer` **之前**，
代價是不能再用 `@` 直接打 email（`abc@def.com` 那條路）—— 取捨題，目前選擇保留 email。

### 鼠鬚管沒有 `style/label_format`
那是小狼毫的鍵。鼠鬚管用 `style/candidate_format`，佔位符是
`[label]` `[candidate]` `[comment]`（也支援舊式 `%c` `%@`）。兩邊**不可互抄**。
查某個鍵前端到底認不認得：`strings -a Squirrel.app/Contents/MacOS/Squirrel | grep '^style/'`。

### shell 腳本在 Mac 噴 `XXX?: unbound variable` → macOS 的 bash 是 3.2
macOS 內建 `/bin/bash` 停在 **3.2**（2007 年，因 GPLv3 授權問題不再更新）。
在 3.2 底下，`$VAR` 後面若**緊接中文字**，多位元組字元會被吃進變數名：

```bash
echo "備份保留在 $BACKUP，確認後可刪除"   # bash 3.2 → BACKUP，: unbound variable
echo "備份保留在 ${BACKUP}，確認後可刪除" # 正確
```

現代 bash（5.x，含 Linux 與 Homebrew 版）**不會**重現這個錯誤，所以在 CI 或
Linux 沙盒測過不代表 Mac 會過。→ 中文字串裡的變數一律加大括號。

### Caps Lock 切不了中英 → 被 macOS 搶在前面
系統設定 → 鍵盤 → 輸入方式的「使用大寫鎖定鍵切換輸入法」會攔截 Caps，
`ascii_composer/switch_key` 永遠等不到事件。**必須手動關掉**，腳本改不到。

### 重裝／重新 clone 會把打字詞頻歸零
`*.userdb/` 與 `sync/` 被 `.gitignore` 排除（刻意的，避免兩台機器互相污染），
所以 `git clone` 出來的是空的。`scripts/bootstrap-mac.sh` 已會從備份目錄把 `*.userdb` 搬回來，
手動重裝時**別忘了這一步**，否則等於重新學一次你的用字習慣。

### private repo 不能用 HTTPS clone
腳本裡若寫 `https://github.com/NatLee/rime-config.git`，在非互動環境會卡在帳密輸入
（症狀是 `could not read Username for 'https://github.com'`）。→ 一律走 SSH。

### os.execute 在 Mac 的回傳值不能拿來判斷成敗
`start` 在 macOS 不存在，但 Lua 5.1／LuaJIT 的 `os.execute` 回傳的是 **exit code**，
127 在 Lua 裡是真值 → 「開啟失敗」會被當成成功，後面的 `open` 永遠輪不到。
→ `p_generic_open.lua` 已改成先用 `f_get_os_name` 判斷系統再挑指令。

## 按鍵與快捷鍵

### `Ctrl+Alt+字母` 完全沒反應 → Windows AltGr 保留組合
小狼毫**不會**把 `Ctrl+Alt+X` 轉送給輸入法（等同 AltGr）。引擎層測試會通過、實機永遠無效。
→ 方案切換改用 **`Ctrl+Shift+F1~F4`**（見 `default.custom.yaml`）。

### `Ctrl+Shift+6~9` 已被方案內建開關佔用
`element_bopomo.yaml` 的 key_binder 綁了字集／emoji／符號標註／Unicode 開關，方案層綁定優先。

### `Ctrl+Shift+0` 完全沒反應 → Windows 系統熱鍵吃掉了
登錄檔 `HKCU:\Control Panel\Input Method\Hot Keys` 的 **`00000104`**（修飾鍵 `0x06`＝Ctrl+Shift、虛擬鍵 `0x30`＝`0`）把它註冊成「直接切換輸入法」，按鍵永遠傳不到小狼毫。
同一份登錄檔的 `00000200~0203` 佔用 **Ctrl+Alt+G/K/L/V**。查法：
```powershell
Get-ChildItem 'HKCU:\Control Panel\Input Method\Hot Keys' | ForEach-Object {
  $v = Get-ItemProperty $_.PSPath
  '{0} mod={1:X2} vk={2:X2}' -f $_.PSChildName, $v.'Key Modifiers'[0], $v.'Virtual Key'[0] }
```
→ `en_sort` 已改綁 `Ctrl+Shift+F5`（F 區未被系統佔用）。

### `Ctrl+Shift+<數字>` 的「數字形式」綁定是死的
按住 Shift 時系統送出的是**符號**（`)` `!` `@` `#`…），所以 `{accept: "Control+Shift+0"}` 永遠不match，只有 `{accept: "Control+Shift+parenright"}` 會。上游把兩種都寫了，前者純屬冗餘。

### `{accept: Shift, ...}` 是無效綁定
不是合法鍵名，日誌會噴 `unrecognized key 'Shift'`。中英切換由 `ascii_composer/switch_key` 的 `Shift_L`/`Shift_R` 處理。

### Caps Lock 亮著時被強制英文、Shift 切回又彈回
小狼毫已知行為（[weasel#1736](https://github.com/rime/weasel/issues/1736)，官方標記不修）。
→ 設 `ascii_composer/good_old_caps_lock: false`，讓小狼毫接管 Caps（LED 永不亮）。

### 中文輸入莫名跳成英文且切不回來
多半是 Windows 的 **Alt+Shift／Ctrl+Shift 輸入法輪切熱鍵**誤觸，落到另一個鍵盤配置。
→ `HKCU:\Keyboard Layout\Toggle` 的 `Language Hotkey`／`Layout Hotkey`／`Hotkey` 全設為 `3`（停用）。

## 測試陷阱

### ⚠ PowerShell 單引號裡的反引號不是跳脫字元
`'``1f '` 送出的是**兩個**反引號。這曾造成「emoji 選字壞掉」的**假象**，浪費了一輪完整調查——實際上該功能一直正常，只是測到了字典裡不存在的碼。
```powershell
$g = [char]0x60      # 正確做法
"${g}1f "
```

### 候選數為 0 時，librime 預設上屏「原始編碼」
所以「打了某個碼按空白，跑出一串英數字」通常代表**該碼字典裡沒有**，不是 bug。

### glog 在沙盒不可靠
`log.info()` 常常寫不進去（`COULD NOT CREATE A LOGGINGFILE`）。lua 取證請直接寫檔：
```lua
local f = io.open(rime_api.get_user_data_dir() .. "/dbg.txt", "a")
if f then f:write("...\n") f:close() end
```

### 時間相關輸出的比對
`'/f`、`'/t` 等每秒都在變。回歸比對要嘛正規化數字，要嘛用凍結時鐘（在沙盒 `rime.lua` 注入 `os.date`/`os.time` shim）。跨午夜測試會誤判日期類項目。

## librime-lua API

### 這裡的 Lua 是 5.3，不是 5.4
`filter_gloss.lua`、`filter_cand/tran_utf8_comment.lua` 等檔案會直接改寫 for 迴圈的
控制變數（`for sense in ... do sense = sense:gsub(...)`）。這在 **5.3 合法、5.4 會編譯失敗**
（`attempt to assign to const variable`）。既然這些檔案實際上跑得起來，代表執行環境是 5.3。
→ 拿 `luac5.4` 或外部 Lua 5.4 去做語法檢查會噴這三個假警報，別當成 bug 去「修」。
反過來說，新寫的碼也不要用 5.4 才有的語法。

### 所有元件共用同一個 Lua state
忘記 `local` 的變數會**跨方案、跨元件互相覆蓋**。本專案修過 5 個檔案的此類 bug。
狀態一律存 `env.xxx`，不要用全域。

### `comp:back()` 在空 composition 上是未定義行為
先判 `comp:empty()`。原版註解自承會 segfault 但只防了「使用」沒防「取值」。

### `update_notifier` 不會在「反白移動」時觸發
只在**輸入改變**時觸發。方向鍵移動高亮**不發通知**（已實測）。
→ 想做「提示行跟著反白走」的功能：**做不到**（processor 內設 `seg.prompt` 也不會反映到前端）。詳見 [HISTORY.md](HISTORY.md#已評估但不做的項目)。

### `ReverseLookup` 建構失敗會讓整個方案掛掉
詞典還沒編譯時尤其危險，一律 `pcall` 包起來。

## 排版

### 註解太長把候選窗撐爆
Weasel 用 DirectWrite 繪製，`layout/max_width` 會**自動折行**，`align_type: top` 讓候選字與多行註解頂端對齊。
中日文字寬度是英文兩倍，截斷要用**顯示寬度**計（全形算 2）而非字元數，否則兩者視覺長度差一倍。
