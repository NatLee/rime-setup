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
（上游的 `processor_zhuyin_space.lua`、`processor_mix_zhs_ltk.lua` 也是同樣寫法，那邊是 9；這兩個檔因為沒有方案在用已經移除。）

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

### 指令選單的每一列「選中即執行」——沙盒裡動作一律空轉
選單列選中、或一級指令代碼按空白，會真的開檔案／開瀏覽器／跑 `scripts/rime-update.ps1`
（git pull → 部署 → 重啟服務）。以前的對策是「測試不要按下去」，靠註解提醒，結果還是出事：
主選單第一列後來換成速查表，`T19`（`'/` ＋空白）沒跟著改，**每跑一次回歸就開一次瀏覽器**。
→ 現在是結構上擋住：使用者資料夾裡有 `na_test_open.log` 這個檔時，`p_generic_open.lua` 只把
  「本來要開的東西」記進去、不執行。`rime-test.ps1` 每次都在沙盒建這個檔，而且開跑前先確認沙盒裡的
  lua 真的有這道判斷，沒有就直接停。正式的使用者資料夾不會有這個檔。
→ 所以測試可以放心按下去，再用 `Get-Opened` 比對它「本來要開什麼」（A01～A06）。
  以前這條鏈（選單列的 `run` → `p_run_pattern` 的 `open`）完全沒有測試。
→ 為什麼用檔案不用環境變數：Lua 的 `os.getenv` 讀的是 C 執行階段的快照，測試行程中途才設的變數不一定看得到。

### 新增 `'/` 功能一定要給選單入口
`'/g`（Lua 記憶體）、`'/gc`、`'/p`、`'/z`、`'/l` 曾經只能靠背代碼才找得到 ——
選單裡沒有任何一列指向它們，使用者根本不知道有這些功能存在。
→ 現在的規則：**每個功能都要能從 `'/` 一路按 ⇧鍵走到**。
新增功能時同步改 `lua/mf_components/mf_menu_data.lua`，並在 `mf_open_menu.lua`
`register_exact` 新子選單。驗收方式：`docs/KEYMAP.md` 第 5 節的每一個代碼，
都要在選單樹裡找得到（或被某一列的說明文字提到，例如 `'/x`、`'/ym`、`'/mdw`）。

### `'/` 選單為什麼每層都壓在 6 列以內
`menu/page_size` 是 6，但 `'/` 段落裡**翻頁鍵大多是壞的**：
`-` `,` `.` 都在 mf_translator 的 recognizer pattern（`'/[-+*^/.,'();0-9a-z]*$`）裡，
會被當成輸入吃掉，只剩 `=` 與 ←／→ 還能翻頁 —— 使用者不會知道。
→ 寧可多分一層子選單，也不要讓某一層超過 6 列。

### 前綴搜尋為什麼不能「一視同仁」套在所有 `'/` 代碼上
`'/gi` → `'/git` 這種補完很自然，但**直接對所有代碼開放會把既有功能吃掉**。
三道護欄各對應一個實際會壞的東西（都實測過）：

| 護欄 | 不加會壞掉什麼 |
|---|---|
| 代碼本身已有 handler 就不介入 | `'/f` 有 `fa` `fc` `fn` `fw`… 一堆更長的同字首碼，會從「出日期」變成「出選單」 |
| 只認嚴格字首，不認完全相等 | `'/ts`（時間戳）、`'/pw`（密碼）同時也是選單列的 key，相等就介入會蓋掉 devkit |
| 目標列的 key 必須是純字母 | 選單裡有 `rgb1a73e8`、`cshello.world` 這種「可跑的範例」當 key，算進來的話 `'/rgb1`、`'/csh` 會被判成字首，蓋掉 devkit 真正的輸出 |

`rime-test.ps1` 的 C01~C08 就是釘這三道護欄：C01~C03 驗補完有效，
C04~C08 驗既有功能沒被蓋。放寬判斷時這幾條會紅。

### `bare_prefix` matcher 的註冊位置：j_run 之後、mf_unicode 之前
不能排在 `mf_unicode` 後面：它的 `codes()` 對 `'/ca` 這種 `[xuco]`＋hex
會 `return true`（雖然一個候選都不吐），排後面就永遠輪不到 ——
畫面空白，但 `processor_p_run_files` 那邊的 `menu_data.lookup` 卻認得有選單，
兩邊不一致（按 ⇧1 會跳到看不見的那一列）。

### `'/cs`、`'/rgb` 空手打沒有候選，是預期的
它們是「需要參數」的指令（`'/cshello.world`、`'/rgb1a73e8`），
devkit 的樣式要求後面至少一個字元。前綴搜尋也刻意不補這兩個（見上表第三道護欄）。
入口在 `'/dev` 選單裡，那兩列直接放可以跑的範例。

### 選單列的候選文字＝「可以直接打的代碼」，別放沒有 handler 的字串
選單的約定是「看得到代碼、下次可以直接打」。把速查表攤平到主選單時一度用
`key = "h"`，畫面顯示 `'/h` —— 但 `'/h` 根本沒有註冊任何 handler，打下去零候選。
→ 改用 `key = "jh"`（j 命名空間是真的能打的），`run = "h"` 讓選中仍是直接執行。
新增選單列時自問：**這一列顯示的代碼，使用者照打會不會有東西？**
驗收：`pwsh tools\rime-test.ps1 -Mode cands -InputSeq "'/<那個代碼>"` 要有候選。

### 指令是「一級代碼」，靠 direct = true 資料驅動掛載
`p_run_pattern.lua` 裡標了 `direct = true` 的條目，會自動得到三樣東西：
translator 的提示候選（`mf_open_menu.register_direct`）、processor 的空白鍵動作
（`processor_p_run_files`）、以及被前綴搜尋列出的資格。加一條就是加一個 `'/xxx`，
不必再為它寫 handler —— `'/git` 以前就是寫死的一份，現在拿掉了。

