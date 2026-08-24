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

## 按鍵與快捷鍵

### `Ctrl+Alt+字母` 完全沒反應 → Windows AltGr 保留組合
小狼毫**不會**把 `Ctrl+Alt+X` 轉送給輸入法（等同 AltGr）。引擎層測試會通過、實機永遠無效。
→ 方案切換改用 **`Ctrl+Shift+F1~F4`**（見 `default.custom.yaml`）。

### `Ctrl+Shift+6~0` 不能用 → 已被方案內建開關佔用
`element_bopomo.yaml` 的 key_binder 綁了字集／emoji／註釋／Unicode／英排序開關，方案層綁定優先。

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
