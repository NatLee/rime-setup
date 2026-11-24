# rime-apply.ps1 — 把 repo 的 rime\ 「攤平」套用到 RIME 使用者資料夾（Windows）
#
# repo 裡為了好維護，檔案按功能分在 rime\<分類>\ 底下；但 RIME 引擎只認使用者資料夾
# 「根目錄」的方案／設定／詞典檔。這支腳本負責中間那一步：
#
#   rime\lua\**、rime\opencc\**   → <使用者資料夾>\lua\**、\opencc\**   （保留資料夾）
#   rime\<其他分類>\<檔案>        → <使用者資料夾>\<檔案>               （攤平到根目錄）
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

# ── 小狼毫「輸入法設定」對話框裡選的配色要能用、也要留得住 ──────────────
# 那個對話框把選擇寫進使用者資料夾的 weasel.custom.yaml（patch 底下多一個
# "style/color_scheme": 名稱），兩件事會讓它「選了沒反應」：
#
# ① 深色模式被釘住。Windows 在深色模式時，小狼毫先套 color_scheme，再看
#    color_scheme_dark 讀不讀得到字串，讀得到就蓋過去。舊版安裝腳本在「不跟隨系統」時
#    把 theme_dark 寫成跟 theme 同一個名稱 —— 等於把深色模式釘死在安裝當下的主題，
#    對話框只改 color_scheme，深色模式下怎麼換都看不出來。
#    現在「不跟隨」寫成 theme_dark: ~（空值），小狼毫讀不到就退回 color_scheme。
#    這裡順手把舊格式的個人選項檔改過來（保留檔案時間，不影響下面「誰比較新」的判斷）。
$optFile = Join-Path $RimeDir 'na_options.custom.yaml'
if (Test-Path -LiteralPath $optFile) {
    $optText = [IO.File]::ReadAllText($optFile)
    $m1 = [regex]::Match($optText, '(?m)^  theme:[ \t]*(\S+)')
    $m2 = [regex]::Match($optText, '(?m)^  theme_dark:[ \t]*(\S+)')
    if ($m1.Success -and $m2.Success -and $m2.Groups[1].Value -ne '~' -and $m2.Groups[1].Value -eq $m1.Groups[1].Value) {
        $stamp = (Get-Item -LiteralPath $optFile).LastWriteTimeUtc
        $fixed = [regex]::Replace($optText, '(?m)^  theme_dark:[ \t]*\S+', '  theme_dark: ~', 1)
        [IO.File]::WriteAllText($optFile, $fixed, (New-Object Text.UTF8Encoding $false))
        (Get-Item -LiteralPath $optFile).LastWriteTimeUtc = $stamp
        $build++   # 選項檔變了，要重新部署才會生效
    }
}

# ② 會被蓋掉。weasel.custom.yaml 是從 repo 複製來的檔，照一般規則下次套用就整個蓋回去，
#    對話框選的配色無聲無息消失。所以套用前先把那個選擇記下來，蓋完再補回檔尾。
#    誰比較新聽誰的：之後用 '/setup（安裝腳本）重選主題會重寫 na_options.custom.yaml，
#    它比 weasel.custom.yaml 新的話，對話框的舊選擇就不再保留。
$weaselTail = ''
$weaselDst = Join-Path $RimeDir 'weasel.custom.yaml'
if (Test-Path -LiteralPath $weaselDst) {
    $picked = [regex]::Match([IO.File]::ReadAllText($weaselDst), '(?m)^  "?style/color_scheme"?:[ \t]*"?([^"\s#]+)"?[ \t]*(#.*)?\r?$')
    if ($picked.Success) {
        $optNewer = (Test-Path -LiteralPath $optFile) -and
                    ((Get-Item -LiteralPath $optFile).LastWriteTimeUtc -gt (Get-Item -LiteralPath $weaselDst).LastWriteTimeUtc)
        if (-not $optNewer) {
            $weaselTail = "`n  # ↓ 你在小狼毫「輸入法設定」裡選的配色。套用／更新時會自動保留；`n" +
                          "  #   之後用 '/setup 重選主題的話，以那邊為準，這幾行會被拿掉。`n" +
                          "  `"style/color_scheme`": $($picked.Groups[1].Value)`n"
        }
    }
}
foreach ($key in $map.Keys) {
    $s = $map[$key]
    $dst = Join-Path $RimeDir $rel[$key]
    if ($weaselTail -and $key -eq 'weasel.custom.yaml') {
        # 這個檔的「應有內容」＝repo 版本＋對話框的選擇；跟現況一樣就不動（否則每次更新都會觸發部署）
        $want = ([IO.File]::ReadAllText($s.FullName) -replace "`r`n", "`n").TrimEnd("`n") + "`n" + $weaselTail
        $have = [IO.File]::ReadAllText($dst) -replace "`r`n", "`n"
        if ($want -ne $have) { [IO.File]::WriteAllText($dst, $want, (New-Object Text.UTF8Encoding $false)); $build++ }
        continue
    }
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

# ── 清掉「上次裝過、這次 repo 已經沒有」的檔 ────────────────────────────
# 不清的話，repo 刪掉的 lua 模組會一直留在使用者資料夾被 require 到（踩過，見 GOTCHAS）。
# 只刪清單上列過的檔，使用者自己放的東西不會被動到。
$manifest = Join-Path $RimeDir 'na_manifest.txt'
$removed = 0
if (Test-Path $manifest) {
    foreach ($old in (Get-Content -LiteralPath $manifest -Encoding UTF8)) {
        $o = $old.Trim()
        if (-not $o -or $o.StartsWith('#')) { continue }
        $k = ($o -replace '/', '\').ToLower()
        if (-not $map.Contains($k)) {
            $p = Join-Path $RimeDir ($o -replace '/', '\')
            if (Test-Path -LiteralPath $p -PathType Leaf) { Remove-Item -LiteralPath $p -Force; $removed++ }
        }
    }
}
$utf8 = New-Object Text.UTF8Encoding $false
$lines = @('# 注音Na+ 安裝腳本裝進來的檔案清單（自動產生，請勿修改；更新時靠它清掉已移除的舊檔）')
$lines += @($rel.Values | ForEach-Object { $_ -replace '\\', '/' } | Sort-Object)
[IO.File]::WriteAllText($manifest, (($lines -join "`n") + "`n"), $utf8)

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