⚠ 代碼撞到既有功能時，**整條失效**（不是部分失效）：
`register_direct` 會跳過已經被註冊的代碼（`registry.has_exact`）、只把真正掛上的
登記到 `registry.claim_direct`；processor 端只認這份名單（`registry.is_direct`）。
兩邊看同一份名單，所以不會出現「打得出提示卻不會執行」或反過來的半生不熟狀態。

實測驗證過：在 `p_run_pattern` 塞一條鍵名為 `f` 的條目（撞到日期代碼 `'/f`），
`'/f` 仍然正常出日期、完全不會變成開網頁。少了這道判斷就會被吃掉 ——
這個 processor 排在鏈首，空白鍵是它先看到的。

### `register_direct` 一定要最後註冊
`translator_multifunction_translator.lua` 的註冊順序即優先序（後蓋前）。
`register_direct` 擺在最後，`has_exact` 才看得到所有既有代碼，撞碼判斷才準。
擺前面的話它反而會蓋掉日期／內碼那些代碼。

### 沙盒同步要 `/PURGE`，否則測試會對著「已刪除的檔案」跑
`robocopy /E` 只複製、**不刪除**目的地多出來的檔案。從 repo 刪掉一個 lua 之後，
沙盒裡還留著舊的那份，測試照樣全綠 —— 正式環境一部署卻整個 lua 掛掉。
實際踩過：`p_run_menu.lua` 已刪除，`translator_multifunction_translator.lua`
卻還 `require` 它，53 條測試全 PASS。
→ `rime-test.ps1` 的 robocopy 已加 `/PURGE`（`*.userdb` 等 `/XD` 排除項不受影響）。
刪檔之後務必 `-Sync` 重跑一次。

### 停服務用 `WeaselServer.exe /quit`，不要 `Stop-Process -Force`
強殺會讓正在連線的應用程式卡在具名管線上 —— 卡的正是使用者當下在打字的視窗。
`/quit` 是官方開關，閒置時實測 100~200ms 就乾淨退出。
⚠ 但服務**正在編譯或剛啟動還在初始化**時會不理 `/quit`（實測遇過逾時）。
→ 重送幾次再考慮強殺，別一逾時就 `-Force`。`scripts/rime-update.ps1` 已這樣寫。

其他可用開關（`strings` 撈出來的）：
`WeaselServer.exe` → `/quit` `/deploy` `/dict` `/sync` `/userdir` `/weaseldir`
`WeaselDeployer.exe` → `/deploy` `/dict` `/sync` `/install` `/help`

### ⚠⚠ 部署時不可以先把服務停掉 —— 會讓所有用輸入法的程式一起沒回應
出過兩次事：使用者打 `'/git` 更新，之後 Chrome、編輯器全部被 Windows 判定無回應。
現場是 `WeaselDeployer.exe` 起來之後 **CPU 一直是 0**（log 只有 262 bytes，停在第一行），
旁邊有一個同時啟動的 `WeaselServer.exe`。兩個互等。

**原因是「先 `/quit` 停服務 → 部署 → 啟動」這個順序本身。**
服務一消失，任何開著輸入法的程式都會自動把它叫回來；叫回來的時機如果撞上部署器剛啟動
（部署器一開始會去連服務、通知它進維護模式），兩邊就鎖死。更新要重編詞典時視窗期拉長，幾乎必中。

小狼毫自己的「重新部署」不是這樣做的。部署器的流程（`Configurator::UpdateWorkspace`）是：
連上服務 → `StartMaintenance` → 編譯 → `EndMaintenance`，服務全程活著。
→ `rime-update.ps1` 現在照這個順序：**確定服務在跑而且就緒 → 部署（等部署器結束）→ lua 有變才重啟服務**。
→ 保險：部署器啟動 20 秒仍完全沒吃 CPU 就判定互鎖，腳本會結束它、把服務重新叫起來，不讓整台卡著。
→ 救援方式：工作管理員結束 `WeaselDeployer` 和 `WeaselServer`，從開始功能表按「重新部署」等它跑完。
→ 這種錯沙盒抓不到（沙盒直接呼叫 librime，不經過部署器與服務）。**改更新流程一定要對實機跑**，
  而且要跑三種：沒變動、只有 yaml 變動、`-Force`。

查這件事的過程中連帶找到三個各自獨立的錯，都是實機才看得出來：

**① `& $deployer /deploy` 不會等。** `WeaselDeployer.exe` 是視窗程式，PowerShell 的 `&` 對視窗程式
不會等待，馬上往下跑。以前註解寫「deployer 有時 0.0 秒就 exit 0，真正的重編是之後啟動的服務做的」，
那是誤判：0.0 秒是根本沒等它。→ 用 `[Diagnostics.Process]::Start(...)` 拿到行程再 `WaitForExit`。

**② Windows PowerShell 5.1 的 `Start-Process -ArgumentList '/quit'` 會讓 `/quit` 失效。**
5.1 組出來的命令列結尾多一個空白（`"…WeaselServer.exe" /quit␠`）。小狼毫是整串比對，認不出這是
`/quit`，就把它當成「啟動一個新的服務」—— 新的把舊的擠掉、自己留下來。從外面看就是「送了 /quit
但 WeaselServer 還在」，重送幾次都一樣，最後落到強殺。pwsh 7 沒有這個問題，所以只在 5.1 測才會發現。
→ 參數一律用 `[Diagnostics.Process]::Start($exe, '/quit')` 給。
→ 順帶知道的事：**再啟動一個 `WeaselServer.exe` 不會被擋掉，而是取代舊的。**

**③ 部署器剛結束時服務正在重新載入設定，這時送 `/quit` 它不理。**
→ 等它的 CPU 時間連續 1.5 秒不再增加再送，就是 0.1 秒的事。

### 部署會讓 IME 暫時不能用 —— 那是維護模式，不是卡死
部署器通知服務進維護模式的那段時間，輸入法不出字，但**其他程式不會被拖住**。
以前為了避開這段「有輸入法但沒反應」而改成先停服務，結果換來更糟的整台卡死（見上一條）。
兩害相權取其輕：就讓它進維護模式。

