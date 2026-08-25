<#
.SYNOPSIS
  掃出「哪個鍵／哪個代碼被誰用掉了」，產生 docs/KEYMAP.md。

.DESCRIPTION
  資料來源刻意分兩種，因為它們回答的問題不同：

    build/*.yaml   ← 部署後的**合併結果**（patch、__include 都算進去了）
                     回答「實際生效的是什麼」。手寫文件最容易在這裡過期。
    lua/**.lua     ← 代碼註冊表（register_exact／specs／devkit 的 string.match）
                     回答「'/ 底下哪些代碼被佔用」。

  所以這支腳本不是「產生文件」，是「把現況倒出來」。改完設定重新跑一次，
  文件就跟著更新，不必再人工調查一輪。

.EXAMPLE
  pwsh tools\keymap-dump.ps1                # 寫入 docs\KEYMAP.md
  pwsh tools\keymap-dump.ps1 -Stdout        # 只印出來看

.NOTES
  ⚠ 讀的是 build\，所以要先部署過。build\ 過期的話產出的表也會過期。
#>
[CmdletBinding()]
param(
  [string]$RimeDir = 'C:\RIME',
  [string]$Schema  = 'bopomo_onionplus',
  [string]$OutFile = '',
  [switch]$Stdout
)

$ErrorActionPreference = 'Stop'
if (-not $OutFile) { $OutFile = Join-Path $RimeDir 'docs\KEYMAP.md' }

$build = Join-Path $RimeDir "build\$Schema.schema.yaml"
$defBuild = Join-Path $RimeDir 'build\default.yaml'
foreach ($f in @($build, $defBuild)) {
  if (-not (Test-Path $f)) { throw "找不到 $f —— 請先部署（WeaselDeployer.exe /deploy）" }
}

# ---------------------------------------------------------------- 小工具
# 只取需要的區塊，不引入 YAML 函式庫（避免多一個相依）。
function Get-Block([string]$path, [string]$key, [int]$indent = 0) {
  $lines = Get-Content $path -Encoding UTF8
  $pad = ' ' * $indent
  $start = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -eq "$pad${key}:") { $start = $i + 1; break }
  }
  if ($start -lt 0) { return @() }
  $out = @()
  for ($i = $start; $i -lt $lines.Count; $i++) {
    $l = $lines[$i]
    if ($l -match '^\s*$') { continue }
    $lead = ($l -replace '^(\s*).*$', '$1').Length
    if ($lead -le $indent) { break }
    $out += $l
  }
  return $out
}

function Esc([string]$s) { return ($s -replace '\|', '\\|') }

# 把值包成 markdown 行內程式碼。內容本身含反引號（如 emoji 前綴）時要改用雙反引號夾空白，
# 否則會把 markdown 撐破。
function Code([string]$s) {
  if ($s -eq '') { return '（空）' }
  if ($s.Contains([char]0x60)) { return '`` ' + $s + ' ``' }
  return [char]0x60 + $s + [char]0x60
}

# ---------------------------------------------------------------- 蒐集
$sb = [System.Text.StringBuilder]::new()
function W([string]$s = '') { [void]$sb.AppendLine($s) }

W '# 鍵位與代碼總表（自動產生）'
W ''
W '> ⚠ **這份檔案由 `tools/keymap-dump.ps1` 產生，不要手改** —— 下次重跑會被覆蓋。'
W '> 要改行為請改對應的來源檔（每一節都標了來源），改完重新部署再跑一次這支腳本。'
W '>'
W "> 產生時間：$(Get-Date -Format 'yyyy-MM-dd HH:mm')　方案：``$Schema``"
W ''
W '這份表要回答的問題：**「這個鍵／這個代碼，現在是誰在用？」**'
W '資料直接取自部署後的 `build/`（patch 與 `__include` 都已合併）與 lua 原始碼，'
W '所以看到的就是實際生效的值，不是「應該要是」的值。'
W ''

# ── 1. processor 鏈 ────────────────────────────────────────────────
W '## 1. processor 鏈（按鍵的攔截順序）'
W ''
W '排在前面的先看到按鍵，`return kAccepted` 之後就輪不到後面的。'
W '「某個鍵沒反應」或「按了跑出別的東西」，九成是這條鏈的順序問題。'
W ''
$procs = Get-Block $build 'engine' 0 | Where-Object { $_ -match '^\s{4}- ' -and $_ -notmatch ':' }
$inProc = $false
$procList = @()
foreach ($l in (Get-Block $build 'engine' 0)) {
  if ($l -match '^\s{2}processors:') { $inProc = $true; continue }
  if ($inProc) {
    if ($l -match '^\s{2}\w') { break }
    if ($l -match '^\s{4}- "?([^"]+)"?\s*$') { $procList += $Matches[1] }
  }
}
$n = 0
foreach ($p in $procList) {
  $n++
  W ("$n. ``$p``")
}
W ''
W '來源：`bopomo_onionplus.custom.yaml` 的 `engine/processors`。'
W '⚠ `lua_processor@x` 需要 `rime.lua` 有 `x = require(...)`，否則靜默失效。'
W ''

# ── 2. 選字與翻頁 ──────────────────────────────────────────────────
W '## 2. 選字鍵與翻頁鍵'
W ''
$selKeys = (Select-String -Path $build -Pattern '^\s*keys:\s*"(.*)"' -AllMatches |
            Where-Object { $_.Line -match 'keys' } | Select-Object -First 1)
$pSelKeys = ''
$m = Select-String -Path $build -Pattern '^p_select_keys:' -Context 0, 3
if ($m) { foreach ($l in $m.Context.PostContext) { if ($l -match '^\s+keys:\s*"(.+)"') { $pSelKeys = $Matches[1] } } }
$altKeys = ''
$mm = Select-String -Path $build -Pattern '^\s+alternative_select_keys:\s*"(.*)"'
if ($mm) { $altKeys = $mm.Matches[0].Groups[1].Value }
$pageSize = ''
$mp = Select-String -Path $build -Pattern '^\s+page_size:\s*(\d+)'
if ($mp) { $pageSize = $mp.Matches[0].Groups[1].Value }
$labels = @()
$inLab = $false
foreach ($l in (Get-Content $build -Encoding UTF8)) {
  if ($l -match '^\s+alternative_select_labels:') { $inLab = $true; continue }
  if ($inLab) {
    if ($l -match '^\s+- "?(.+?)"?\s*$') { $labels += $Matches[1] } else { break }
  }
}
W '| 項目 | 值 | 定義在 |'
W '|---|---|---|'
W ("| 選字鍵（lua） | ``$pSelKeys`` | ``bopomo_onionplus.custom.yaml`` → ``p_select_keys/keys``，行為在 ``lua/processor_p_select_keys.lua`` |")
W ("| 選字鍵（librime 內建） | " + $(if ($altKeys) { "``$altKeys``" } else { '**刻意留空**' }) + " | ``menu/alternative_select_keys``（設了 macOS 標籤會壞，見 GOTCHAS） |")
W ("| 候選標籤 | " + (($labels | ForEach-Object { "``$_``" }) -join ' ') + " | ``menu/alternative_select_labels`` |")
W ("| 每頁列數 | ``$pageSize`` | ``menu/page_size``（``element_bopomo.yaml``） |")
W ''

# ── 3. key_binder ─────────────────────────────────────────────────
W '## 3. 快捷鍵（key_binder）'
W ''
W '合併後的完整清單。`accept` 是實際按的鍵，`send`/`toggle`/`select` 是動作。'
W ''
W '| 按鍵 | 動作 | 生效條件 | 來源 |'
W '|---|---|---|---|'
foreach ($srcPair in @(@($build, '方案（element_bopomo ＋ custom）'), @($defBuild, '全域（default.custom.yaml）'))) {
  $src, $srcName = $srcPair
  $inKB = $false
  foreach ($l in (Get-Content $src -Encoding UTF8)) {
    if ($l -match '^key_binder:') { $inKB = $true; continue }
    if ($inKB) {
      if ($l -match '^\w') { break }
      if ($l -match 'accept:\s*"?([^",]+)"?') {
        $acc = $Matches[1].Trim()
        $act = ''
        if ($l -match '(send_sequence|send|toggle|select|unset_option|set_option|toggle_option):\s*"?([^",}]+)"?') { $act = "$($Matches[1]): $($Matches[2].Trim())" }
        $whn = ''
        if ($l -match 'when:\s*"?([^",}]+)"?') { $whn = $Matches[1].Trim() }
        W ("| ``$(Esc $acc)`` | $(Esc $act) | $whn | $srcName |")
      }
    }
  }
}
W ''
W '來源：`default.custom.yaml`（全域）＋ `element_bopomo.yaml`（方案內建）＋'
W '`bopomo_onionplus.custom.yaml` 的 `key_binder/bindings/+`。'
W ''

# ── 4. 語言／功能前綴 ──────────────────────────────────────────────
W '## 4. 輸入前綴（打這幾個字元會切到別的語言／功能段落）'
W ''
W '| 前綴 | 段落 | 定義在 |'
W '|---|---|---|'
$nsList = 'easy_en', 'easy_en_upper', 'european', 'japan', 'korea', 'fs2', 'gr2', 'cyr2',
          'reverse2_lookup', 'emoji_series', 'all_bpm', 'mf_translator'
$lines = Get-Content $build -Encoding UTF8
foreach ($ns in $nsList) {
  $idx = -1
  for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -eq "${ns}:") { $idx = $i; break } }
  if ($idx -lt 0) { continue }
  for ($i = $idx + 1; $i -lt $lines.Count -and $lines[$i] -match '^\s'; $i++) {
    if ($lines[$i] -match '^\s+prefix:\s*"?([^"]*)"?\s*$') {
      W ("| $(Code $Matches[1]) | $ns | ``build/$Schema.schema.yaml`` → ``$ns/prefix`` |")
      break
    }
  }
}
W ''

# ── 5. '/ 代碼 ────────────────────────────────────────────────────
W "## 5. ``'/`` 底下的代碼（誰註冊了什麼）"
W ''
W '`registry` 是 `exact[code] = handler`，**沒有衝突檢查、後註冊覆蓋先註冊**。'
W '註冊順序見 `lua/translator_multifunction_translator.lua`，越後面的模組贏。'
W '新增代碼前先在這張表查一下，不然會靜默蓋掉別人的。'
W ''
W '| 代碼 | 用途 | 註冊於 |'
W '|---|---|---|'
$luaDir = Join-Path $RimeDir 'lua\mf_components'
foreach ($f in (Get-ChildItem $luaDir -Filter '*.lua' | Sort-Object Name)) {
  foreach ($l in (Get-Content $f.FullName -Encoding UTF8)) {
    if ($l -match 'reg\.register_exact\(\s*"([^"]*)"\s*,') {
      $code = $Matches[1]
      $desc = ''
      if ($l -match '--\s*(.+)$') { $desc = $Matches[1].Trim() }
      elseif ($l -match '"(【[^"]+】[^"]*)"') { $desc = $Matches[1] }
      elseif ($l -match 'hier_menu') { $desc = '分層選單' }
      # 沒有註解也沒有標籤字串時（'/v、'/g、'/gc 這種），至少把 handler 名稱寫出來，
      # 才不會留一格空白讓人以為是漏抓
      elseif ($l -match 'register_exact\(\s*"[^"]*"\s*,\s*(\w+)') { $desc = "handler: ``$($Matches[1])``" }
      $shown = if ($code -eq '') { "``'/``（單獨）" } else { "``'/$code``" }
      W ("| $shown | $(Esc $desc) | ``lua/mf_components/$($f.Name)`` |")
    }
  }
}
# 日期時間規格表：數量太多，只列出開頭字母
$dtCodes = @()
foreach ($f in (Get-ChildItem $luaDir -Filter 'dt_specs_*.lua')) {
  foreach ($l in (Get-Content $f.FullName -Encoding UTF8)) {
    if ($l -match '^specs\["([a-z]+)"\]') { $dtCodes += $Matches[1] }
  }
}
$dtHeads = ($dtCodes | ForEach-Object { $_.Substring(0, 1) } | Sort-Object -Unique) -join ' '
W ("| ``'/`` ＋ 日期時間碼（共 $($dtCodes.Count) 個，開頭字母：$dtHeads） | 年月日週時分秒／節氣／月相／時區 | ``lua/mf_components/dt_specs_*.lua`` |")
# devkit
$devkit = Join-Path $RimeDir 'lua\translator_devkit.lua'
if (Test-Path $devkit) {
  # 同一個代碼會出現在多行 string.match（判斷式一行、取值一行），要去重
  $dkSeen = [ordered]@{}
  foreach ($l in (Get-Content $devkit -Encoding UTF8)) {
    if ($l -match 'string\.match\(body,\s*"\^([a-z]+)') { $dkSeen[$Matches[1]] = $true }
  }
  foreach ($c in $dkSeen.Keys) {
    W ("| ``'/$c`` … | 開發小工具 | ``lua/translator_devkit.lua`` |")
  }
}
W ''
W '### 命名空間'
W ''
W '指令沒有命名空間：`p_run_pattern.lua` 裡 `direct = true` 的條目就是一級代碼'
W "（``'/h`` ``'/git`` ``'/phrase`` ``'/cmd``），由 `mf_open_menu.register_direct` 掛載。"
W '⚠ 代碼撞到上表任何一個既有代碼時，該條目會**整條失效**（讓路給既有功能）。'
W '曾經有過 ``/j`` 命名空間與改用 ``c`` 的版本，都已移除，見 `docs/GOTCHAS.md`。'
W ''

# ── 6. recognizer ─────────────────────────────────────────────────
W '## 6. recognizer 樣式（會「搶走」按鍵的隱形規則）'
W ''
W '`recognizer` 排在 `speller`／`selector` 之前，判斷方式是'
W '**「把這個鍵接上去之後還符合樣式，就收下」**。'
W '所以樣式裡出現的字元，在組字途中會被它接走 —— 這是最難查的一類衝突。'
W ''
W '| 段落 | 樣式裡出現的可見字元 |'
W '|---|---|'
$inRec = $false
foreach ($l in (Get-Content $build -Encoding UTF8)) {
  if ($l -match '^recognizer:') { $inRec = $true; continue }
  if ($inRec) {
    if ($l -match '^\w') { break }
    if ($l -match '^\s{4}(\w+):\s*"(.*)"\s*$') {
      $tag = $Matches[1]; $pat = $Matches[2]
      # 只挑「非字母數字、且不是正規表示式語法」的字元，那些才是會撞到的實體按鍵
      $chars = ($pat.ToCharArray() | Where-Object { '@:!#%^&_~' -contains $_ } | Sort-Object -Unique) -join ' '
      if (-not $chars) { $chars = '（無特殊符號）' }
      W ("| $tag | $(Esc $chars) |")
    }
  }
}
W ''
W '已知因此產生的衝突：`@` 被 `email_url_translator` 的 `^[a-z][-_.0-9a-z]*@.*$` 接走，'
W '所以「輸入以英文字母開頭時按 ⇧2 選不到字」。這是上游設計，刻意保留。'
W ''

# ── 7. 系統佔用 ───────────────────────────────────────────────────
W '## 7. 被作業系統吃掉的鍵（傳不到輸入法）'
W ''
W '| 鍵 | 誰吃掉的 | 對策 |'
W '|---|---|---|'
W '| `Ctrl+Alt+<字母>` | Windows 視為 AltGr，小狼毫不轉送 | 改用 `Ctrl+Shift+F1~F4` |'
W '| `Ctrl+Shift+0` | Windows 系統熱鍵（登錄檔 `Input Method\Hot Keys` 的 `00000104`） | `en_sort` 改綁 `Ctrl+Shift+F5` |'
W '| `Ctrl+Alt+G/K/L/V` | 同上，`00000200~0203` | 避開 |'
W '| `F1~F4`（macOS） | 預設是亮度／調度中心等媒體鍵 | 開「標準功能鍵」或用 `Ctrl+Opt+1~4` |'
W '| `Caps Lock`（macOS） | 系統的「用大寫鎖定鍵切換輸入法」 | 到系統設定手動關掉 |'
W ''
W '查 Windows 註冊了哪些輸入法熱鍵：'
W ''
W '```powershell'
W "Get-ChildItem 'HKCU:\Control Panel\Input Method\Hot Keys' | ForEach-Object {"
W '  $v = Get-ItemProperty $_.PSPath'
W "  '{0} mod={1:X2} vk={2:X2}' -f `$_.PSChildName, `$v.'Key Modifiers'[0], `$v.'Virtual Key'[0] }"
W '```'
W ''

$text = $sb.ToString()
if ($Stdout) { $text }
else {
  $dir = Split-Path $OutFile
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
  [System.IO.File]::WriteAllText($OutFile, $text, [System.Text.UTF8Encoding]::new($false))
  Write-Host "已寫入 $OutFile" -ForegroundColor Green
}
