# rime-apply.ps1 — 把 repo 的 rime\ 「攤平」套用到 RIME 使用者資料夾（Windows）
#
# repo 裡為了好維護，檔案按功能分在 rime\<分類>\ 底下；但 RIME 引擎只認使用者資料夾
# 「根目錄」的方案／設定／詞典檔。這支腳本負責中間那一步：
#
#   rime\lua\**、rime\opencc\**   → <使用者資料夾>\lua\**、\opencc\**   （保留資料夾）
#   rime\<其他分類>\<檔案>        → <使用者資料夾>\<檔案>               （攤平到根目錄）
#
# 使用者資料夾裡「不是從 repo 複製來」的檔，這支腳本只建立、不覆蓋：
#   weasel.custom.yaml、default.custom.yaml   使用者與小狼毫設定對話框的（只有一行 __include 接上 repo 的設定）
#   na_style／na_input／na_menu.custom.yaml   '/setup 選的選項（install.ps1 寫的，這裡只做舊格式的轉換）
#   bopomo_onionplus_phrase.txt               個人短語（第一次從範本複製）
#
# 只做複製，不部署、不重啟。平常不用直接跑它：
#   ‧ 安裝／重選選項  → install.ps1（或使用者資料夾裡的 na-setup.cmd）
#   ‧ 更新            → rime-update.ps1（輸入法內打 '/git）
#   ‧ 沙盒測試        → tools\rime-test.ps1 -Sync
# 這三個都會呼叫這支。手動安裝的人可以自己跑：
#   powershell -ExecutionPolicy Bypass -File scripts\rime-apply.ps1
#
# 回傳一個物件 { Lua; Build; Removed }：這次實際變動了幾個 lua 檔／幾個會進 build 的檔／
# 刪了幾個舊檔。rime-update.ps1 靠它決定要不要部署、要不要重啟。
#
# ⚠ 要能在 Windows PowerShell 5.1 跑；本檔存成 UTF-8 含 BOM（見 docs\GOTCHAS.md）。