### 套用檔案要比內容，不能只比修改時間
`rime-apply` 原本用「大小＋修改時間」判斷檔案有沒有變。換一份 clone 來套用、或 git 重新簽出時，
內容沒變但修改時間全都不同 → 一百多個檔全部重新複製 → RIME 整輪重新編譯（實測 170 秒）。
→ 大小相同、時間不同時再比 SHA256，內容一樣就不動。全部比一輪不到 2 秒。

### 更新流程：沒變更就別動輸入法
以前不管 `git pull` 有沒有拉到東西，都照樣部署＋重啟 —— 光是「確認一下有沒有
更新」就要付十幾秒的 IME 中斷。現在以「套用時實際有沒有檔案被改到」分流（`rime-apply.ps1` 的回傳值）：

| 套用時變動的檔 | 動作 | 實測（小狼毫 0.17.4） |
|---|---|---|
| 沒有 | 什麼都不做 | 整支腳本 0.5 秒，IME 完全不中斷 |
| 只有 `.lua` | 只重啟服務（lua 只在服務啟動時載入） | （沒有單獨量過） |
| 有 yaml／詞典／txt／gram／opencc | 部署，服務保持運作；lua 也有變才另外重啟 | 只動候選窗設定：部署 1.0 秒、整支 1.7 秒；動到全域設定（每個方案都要重編）：部署 11.5 秒 |
| `-Force` | 部署＋重啟 | 沒有東西要重編時整支 7.6 秒（部署 0.9 秒，其餘是等服務停、啟） |

macOS 版（`rime-update.command`）同樣的分流，但沒有「先停服務」那段：
鼠鬚管沒有獨立部署器，`Squirrel --reload` 一個動作就同時重編與重載 lua。

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
`squirrel.custom.yaml` 已改寫完成。⚠ Windows 的 `na_weasel.yaml` 目前仍是巢狀寫法，
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
所以 `git clone` 出來的是空的。安裝腳本（`install.sh`／`install.ps1`）已會從備份目錄把
`*.userdb`、`sync/`、`installation.yaml`、`user.yaml`、個人短語檔搬回來，
手動重裝時**別忘了這一步**，否則等於重新學一次你的用字習慣。

### 安裝腳本一律用 HTTPS clone（repo 是公開的）
公開 repo 用 `https://github.com/NatLee/rime-setup.git` 匿名就能拉，不需要 SSH key。
維護者自己的機器 remote 是 SSH（要 push）沒關係：安裝腳本判斷「是不是已經裝過」時
只比 remote 的最後兩段（`owner/repo`），HTTPS 與 SSH 會被視為同一個 repo。
（歷史：repo 還是 private 時 HTTPS 會卡在帳密輸入，
`could not read Username for 'https://github.com'`，當時才一律走 SSH。）

## 方案切換

