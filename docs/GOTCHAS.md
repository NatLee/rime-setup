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
就得排在 `selector` 之前。本專案放在 `key_binder` 之後。

### 選單只顯示第一列 → uniquifier 把候選文字相同的列合併了
`engine/filters` 末端掛著 `uniquifier`，它**以候選文字去重**。
選單類候選若把文字留空（想讓選中時不上屏任何東西），六列會被併成一列。
上游把 ①②③ 塞進候選文字就是為了閃這個，不是為了好看。
→ 本專案改成把「該列的代碼」（`'/dt`、`'/f`…）當候選文字：天然唯一，
而且看得到代碼、下次可以直接打。

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

### ⚠ 未解：鼠鬚管 1.1.2 不吃 `menu/alternative_select_labels`
Windows 端候選標籤顯示 `⇧1.`～`⇧6.`，macOS 端實測顯示的是**選字鍵本身** `!. @. #. $. %. ^.`。
已排除的可能：
- `build/bopomo_onionplus.schema.yaml` 裡 `alternative_select_labels: [⇧1…⇧6]` 確實有編進去
- `build/squirrel.yaml` 裡 `candidate_format: '[label]. [candidate] [comment]'` 也有
- Squirrel 1.1.2 是目前最新版，不是版本太舊

也就是說 librime 那邊標籤是好的，鼠鬚管前端沒拿去用（或拿的是 `select_keys`）。
未實測的驗證法：把 labels 暫時改成 `[壹,貳,參,肆,伍,陸]` 重新部署，
若畫面沒變即可確認是前端忽略，可以去 rime/squirrel 開 issue。

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