[CmdletBinding()]
param(
    [string]$RimeDir,        # 目標：RIME 使用者資料夾（預設讀小狼毫的設定）
    [switch]$NoLaunchers,    # 不產生 na-update.cmd／na-setup.cmd（沙盒測試用）
    [string]$SharedData,     # 小狼毫的內建資料夾（預設：目標是小狼毫正在用的資料夾時自動找；測試時可指定）
    [switch]$AllowDowngrade, # 目標資料夾的版面比這份 repo 新也照樣套用（沙盒測試用，見下面「版面編號」）
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot -Parent
$Src  = Join-Path $Repo 'rime'
if (-not (Test-Path $Src)) { throw "找不到 $Src" }

if (-not $RimeDir) {
    $r = Get-ItemProperty 'HKCU:\Software\Rime\Weasel' -ErrorAction SilentlyContinue
    if ($r -and $r.RimeUserDir) { $RimeDir = $r.RimeUserDir } else { $RimeDir = Join-Path $env:APPDATA 'Rime' }
}
$RimeDir = [IO.Path]::GetFullPath($RimeDir).TrimEnd('\')

# 防呆：目標不可以是 repo 自己（或在 repo 裡面），否則會把攤平的檔案倒進版控目錄
$repoFull = [IO.Path]::GetFullPath($Repo).TrimEnd('\')
if ($RimeDir -ieq $repoFull -or $RimeDir.ToLower().StartsWith($repoFull.ToLower() + '\')) {
    throw "使用者資料夾（$RimeDir）不可以是設定 repo 本身或它的子資料夾。"
}
# 舊版安裝：使用者資料夾本身就是 git clone。直接往裡面倒檔案會弄髒那個 repo，
# 要先由安裝腳本把它備份搬走。
if (Test-Path (Join-Path $RimeDir '.git')) {
    throw "$RimeDir 是舊版安裝（資料夾本身是 git repo）。請重跑 README 的安裝指令，它會幫你備份並遷移。"
}
New-Item -ItemType Directory -Force $RimeDir | Out-Null

# ── 版面編號：擋下「舊版的 repo 去套用新版面的資料夾」──────────────────
# 「使用者資料夾裡的個人檔叫什麼名字、哪些檔歸使用者」每改一次，這個數字就加 1
# （rime-apply.sh 的 LAYOUT 要一起改）。套用時記在 na_manifest.txt 的檔頭。
#   2＝選項拆成 na_style／na_input／na_menu；weasel.custom.yaml、default.custom.yaml 改歸使用者
# 為什麼要擋：同一台電腦有兩份 clone（安裝用的 ~/.na-plus 和開發用的那份）而且版本不同時，
# 舊的那份不認得新的個人選項檔 —— 它會把選項寫回預設值、把新版的檔當成「repo 已刪除」清掉。
# 兩份輪流套用，看起來就是「設定一直被重置」（真的發生過，查了很久才發現是兩份 clone 在打架）。
$Layout = 2
$manifest = Join-Path $RimeDir 'na_manifest.txt'
if ((Test-Path -LiteralPath $manifest) -and -not $AllowDowngrade) {
    $hit = Select-String -LiteralPath $manifest -Pattern '^#\s*na-layout:\s*(\d+)' | Select-Object -First 1
    if ($hit -and [int]$hit.Matches[0].Groups[1].Value -gt $Layout) {
        throw ("$RimeDir 上次是用比較新版的設定套用的（版面 $($hit.Matches[0].Groups[1].Value)），這份 repo（$Repo）比較舊（版面 $Layout）。" +
               "硬套會把你的選項重置。請先更新這份 repo（git pull），或改用比較新的那一份來套用。")
    }
}

# ── 列出「來源 → 相對目標路徑」────────────────────────────────────────
$keepDirs = 'lua', 'opencc'          # 這兩類保留資料夾結構，其餘分類攤平
$map = [ordered]@{}                  # 相對目標路徑（小寫）→ 來源檔
$rel = @{}                           # 相對目標路徑（小寫）→ 相對目標路徑（原大小寫）
foreach ($cat in Get-ChildItem $Src -Directory | Sort-Object Name) {
    $base = $cat.FullName.TrimEnd('\')
    foreach ($f in Get-ChildItem $cat.FullName -File -Recurse) {
        $inner = $f.FullName.Substring($base.Length + 1)
        if ($keepDirs -contains $cat.Name) { $target = Join-Path $cat.Name $inner } else { $target = $inner }
        $key = $target.ToLower()
        if ($map.Contains($key)) {
            throw "檔名衝突：$($f.FullName) 與 $($map[$key].FullName) 攤平後都是 $target"
        }
        $map[$key] = $f; $rel[$key] = $target
    }
}

# ── 複製（內容沒變就不動，避免無謂的重新編譯）──────────────────────────
# 先比大小與修改時間，時間不同再比內容；Copy-Item 會保留修改時間，所以沒變的檔下次比對仍然相同。
$lua = 0; $build = 0

# ── 舊版的單一選項檔 na_options.custom.yaml → 拆成三個 ───────────────────
# 選項現在分 na_style／na_input／na_menu 三個檔（原因見 rime\core\na_style.yaml 檔頭）。
# 已經裝過的人手上是舊的單一檔，這裡照鍵名分過去，一行都不改；舊檔改名成 .bak 留著。
$oldOpt = Join-Path $RimeDir 'na_options.custom.yaml'
if (Test-Path -LiteralPath $oldOpt) {
    $route = @{ emoji = 'input'; gloss = 'input'; schema_list = 'menu'; langs = 'menu' }   # 沒列到的都屬於 style
    $body = @{ style = @(); input = @(); menu = @() }
    $head = @{ style = @(); input = @(); menu = @() }
    $cur = $null
    foreach ($ln in (([IO.File]::ReadAllText($oldOpt) -replace "`r`n", "`n").Split("`n"))) {
        if ($ln -match '^#\s*na-options:\s*(.*)$') {
            foreach ($kv in ($Matches[1].Trim() -split '\s+')) {
                $name = ($kv -split '=', 2)[0]
                if ($route.ContainsKey($name)) { $head[$route[$name]] += $kv } else { $head['style'] += $kv }
            }
        } elseif ($ln -match '^  ([A-Za-z_]+):') {
            if ($route.ContainsKey($Matches[1])) { $cur = $route[$Matches[1]] } else { $cur = 'style' }
            $body[$cur] += $ln
        } elseif ($cur -and $ln -match '^ {3,}\S') {
            $body[$cur] += $ln      # 上一個鍵的內容（例如 schema_list 底下的清單）
        }
    }
    foreach ($part in 'style', 'input', 'menu') {
        $dst = Join-Path $RimeDir "na_$part.custom.yaml"
        if ((Test-Path -LiteralPath $dst) -or -not $body[$part].Count) { continue }
        $out = @("# na_$part.custom.yaml — 個人選項（從舊版的 na_options.custom.yaml 轉過來，不進版控）",
                 "# 想換：輸入法裡打 '/setup；或手動改下面的值後重新部署。各鍵說明見 na_$part.yaml。")
        if ($head[$part].Count) {
            $out += '# ↓ 這行是給安裝腳本讀「上次選了什麼」用的，手動改值時請一起改，或整行刪掉。'
            $out += '# na-options: ' + ($head[$part] -join ' ')
        }
        $out += 'patch:'
        $out += $body[$part]
        [IO.File]::WriteAllText($dst, (($out -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))
    }
    Move-Item -LiteralPath $oldOpt -Destination "$oldOpt.bak" -Force
    $build++   # 選項檔換了名字，要重新部署才會生效
}

# ── 舊格式的個人選項：「不跟隨系統深色模式」原本寫成 theme_dark 跟 theme 同名 ──
# Windows 在深色模式時，小狼毫先套 color_scheme，再看 color_scheme_dark 讀不讀得到字串，
# 讀得到就蓋過去。同名等於把深色模式釘死在安裝當下的主題：之後在小狼毫「輸入法設定」對話框
# 換配色（它只改 color_scheme），深色模式下怎麼換都看不出來。
# 現在「不跟隨」寫成 theme_dark: ~（空值），小狼毫讀不到就退回 color_scheme。這裡把舊檔改過來。
$optFile = Join-Path $RimeDir 'na_style.custom.yaml'
if (Test-Path -LiteralPath $optFile) {
    $optText = [IO.File]::ReadAllText($optFile)
    $m1 = [regex]::Match($optText, '(?m)^  theme:[ \t]*(\S+)')
    $m2 = [regex]::Match($optText, '(?m)^  theme_dark:[ \t]*(\S+)')
    if ($m1.Success -and $m2.Success -and $m2.Groups[1].Value -ne '~' -and $m2.Groups[1].Value -eq $m1.Groups[1].Value) {
        $fixed = [regex]::Replace($optText, '(?m)^  theme_dark:[ \t]*\S+', '  theme_dark: ~', 1)
        [IO.File]::WriteAllText($optFile, $fixed, (New-Object Text.UTF8Encoding $false))
        $build++   # 選項檔變了，要重新部署才會生效
    }
}

# ── weasel.custom.yaml、default.custom.yaml 是「使用者的」：只建立，不覆蓋 ──
# 小狼毫的「輸入法設定」對話框會寫這兩個檔（配色寫進 weasel.custom.yaml 的 "style/color_scheme"，
# 勾選的方案寫進 default.custom.yaml 的 schema_list），而且每次都把整個檔重寫。
# 以前 repo 的內容也放在這兩個檔，套用時一複製就把對話框的選擇蓋掉；後來改成套用前記下、
# 蓋完補回檔尾、再比檔案時間猜誰比較新 —— 只顧得到配色，而且很脆弱。
# 現在 repo 的內容搬到 na_weasel.yaml／na_default.yaml，這兩個檔只放一行 __include 把它接進來，
# 其餘都是使用者（與對話框）的：寫在那一行底下的鍵會蓋過 repo 的值。套用腳本從此不再碰它們，
# '/setup 要換主題或語言時自己把對應的那一行拿掉（見 install.ps1）。
# 這是 RIME 社群既有的寫法（easy_en 的安裝說明就是 patch: 底下寫 __include: easy_en:/patch）。
$owned = [ordered]@{ 'weasel.custom.yaml' = 'na_weasel'; 'default.custom.yaml' = 'na_default' }
foreach ($name in $owned.Keys) {
    # repo 裡不可以再出現這兩個檔名：下面的複製會把使用者的檔整個蓋掉，問題又回來了
    if ($map.Contains($name)) { throw "$($map[$name].FullName)：rime\ 裡不可以放 $name（那是使用者的檔）。內容請寫進 $($owned[$name]).yaml。" }
}
foreach ($name in $owned.Keys) {
    $dst = Join-Path $RimeDir $name
    $ref = "$($owned[$name]):/patch"
    $old = ''
    if (Test-Path -LiteralPath $dst) { $old = [IO.File]::ReadAllText($dst) }
    # 已經接上了（不看註解行）→ 是使用者的檔，不碰
    if ($old -match ('(?m)^[^#\r\n]*' + [regex]::Escape($ref))) { continue }
    # 沒有這個檔，或是舊版面留下來的（整個檔是從 repo 複製來的）→ 換成新格式。
    # 舊版面裡對話框選的配色要帶過來；方案清單不帶（舊版面每次套用本來就會把它蓋掉）。
    $keep = ''
    if ($name -eq 'weasel.custom.yaml') {
        $picked = [regex]::Match($old, '(?m)^  "?style/color_scheme"?:[ \t]*"?([^"\s#{]+)"?[ \t]*(#.*)?\r?$')
        if ($picked.Success) { $keep = "  `"style/color_scheme`": $($picked.Groups[1].Value)`n" }
    }
    $shim = "# $name — 這個檔是你的，更新不會覆蓋它。`n" +
            "# __include 那一行把這套設定（$($owned[$name]).yaml）接進來，請留著；寫在它底下的鍵會蓋過這套設定的值。`n" +
            "# 小狼毫「輸入法設定」對話框的選擇也是寫在這裡（它存檔時會把這幾行註解拿掉，沒關係）。`n" +
            "patch:`n" +
            "  __include: $ref`n" + $keep
    # 原本有內容就留一份 .bak：通常是舊版面的 repo 內容（留著無妨），但也可能是使用者自己把
    # __include 那一行拿掉的檔 —— 那種情況不能讓他寫的東西無聲無息消失。
    if ($old.Trim()) { Copy-Item -LiteralPath $dst -Destination "$dst.bak" -Force }
    [IO.File]::WriteAllText($dst, $shim, (New-Object Text.UTF8Encoding $false))
    $build++
}

foreach ($key in $map.Keys) {
    $s = $map[$key]
    $dst = Join-Path $RimeDir $rel[$key]
    $same = $false
    if (Test-Path -LiteralPath $dst) {
        $d = Get-Item -LiteralPath $dst
        if ($d.Length -eq $s.Length) {
            # 大小、時間都一樣 → 當成沒變（最常見，不必讀檔）。
            # 大小一樣但時間不同 → 比內容。換一份 clone 來套用、或 git 重新簽出時，檔案內容沒變
            # 但修改時間全都不一樣；只看時間的話會把一百多個檔全部重新複製，
            # 連帶讓 RIME 整輪重新編譯（實測多等將近三分鐘）。
            $same = ($d.LastWriteTimeUtc -eq $s.LastWriteTimeUtc) -or
                    ((Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $s.FullName -Algorithm SHA256).Hash)
        }
    }
    if ($same) { continue }
    $dir = Split-Path $dst -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    Copy-Item -LiteralPath $s.FullName -Destination $dst -Force
    if ($s.Extension -eq '.lua') { $lua++ } else { $build++ }
}

# ── 內建設定檔的副本：不放的話，每次部署都會白白重編一輪 ─────────────────
# 症狀：什麼都沒改，部署卻每次重寫十幾個方案、重建好幾個詞典索引，要等 1～10 秒不等。
# 原因：RIME 靠「編譯時記下的檔案時間」判斷設定要不要重編。小狼毫安裝目錄裡的
#   default.yaml／key_bindings.yaml／punctuation.yaml 修改時間剛好是整秒，而 librime 換算時間時
#   有極小的誤差，整秒的檔會有時算成 N、有時算成 N-1（實測同一次部署裡兩種都出現）。
#   於是每次部署都有一批方案被當成「內建設定變了」而重編，連帶重建詞典索引。
# 解法：在使用者資料夾放一份一模一樣的副本，時間設成「原檔＋半秒」。RIME 優先讀使用者資料夾的，
#   帶小數的時間怎麼算都是同一個值。實測：沒變動的部署從重寫 16～26 個檔變成 0 個、穩定 1 秒內。
# 副本跟著原檔走：小狼毫升級後內容不同了，下次套用會重新複製。只管「內容跟我們上次複製的一樣」
# 的檔 —— 使用者自己放、自己改過的 default.yaml 不會被動到（記錄在 na_shared_copy.txt）。
$sharedNames = 'default.yaml', 'key_bindings.yaml', 'punctuation.yaml'
if (-not $SharedData) {
    $reg = Get-ItemProperty 'HKCU:\Software\Rime\Weasel' -ErrorAction SilentlyContinue
    $registered = Join-Path $env:APPDATA 'Rime'
    if ($reg -and $reg.RimeUserDir) { $registered = $reg.RimeUserDir }
    if ($RimeDir -ieq [IO.Path]::GetFullPath($registered).TrimEnd('\')) {
        foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Rime\Weasel', 'HKLM:\SOFTWARE\Rime\Weasel') {
            $w = Get-ItemProperty $k -ErrorAction SilentlyContinue
            if ($w -and $w.WeaselRoot -and (Test-Path (Join-Path $w.WeaselRoot 'data\default.yaml'))) { $SharedData = Join-Path $w.WeaselRoot 'data'; break }
        }
    }
}
if ($SharedData -and (Test-Path -LiteralPath $SharedData)) {
    $recFile = Join-Path $RimeDir 'na_shared_copy.txt'
    $rec = @{}
    if (Test-Path -LiteralPath $recFile) {
        foreach ($ln in (Get-Content -LiteralPath $recFile -Encoding UTF8)) {
            $p = $ln -split "`t"
            if ($p.Count -eq 2 -and -not $ln.StartsWith('#')) { $rec[$p[0]] = $p[1] }
        }
    }
    $recNew = @{}
    foreach ($n in $sharedNames) {
        $src = Join-Path $SharedData $n
        $dst = Join-Path $RimeDir $n
        if (-not (Test-Path -LiteralPath $src)) { continue }
        $srcItem = Get-Item -LiteralPath $src
        $srcHash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
        $want = $srcItem.LastWriteTimeUtc.AddMilliseconds(500)
        if (Test-Path -LiteralPath $dst) {
            $dstHash = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
            # 內容跟原檔不同、也不是我們上次複製的那份 → 是使用者自己的檔，不碰
            if ($dstHash -ne $srcHash -and $rec[$n] -ne $dstHash) { continue }
            if ($dstHash -eq $srcHash -and (Get-Item -LiteralPath $dst).LastWriteTimeUtc -eq $want) { $recNew[$n] = $srcHash; continue }
        } elseif (($srcItem.LastWriteTimeUtc.Ticks % 10000000) -ne 0) {
            continue    # 原檔的時間本來就不是整秒，沒有這個問題，不需要副本
        }
        Copy-Item -LiteralPath $src -Destination $dst -Force
        (Get-Item -LiteralPath $dst).IsReadOnly = $false
        (Get-Item -LiteralPath $dst).LastWriteTimeUtc = $want
        $recNew[$n] = $srcHash
        $build++
    }
    if ($recNew.Count) {
        $recLines = @('# 注音Na+：從小狼毫內建資料夾複製過來的設定檔（自動產生，請勿修改；原因見 scripts\rime-apply.ps1）')
        $recLines += @($recNew.Keys | Sort-Object | ForEach-Object { "$_`t$($recNew[$_])" })
        $recText = ($recLines -join "`n") + "`n"
        if (-not (Test-Path -LiteralPath $recFile) -or [IO.File]::ReadAllText($recFile) -ne $recText) {
            [IO.File]::WriteAllText($recFile, $recText, (New-Object Text.UTF8Encoding $false))
        }
    }
}

# ── 清掉「上次裝過、這次 repo 已經沒有」的檔 ────────────────────────────
# 不清的話，repo 刪掉的 lua 模組會一直留在使用者資料夾被 require 到（踩過，見 GOTCHAS）。
# 只刪清單上列過的檔，使用者自己放的東西不會被動到。
# （weasel.custom.yaml、default.custom.yaml 在舊版面的清單上，但現在歸使用者，不可以刪。）
$removed = 0
if (Test-Path $manifest) {
    foreach ($old in (Get-Content -LiteralPath $manifest -Encoding UTF8)) {
        $o = $old.Trim()
        if (-not $o -or $o.StartsWith('#')) { continue }
        $k = ($o -replace '/', '\').ToLower()
        if (-not $map.Contains($k) -and -not $owned.Contains($k)) {
            $p = Join-Path $RimeDir ($o -replace '/', '\')
            if (Test-Path -LiteralPath $p -PathType Leaf) { Remove-Item -LiteralPath $p -Force; $removed++ }
        }
    }
}
$utf8 = New-Object Text.UTF8Encoding $false
$lines = @('# 注音Na+ 安裝腳本裝進來的檔案清單（自動產生，請勿修改；更新時靠它清掉已移除的舊檔）',
           "# na-layout: $Layout")
$lines += @($rel.Values | ForEach-Object { $_ -replace '\\', '/' } | Sort-Object)
# 內容沒變就不重寫（這個檔不影響編譯，只是不必要的寫入能省就省）
$manifestText = ($lines -join "`n") + "`n"
if (-not (Test-Path -LiteralPath $manifest) -or [IO.File]::ReadAllText($manifest) -ne $manifestText) {
    [IO.File]::WriteAllText($manifest, $manifestText, $utf8)
}

# ── 個人短語檔：第一次從範本複製（之後永遠不覆蓋）──────────────────────
$phrase = Join-Path $RimeDir 'bopomo_onionplus_phrase.txt'
$sample = Join-Path $RimeDir 'bopomo_onionplus_phrase.sample.txt'
if (-not (Test-Path $phrase) -and (Test-Path $sample)) { Copy-Item -LiteralPath $sample -Destination $phrase }

# ── 啟動器：讓輸入法（'/git）與使用者找得到 repo 裡的腳本 ───────────────
# 批次檔是用 OEM 字碼頁讀的，路徑含中文（例如使用者名稱）會壞。所以盡量寫成
# %USERPROFILE% 這種環境變數；真的避不掉才在開頭 chcp 65001。
if (-not $NoLaunchers) {
    $repoRef = $repoFull
    $up = $env:USERPROFILE
    if ($up -and $repoFull.ToLower().StartsWith($up.ToLower() + '\')) { $repoRef = '%USERPROFILE%' + $repoFull.Substring($up.Length) }
    $head = "@echo off`r`n"
    if ($repoRef -match '[^\x00-\x7F]') { $head += "chcp 65001 >nul`r`n" }
    [IO.File]::WriteAllText((Join-Path $RimeDir 'na-update.cmd'),
        ($head + "rem Generated by rime-apply.ps1: update config (git pull + apply + redeploy).`r`n" +
         "`"$repoRef\scripts\rime-update.cmd`" %*`r`n"), $utf8)
    [IO.File]::WriteAllText((Join-Path $RimeDir 'na-setup.cmd'),
        ($head + "rem Generated by rime-apply.ps1: re-run the installer to re-pick options.`r`n" +
         "`"$repoRef\scripts\rime-setup.cmd`" %*`r`n"), $utf8)
}

if (-not $Quiet) {
    Write-Host ("      套用到 {0}：更新 {1} 個檔（lua {2}）、移除 {3} 個舊檔" -f $RimeDir, ($lua + $build), $lua, $removed)
}
[pscustomobject]@{ Lua = $lua; Build = $build; Removed = $removed; RimeDir = $RimeDir }