### 方案名稱：選單對了，「輸入法設定」對話框還是舊名
`*.custom.yaml` 的 `"schema/name"` 只影響部署後的結果（F4／Ctrl+` 的方案選單）。
小狼毫工作列圖示 →「輸入法設定」那個勾選方案的對話框，讀的是 `*.schema.yaml` 的**原始** `name`。
→ 方案名稱直接改 schema.yaml，兩邊才會一致。

### 載入注音主方案比其他方案慢很多 —— 時間花在哪
實機 log 量到的：主方案每次載入 110～315 ms（日文 20～30、韓文 10～17、英文 5）。
打字時感覺不到（每鍵 2～5 ms），但「切回注音」的那一下有感，用右 Shift 循環時每繞一圈遇到一次，
每開一個新視窗第一次用輸入法也是一次。沙盒可重現：`pwsh tools\rime-test.ps1 -Mode load`，原本約 120 ms。

把元件一組一組拿掉量出來的分佈，以及處理方式：
- **字集過濾的 OpenCC 字典約 30 ms** → 已改成二進位。`rime/opencc/*.txt` 是文字格式，
  每次載入都整份重新解析（最大的五萬五千行）。現在 `*.json` 指向 `.ocd2`，載入幾乎不花時間。
  ⚠ 所以**改了 `.txt` 一定要重編**：`pwsh tools\opencc-build.ps1`（用 Docker 跑官方的 `opencc_dict`；
  小狼毫沒附這個工具）。沒重編的話輸入法看到的還是舊內容。`-Check` 可以檢查有沒有過期。
- **九個前綴語言各開一個使用者詞庫約 35 ms** → 拉丁、希臘、俄文、全形、倉頡反查這五個少用的
  已關掉（`bopomo_onionplus.custom.yaml` 的 `…/enable_user_dict: false`），日文、韓文、emoji 保留。
  代價：那五種前綴語言不再記詞頻。
- 其餘約 60 ms 是九個前綴語言的詞典、主詞典、語言模型本身，沒有便宜的省法。
  （試過：拿掉語言模型、拿掉全部 lua filter／translator，各自都只差 2～5 ms。）

處理後沙盒量到約 60 ms。快照 1819 行逐字相同（字典內容沒變，只是換格式）。

### `select: .next` 不是「循環」，只會在兩個方案之間來回
key_binder 的 `select: .next` 選的是方案選單的第 2 項，而選單永遠把「目前的方案」排第 1，
所以 A→B 之後再按一次是 B→A，到不了 C。想要「按一下換下一個語言」要自己算下一個：
`lua/processor_schema_cycle.lua` 讀 `build/default.yaml` 的 `schema_list`，
用 `env.engine:apply_schema(Schema(id))` 切過去。

### 單按修飾鍵只能用 lua 接
key_binder 綁不了「單按右 Shift」；`ascii_composer/switch_key` 認得單按 Shift 但只能切中英。
`schema_cycle` 的判定：右 Shift 按下記一筆 → 中間按了別的鍵就取消 → 放開時那筆還在才算單按。
`switch_key` 的 `Shift_R` 要設 `noop`，否則同一下會順便切中英。

### `apply_schema` 之後不可以再碰 `env`
它會把整條 processor 鏈換掉，包含正在執行的那個 lua 元件。呼叫後直接 `return 1`（kAccepted）。
另外切過去之後是**新方案自己的** processor 鏈接手，所以 `schema_cycle` 要掛在每一個選單方案上，
漏掛的方案「切得進去、切不出來」。回歸：`pwsh tools\rime-test.ps1 -Mode cycle`。

### lua 不是打字延遲的來源
沙盒實測（`-Mode bench`，逐鍵送 35 鍵長句、每鍵取回第一頁候選）：每鍵 2.5～3.5 ms，
量測本身的抖動就有 1 ms。把 6 個 lua filter 全部拿掉、或把 lua processor 全部拿掉，都落在同一個範圍。
→ 不要為了效能去改寫 filter。真正有感的是啟動與部署：`rime.lua` 少掛沒人用的元件、少放沒人用的詞典。

### 重構 lua 之前先存快照
`pwsh tools\rime-test.ps1 -Sync -Mode snapshot > before.txt` 會把九十幾組輸入的「全部候選＋註解」
和二十幾組按鍵序列的上屏結果倒出來（一千三百多行，兩次執行逐字相同）。改完再跑一次 diff。
基本回歸只看每組的第一個結果，重構時不夠 —— 例如字母樣式有二十幾種，回歸只會看到第一種。
會隨時間變的輸出（日期、uuid、隨機密碼）和會真的執行動作的序列（`'/h` 空白）不可以放進快照清單。

### `'/j<代碼>` 已經退役，行為跟其他未知代碼一樣
舊版的指令命名空間（`'/jh`、`'/jgit`）拿掉之後，`mix_apc_s2rm_ltk` 裡還留著它的開檔分支
（`'/jh` 按空白其實仍會開速查表、打錯的 `'/jxx` 按空白會清空）。那段已移除：
現在 `'/j…` 按空白就是一般的「沒有候選 → 上屏原始編碼」。

## 主題與小狼毫自己的設定對話框

### 字型：粉圓體不放進 repo，名稱要用「電腦上實際裝的那個」
- jf open 粉圓的家族名稱**帶版本號**（`jf open 粉圓 2.1`），裝的是 2.0 名字就不一樣。
  所以 Windows 的安裝腳本先列出已安裝的字型、用實際找到的名稱；沒裝才從官方發佈頁下載 2.1。
- 裝在使用者自己的字型資料夾（Windows：`%LOCALAPPDATA%\Microsoft\Windows\Fonts` ＋ HKCU 登錄檔；
  macOS：`~/Library/Fonts`），不需要管理員權限。Windows 裝完要 `AddFontResource` ＋廣播
  `WM_FONTCHANGE`，這次登入階段才馬上認得。
- 粉圓體只有一種字重，**不要加 `:bold`**（合成粗體會糊）。後面接正黑體／蘋方當後備字型。
- 鼠鬚管認字型：`名稱-樣式`（如 `PingFangTC-Semibold`）或 PostScript 名稱。粉圓要寫 `jf-openhuninn-2.1`。
- `na_style.yaml` 的預設值刻意留系統字型：手動安裝、或粉圓下載失敗的人不會拿到一個不存在的字型。
  下載失敗時安裝腳本自動退回系統字型，不中斷安裝。
- PowerShell 5.1 的 `Invoke-WebRequest` 不關進度條會慢十倍，下載前要設 `$ProgressPreference = 'SilentlyContinue'`。

### 候選窗樣式：哪些是小狼毫真的支援的
下面這些都對過小狼毫 0.17.4 的原始碼（`RimeWithWeasel.cpp` 的 `_UpdateUIStyle`、`WeaselPanel.cpp`），
不是照網路上的範例抄的。寫了不認得的鍵不會報錯，只是沒效果，很難發現。
- **高亮列左側的圓角色條**：`style/mark_text` 留空，而且配色有 `hilited_mark_color` 才會畫。
  `mark_text` 填了字就改成畫那個字。
- **翻頁箭頭 `<` `>`**（編碼列右側，可點）：配色**同時**有 `prevpage_color` 和 `nextpage_color` 才出現，
  而且只在 `inline_preedit: false` 時畫。不能翻的那個方向用一般文字色。
- `style/hover_type` 只認 `none`／`semi_hilite`／`hilite`；`style/layout/align_type` 只認 `top`／`center`／`bottom`。
- `margin_y` 會被自動撐到至少等於 `hilite_padding_y`，設小了沒用。
- 光棒圓角是 `layout/round_corner`，視窗圓角是 `layout/corner_radius`，兩個名字很像、別寫反。
- 新增一個會出現在配色裡的顏色鍵，九套主題都要補；`tools/theme-preview.ps1` 畫圖時用的排版數字
  是寫死在腳本裡對應 `layout` 的，改了排版記得一起改，再重產預覽圖。
- 鼠鬚管的排版鍵另成一套（對過 `SquirrelTheme.swift`）。對照：
  | 想要的效果 | 小狼毫 | 鼠鬚管 |
  |---|---|---|
  | 標籤不加句點 | `label_format: "%s"` | `candidate_format: "[label] [candidate] [comment]"` |
  | 視窗圓角／光棒圓角 | `layout/corner_radius`／`layout/round_corner` | `corner_radius`／`hilited_corner_radius` |
  | 視窗最小寬度 | `layout/min_width`（設 0＝跟著內容走） | 沒有，本來就跟著內容走 |
  | 視窗內距 | `layout/margin_x`、`margin_y` | 沒有獨立的鍵：＝`border_width`／`border_height` ＋ `corner_radius` |
  | 邊框粗細 | `layout/border_width` | `border_width` 與 `border_height` 取小的 |
  | 候選列距與光棒內距 | `candidate_spacing`、`hilite_padding_*` | `line_spacing` 一個值兼任兩者 |
  | 編碼列與候選的間距 | `layout/spacing` | `spacing` |
  | 翻頁箭頭 | 配色的 `prevpage_color`＋`nextpage_color` | `show_paging: true`（畫在左緣，是三角形） |
  | 註釋字重 | `comment_font_face` | `comment_font_face` |
  | 高亮列的色條 | `mark_text: ""`＋`hilited_mark_color` | **沒有** |
  | 視窗陰影 | `layout/shadow_radius` | **沒有**（`shadow_size` 是光棒底下的陰影，不是同一件事） |
- 鼠鬚管這份排版是照原始碼的算法換算的，沒有在 Mac 上實際看過，上機後可能要微調數值。

### 小狼毫設定對話框與 `*.custom.yaml`：那兩個檔是使用者的，repo 不可以放東西進去
工作列圖示右鍵 →「輸入法設定」會連開兩個對話框，按確定就**把整個檔重寫**（註解全掉、鍵重新排序、
多一段 `customization:`），然後自己部署一次。對過小狼毫 0.17.4 的原始碼（`Configurator.cpp`、
`UIStyleSettings.cpp`）與 librime 的 `custom_settings.cc`：

| 對話框 | 寫哪個檔 | 寫什麼 |
|---|---|---|
| 方案選單設定 | `default.custom.yaml` | `patch/schema_list`（勾選的方案） |
| 介面風格設定 | `weasel.custom.yaml` | `patch/"style/color_scheme"`（**只有這一格，深色那格它不碰**） |

這套設定以前把自己的內容也放在這兩個檔（從 repo 複製過去），於是「在對話框選了、下次更新就不見」。
修過一輪：套用前記下對話框選的配色、蓋完補回檔尾、再比 `na_style.custom.yaml` 和它誰的檔案時間新。
那個做法只顧得到配色（方案清單照樣被蓋掉）、靠檔案時間猜先後很脆弱，`'/setup` 還得「就算沒變也重寫一次
選項檔」來贏過時間比較。

**現在的做法：誰寫的檔歸誰。**
- repo 的內容搬到 `na_weasel.yaml`／`na_default.yaml`（一樣是 `patch:` 開頭）。
- 使用者資料夾的 `weasel.custom.yaml`／`default.custom.yaml` 只有一行把它接進來：
  ```yaml
  patch:
    __include: na_weasel:/patch
  ```
  `rime-apply` 只在「沒有這個檔」或「還是舊版面的檔」時建立它，之後**永遠不覆蓋**，也不在安裝清單上。
  （判斷方式：檔裡找不到接上 `na_weasel:/patch` 的那一行就當成舊版面。換掉之前原檔留一份 `.bak`，
  萬一那其實是使用者自己把 `__include` 拿掉的檔，他寫的東西還找得回來。）
  `rime/` 裡如果又出現這兩個檔名，`rime-apply` 會直接報錯。
- librime 的規則：`__include` 旁邊的其他鍵會合併進被引入的內容、蓋過同名的值。對話框寫的
  `"style/color_scheme"`／`schema_list` 就落在那裡，所以它直接生效、更新也碰不到。
  這是社群既有的寫法（easy_en 的安裝說明就是 `patch:` 底下寫 `__include: easy_en:/patch`）。
- 使用者想自己加設定也寫在那一行底下，同樣不會被更新蓋掉。

**`'/setup` 跟對話框誰贏：最後動手的那個。** 不比檔案時間，由安裝腳本直接處理那一行：
- 對話框選的配色是這套的主題 → 選項畫面把它顯示成目前的主題；套用時記進 `na_style.custom.yaml`，
  並把 `weasel.custom.yaml` 裡那一行拿掉。之後再用對話框選，又會多出那一行、蓋過選項檔。
- 對話框選的是別的配色（使用者自己加的）、或自己勾了方案清單 → 選項畫面照實顯示「自訂…」，
  **沒在這裡重選那一項就不動它**；重選了才拿掉。
- 只刪那一個鍵，檔案其他內容原樣留著。

驗證：`pwsh tools\rime-test.ps1 -Mode gui`。它用對話框呼叫的同一組 API（librime 的 levers）寫檔，
所以產生的檔跟真的按對話框一模一樣；再套用、跑安裝腳本、編譯，逐步比對結果（33 條）。
改到 `rime-apply`、安裝腳本的選項段、或這兩個檔的配置，都要跑這個模式。

### 在對話框換了配色卻沒變 → 系統在深色模式，而且「跟隨系統」開著
小狼毫先套 `style/color_scheme`，系統在深色模式時再看 `style/color_scheme_dark`
**讀不讀得到字串**，讀得到就蓋過去（`RimeWithWeasel.cpp`）。對話框只改得到前者。
- 「系統深色模式：跟隨」時，深色模式固定顯示 Nat Dark。這時在對話框或 `'/setup` 換主題，改到的都是
  淺色模式那一格，畫面不會變 —— **這是設定的本意，不是壞掉**，但看起來一模一樣。
  → 選項畫面在這個狀態下會多印兩行提示（系統現在是深色、想在深色模式也用這個主題就把第 2 項改成「不跟隨」）。
- 「不跟隨」寫成 `theme_dark: ~`（空值），搭配選用式的 `{ __include: "na_style:/theme_dark?" }`：
  值是空的時候那個鍵解析成空節點，`config_get_string` 回 false，小狼毫就退回 `color_scheme`。
  ⚠ 不可以寫成跟 `theme` 同名：那會把深色模式釘死在那個主題，對話框怎麼換都沒反應（舊版安裝腳本
  就是這樣寫的，`rime-apply` 會把舊檔自動改過來）。

### ⚠ 設定「一直被重置」→ 同一台電腦有兩份版本不同的 clone 在輪流套用
維護者的電腦通常有兩份：安裝指令放的 `~/.na-plus`，和開發用的那份。**誰最後套用，使用者資料夾裡的
啟動器（`na-setup.cmd`、`na-update.cmd`）就指向誰**，所以 `'/setup`、`'/git` 跑的是哪一份會跟著換。
兩份版本一樣時沒事；開發那份改了個人檔的格式（例如選項檔從一個拆成三個）而 `~/.na-plus` 還是舊的，
就會這樣：新版套用 → 舊的選項檔被收掉；之後不管什麼原因跑到舊版的安裝腳本，它找不到自己認得的選項檔，
**直接寫回預設值**，還把新版的檔當成「repo 已刪除」清掉。從使用者看就是「改了又被改回去」，
而且兩邊都沒有任何錯誤訊息（真的發生過，查了很久才想到要看 `na-setup.cmd` 指向哪裡）。
→ `rime-apply` 有「版面編號」（`.ps1` 的 `$Layout`、`.sh` 的 `LAYOUT`，記在 `na_manifest.txt` 檔頭的
  `# na-layout:`）。目標資料夾的編號比這份 repo 大就拒絕套用，並說明原因。
→ **個人檔的名字、格式、或「哪個檔歸使用者」一改，兩支腳本的版面編號就要一起加 1。**
→ 沙盒測試傳 `-AllowDowngrade`（沙盒本來就會被不同分支輪流套用）。
→ 開發到一半要確認現在是誰在管：看使用者資料夾的 `na-setup.cmd` 最後一行指向哪個資料夾。

## 安裝腳本與安裝選項

### 安裝選項放在 `na_style`／`na_input`／`na_menu` 三個檔，不要寫死在 `*.custom.yaml`
主題、深色模式、直／橫排、字級、字型、emoji 預設、釋義語言、方案清單是「每個人裝的時候自己選」的東西。
作法：

- `rime/core/na_style.yaml`、`na_input.yaml`、`na_menu.yaml`（repo 裡）放**預設值**。
- 用到它的檔（`na_weasel.yaml`、`squirrel.custom.yaml`、`na_default.yaml`、方案的 `*.custom.yaml`）
  在需要的位置寫 `{ __include: "na_style:/<鍵>" }` 取值。
- 個人選擇寫在對應的 `na_*.custom.yaml`（**不進版控**，安裝腳本產生）——
  librime 對「被 include 的檔」也會自動套 `<檔名>.custom.yaml` 的 patch，
  跟 `default.yaml ← default.custom.yaml` 是同一套機制（`build/*.yaml` 的
  `__build_info/timestamps` 會列出 `na_style` 與 `na_style.custom`，改了會觸發重編）。

**為什麼是三個檔而不是一個**：RIME 記下每個設定檔讀過哪些檔，任何一個的時間變了就整個重編；
方案檔重編還會連帶重建詞典索引（英文那個索引 46 MB，一個就要三秒）。誰讀哪個檔：

| 檔 | 內容 | 被誰讀 | 改了之後重編什麼 | 實測 |
|---|---|---|---|---|
| `na_style` | 主題、字型、字級、排列 | `weasel`／`squirrel` | 只有候選窗設定 | 1.6 秒 |
| `na_input` | emoji、釋義語言 | 注音、日文兩個方案 | 這兩個方案＋它們的索引 | 1.8 秒 |
| `na_menu` | 方案清單 | `default` → **每個方案** | 全部 | 6～12 秒 |

以前全放在一個 `na_options.yaml`，方案清單也在裡面，所以每個方案都讀它 —— 換個主題等於全部重編。
新增選項時**放進對的檔**：只影響長相的放 `na_style`，千萬別放 `na_menu`。
`rime-apply` 看到舊的 `na_options.custom.yaml` 會照鍵名拆成三個檔（舊檔改名 `.bak`）。

安裝腳本**只重寫內容有變的檔**（沒變卻重寫＝時間變了＝白白重編），而且不再一律 `-Force`：
選項有變加 `-Deploy`（部署、不重啟服務），沒變就什麼都不加，`rime-update` 發現沒事可做直接結束。
實測（臨時資料夾、不部署）：`'/setup` 從啟動到列出選單 0.2 秒；直接按 Enter 到結束 0.8 秒。
以前「進來看一眼就要等十幾秒」是因為一律 `-Force`（整輪部署＋重啟服務）。

為什麼選項不寫進 `weasel.custom.yaml`／`default.custom.yaml`：那兩個檔留給使用者和小狼毫的設定對話框
（見「小狼毫設定對話框與 `*.custom.yaml`」）。選項有自己的三個檔，安裝腳本整個檔重寫也不會動到別人的東西。

新增一個選項要動四處：對應的 `na_*.yaml`（預設值）、用到它的檔（`__include`）、
`install.ps1` 與 `install.sh`（詢問＋寫檔，兩支要同步）。

`scripts\rime-setup.cmd`（`'/setup` 開的就是它）成功時視窗 2 秒後自己關，失敗才停下來等按鍵：
安裝腳本走到最後會設 `$global:NaSetupOk`，沒設到就代表中途出錯。

### ⚠ 什麼都沒改，部署卻每次重編一堆方案 → 內建設定檔的時間是「整秒」
**症狀**：連續按兩次「重新部署」，中間什麼都沒動，`build/` 裡還是有十幾個 `*.schema.yaml`、
好幾個 `*.prism.bin` 被重寫，要等 1～10 秒不等（看這次輪到哪幾個方案）。`'/setup` 慢就是這個。
**原因**：RIME 靠編譯時記下的檔案時間（`__build_info/timestamps`）判斷要不要重編。小狼毫安裝目錄的
`default.yaml`、`key_bindings.yaml`、`punctuation.yaml` 修改時間剛好是整秒（安裝程式寫的），
而 librime 把檔案時間換算成秒數時有極小的誤差，整秒的檔會**有時算成 N、有時算成 N−1**。
實測同一次部署：17 個編譯結果裡 3 個把 `default` 記成 …323、14 個記成 …324，檔案實際是 …324.0000000。
下一次部署兩邊再各擲一次骰子，對不上的就被當成「內建設定變了」而重編；重編後 `__build_info`
的內容不同 → 方案檔的 checksum 不同 → 詞典索引跟著重建。
**解法**：`rime-apply.ps1` 在使用者資料夾放這三個檔的副本，時間設成「原檔＋半秒」。RIME 優先讀
使用者資料夾的，帶小數的時間怎麼算都是同一個值。

| 沒有任何變動，連續部署 | 重寫的檔 | 時間 |
|---|---|---|
| 修正前 | 16～26 個（其中索引 4～11 個） | 1.3～10.6 秒 |
| 修正後 | 0 個 | 0.9 秒 |

- 副本跟著原檔走：小狼毫升級後內容不同，下次套用會重新複製。`default.yaml` 另有 librime 自己的保護
  （使用者資料夾的版本比內建的舊就會被它移到 `trash/`）。
- 只管「內容跟上次複製的一樣」的檔（雜湊記在 `na_shared_copy.txt`）；使用者自己放、自己改過的不碰。
- 只在目標是小狼毫正在用的資料夾時才做（沙盒與測試不受影響；測試可用 `-SharedData` 指定來源）。
- `weasel.yaml` 也有同樣的現象，但它重編不牽動詞典、幾乎不花時間，所以沒放副本。
- **macOS 沒有做也沒有驗證**：鼠鬚管的內建檔在 app 裡面，是否有同樣的問題要在 Mac 上連續部署兩次、
  看 `build/` 的檔案時間才知道。
- 查這類問題的方法：部署前 `touch` 一個標記檔，部署後列出 `build/` 裡比它新的檔；
  再比對各 `build/*.yaml` 的 `__build_info/timestamps` 跟實際檔案時間（要看到小數）。
- 誤差的來源（librime `common.h` 的 `to_time_t`）：它用「檔案時間 − 檔案時鐘的現在 ＋ 系統時鐘的現在」換算，
  兩個「現在」是先後取的，差那一點點就決定整秒的檔被捨去成 N 還是 N−1。

### `install.ps1` 不能有 BOM，其他 `.ps1` 一定要有
- **`irm` 不會去掉 BOM**。腳本開頭多一個 U+FEFF，第一行會變成「找不到指令」，
  而且 `param(...)` 區塊失效——參數被**悄悄忽略**（實測 5.1 與 7 都一樣；
  測試時 `-NoDeploy` 因此沒生效，真的跑了一次部署）。→ `install.ps1` 存成 UTF-8 無 BOM。
- **Windows PowerShell 5.1 讀「沒有 BOM」的檔會當成 ANSI**，中文變亂碼甚至語法錯。
  → 會從磁碟被執行的 `scripts\*.ps1`、`tools\*.ps1` 一律 UTF-8 **含** BOM。
- 兩條規則衝突在 `install.ps1` 身上：本機要重跑它得走 `scripts\rime-setup.cmd`（使用者資料夾裡的 `na-setup.cmd` 會轉過來）
  （明確用 UTF-8 讀進來再當 script block 執行），不要 `powershell -File install.ps1`。

### 一般人的 Windows 只有 PowerShell 5.1，沒有 `pwsh`
腳本不能用三元運算子、`??`、`&&`；輸入法呼叫腳本要經過 `.cmd` 啟動器
（`rime-update.cmd` 會挑 `pwsh` 或 `powershell`），不能寫死 `pwsh`。
預設執行政策也不准直接跑 `.ps1` 檔，所以啟動器都帶 `-ExecutionPolicy Bypass`，
安裝腳本呼叫 `rime-update.ps1` 時也是另開行程帶這個參數，不是用 `&` 直接呼叫。

### `start "" "x.cmd"` 開出來的視窗不會自己關
`start` 執行批次檔是用 `cmd /K`（跑完留在提示字元）。→ 輸入法開批次檔時明寫
`start "" cmd /c ""路徑""`（`p_generic_open.lua`），跑完就關；直接雙擊或手動 `start` 的情況
則靠 `rime-update.cmd`／`rime-setup.cmd` 最後一行的 `exit`。失敗時 `.ps1` 自己已經停下來等 Enter，不會漏看訊息。
路徑包兩層引號是因為 `cmd /c` 會剝掉頭尾那一對；斜線要換成反斜線，否則 `cmd` 把 `/` 當選項。

### ⚠ Windows 上從 lua 開東西不可以用 `os.execute` —— 輸入法會卡住五秒
**症狀**：打 `'/setup` 按下去，要等五、六秒終端機才出現；這段時間輸入法完全沒反應。
`'/git`、`'/h`、`'/phrase` 也一樣（只是開瀏覽器或編輯器時比較不容易察覺是誰在慢）。
**量到的**（選項畫面印出來的分段時間，實機）：

| | 從按下到選單 | 輸入法卡在啟動指令 | 批次檔開始跑 | 腳本到選單 |
|---|---|---|---|---|
| `os.execute` | 5.7 秒 | 5.3 秒 | +5.3 秒 | 0.4 秒 |
| `io.popen` | 0.8 秒 | 0.0 秒 | +0.4 秒 | 0.4 秒 |

**原因**：`os.execute` 是 C 的 `system()`，起一個 `cmd /c <指令>` 之後**等它結束**才返回。輸入法服務沒有主控台，
系統得先替那個 `cmd` 開主控台視窗。同一條指令從別的行程呼叫 `system()` 只要 0.12 秒，換成輸入法服務來呼叫就是 5 秒，
所以推測是互等：服務卡在 `system()` 不回應 → 新視窗一出現要連輸入法（它也是輸入法的用戶端）→ 連不上 →
主控台起不來 → `cmd` 不結束，直到某個五秒的逾時放行。（互等的細節是推測；兩組數字是量到的。）
**解法**：`io.popen` 建立行程後立刻返回（8～10 ms），不等它結束。回傳的 handle **不可以馬上 `close`**
（`close` 會等行程結束，等於又卡回去），留到下一次呼叫再關。全部收在 `p_generic_open.lua`，
**要從 lua 開檔案／程式／網址一律呼叫它，不要自己寫 `os.execute`。**

查這個問題繞過的路，別再走一次：
- **從外面模擬不出來**。寫一個沒有主控台的小程式去呼叫 `system()`，整條路只要一秒 —— 因為卡住的條件是
  「呼叫的人就是輸入法服務」。這類問題要讓它在真實路徑上自己量：lua 啟動前留時間戳（`na_launch.stamp`／`.ret`），
  `rime-setup.cmd` 記下批次檔開始的時刻，`install.ps1` 算出分段。平常不顯示，超過 2 秒才印在選單標題旁並寫進
  `na_launch.log`；想每次都看就設 `NA_LAUNCH_TIMING=1`。
- 模擬時要用 `ucrtbase.dll` 的 `_popen`（跟 rime.dll 裡的 lua 同一套）。`msvcrt.dll` 的 `_popen` 在視窗程式裡會卡死，量不出東西。
- **`start /b` 沿用同一個主控台來少開一個視窗，行不通**：popen 會把子行程的標準輸出接到管線上，沿用主控台的話
  批次檔的輸出就跟著進管線，畫面空白；用 `>CONOUT$` 接回去，PowerShell 仍判定輸出被重導向（顏色與編碼都會變）。
  所以現在的寫法會先閃一個過渡的主控台視窗，再開真正的那個——這是 `system()`／`popen` 一定要先起 `cmd` 的代價。
- `where pwsh` 每次要起一個行程（約 60 ms）。啟動器改用 `for %%I in (pwsh.exe) do … %%~$PATH:I` 直接查 PATH。

### PowerShell：只有一個元素的「陣列的陣列」會被攤平
`@( @('jpnin1', '日文') )` 得到的是兩個字串，不是「一個含兩元素的陣列」，
迴圈裡取 `[0]` 會拿到單一字元（方案 id 變成 `j`）。→ 前面加逗號：`@( , @(…) )`。
另外自訂函式別取名 `Git`（會遮住 `git.exe` 造成無窮遞迴）或 `R`（是 `Invoke-History` 的別名）。

### repo 不是使用者資料夾 —— 改了 repo 要「套用」才會生效
repo 的 `rime/` 按功能分類，RIME 卻只認使用者資料夾根目錄的方案檔，所以兩者是分開的：
`scripts/rime-apply.*` 把 `rime/<分類>/*` 攤平複製過去（`lua/`、`opencc/` 保留資料夾）。
- 改完 repo 沒效果 → 還沒套用。跑 `pwsh scripts\rime-update.ps1 -SkipPull`（Mac：`bash scripts/rime-update.command --skip-pull`）。
- 直接改使用者資料夾裡的副本 → 下次更新被蓋掉（`'/cmd` 開到的就是副本）。個人化只能放在
  「使用者的檔」：`na_*.custom.yaml`（選項）、`weasel.custom.yaml`／`default.custom.yaml`
  （`__include` 那一行底下可以自己加鍵）、個人短語檔。
- 兩個分類放了同名檔 → 攤平後會撞，`rime-apply` 會報錯拒絕。
- repo 刪掉的檔，套用時會依使用者資料夾的 `na_manifest.txt` 清掉；清單以外的檔一律不動。
- 套用只複製「大小或修改時間不同」的檔（Mac 版比內容）。所以沒有變更時 `'/git` 不會觸發部署。
- 輸入法怎麼找到 repo：套用時在使用者資料夾產生 `na-update.cmd`／`na-update.command`，
  裡面記著 repo 的位置，`'/git` 開的是它。批次檔用 OEM 字碼頁讀，路徑含中文會壞，
  所以盡量寫成 `%USERPROFILE%\…`，避不掉才 `chcp 65001`。

### 舊版安裝（使用者資料夾本身是 git clone）要遷移
早期這個 repo 就是使用者資料夾。改成分類結構後，舊機器不能再 `git pull`
（一拉檔案全搬進 `rime/` 子資料夾，輸入法整個壞掉）。防護有三層：
歷史重寫過，舊 clone 的 `pull --ff-only` 本來就會失敗；`rime-apply` 看到目標有 `.git` 會拒絕；
安裝腳本看到「有東西但沒有 `na_manifest.txt`」就整個備份搬走，再還原詞頻與個人檔。
→ 舊機器的遷移方式就是**重跑安裝指令**。

### 個人短語檔不進版控
`bopomo_onionplus_phrase.txt` 裡是信箱之類的個人資料，只存在使用者資料夾；
repo 裡只有範本 `bopomo_onionplus_phrase.sample.txt`，套用腳本在檔案不存在時複製一份。
lua 讀不到檔會安靜略過（`translator_lua_custom_phrase.lua`），不會壞，但 `'/phrase` 會開不到東西。

### os.execute 在 Mac 的回傳值不能拿來判斷成敗
`start` 在 macOS 不存在，但 Lua 5.1／LuaJIT 的 `os.execute` 回傳的是 **exit code**，
127 在 Lua 裡是真值 → 「開啟失敗」會被當成成功，後面的 `open` 永遠輪不到。
→ `p_generic_open.lua` 已改成先用 `f_get_os_name` 判斷系統再挑指令。

## 按鍵與快捷鍵

### `Ctrl+Alt+字母` 完全沒反應 → Windows AltGr 保留組合
小狼毫**不會**把 `Ctrl+Alt+X` 轉送給輸入法（等同 AltGr）。引擎層測試會通過、實機永遠無效。
→ 方案切換改用 **`Ctrl+Shift+F1~F4`**（見 `na_default.yaml`）。

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

### ⚠ 沙盒裡「重新編譯設定檔」安靜地什麼都沒做 → 部署模組沒載入
`RimeInitialize` 只載入打字用的模組；`RimeDeployConfigFile`（編譯單一設定檔）需要的部署模組（levers）
要 `RimeDeployerInitialize` 或跑過一次維護（`RimeStartMaintenance`）才會載入。沒載入時它**回 false、
不報錯、什麼都不編**，接著讀到的全是上一次留下的編譯結果 —— 而預設值剛好等於預期值的檢查還會顯示 PASS。
寫 `-Mode gui` 時被它騙過一輪。→ 那個模式開頭先呼叫 `RimeDeployerInitialize`，編譯回 false 就直接丟例外。

### librime 判斷「要不要重編」只比到秒
`__build_info/timestamps` 記的是整數秒。測試在同一秒內「改檔 → 編譯 → 再改檔 → 再編譯」，
第二次會被當成沒變。真實操作不會一秒內改兩次，所以只有測試會遇到。
→ `-Mode gui` 每次編譯前把相關檔案的時間往後推 2 秒。

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
