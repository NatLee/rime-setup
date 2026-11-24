# rime-update.ps1 — Windows：拉取最新設定 → 套用到使用者資料夾 →（必要時）部署／重啟
#
# 由輸入法內打 '/git ＋空白鍵觸發：lua 開使用者資料夾裡的 na-update.cmd，
# 它轉給 repo 的 scripts\rime-update.cmd，後者挑 pwsh 或 powershell 來跑這支。
# 安裝腳本 install.ps1 最後一步也是呼叫這支（-Force -SkipPull）。
#
# repo 與使用者資料夾是分開的兩個地方（repo 的 rime\ 按功能分類，使用者資料夾是攤平的），
# 中間靠 rime-apply.ps1 複製。這支腳本所在的 repo 就是來源。
#
# ⚠ 要同時能在 Windows PowerShell 5.1 與 pwsh 7 跑（一般人的電腦只有 5.1）：
#   ‧ 不用三元運算子、??、&& 這些 7 才有的語法
#   ‧ 本檔存成「UTF-8 含 BOM」—— 5.1 讀沒有 BOM 的檔會當成 ANSI，中文變亂碼甚至語法錯
#
# ── 這支腳本為什麼長這樣（都是實測出來的，改之前先讀）──────────────────
#
# ① 先停服務、再部署
#    部署是**同步**的：WeaselDeployer /deploy 會等編譯完才回傳
#    （實測單一方案重編 1.6 秒、大改動 10~13 秒，動到詞典更久）。
#    問題是服務還活著的時候，這段時間 IME 收得到按鍵卻回不了字 ——
#    使用者看到的就是「卡死」。先把服務停掉，就變成乾淨的「暫時沒有輸入法」，
#    而不是「有但沒反應」，也沒有人跟編譯搶 build\ 的檔案。
#    實測：服務停止時部署 exit 0，且部署器不會自己把服務拉起來。
#
# ② 用 WeaselServer.exe /quit，不要 Stop-Process -Force
#    強殺會讓正在連線的應用程式卡在具名管線上（那才是真的卡死，而且卡的是
#    使用者當下在打字的那個視窗）。/quit 是官方開關，實測 159~177ms 乾淨退出。
#    而且要「等它真的消失」再啟動，不要 Start-Sleep 猜秒數。
#
# ③ 沒變更就什麼都不做
#    以「套用時實際有沒有檔案被改到」為準（rime-apply.ps1 的回傳值）：
#      沒有檔案變動  → 直接結束（完全不動 IME）
#      只有 .lua     → 只重啟（lua 只在服務啟動時載入，部署不會重讀）
#      有 yaml/詞典  → 部署＋重啟
#    要強制跑一輪：加 -Force
#
# ④ 成功自己關視窗，失敗才停下來等人看
#    這個視窗是 WeaselServer 透過 os.execute 開出來的，留著不關很煩。

[CmdletBinding()]
param(
    [switch]$Force,          # 沒有變更也強制部署＋重啟
    [switch]$SkipPull,       # 不自己 git pull（給已經拉過的呼叫端，如 install.ps1、rime-sync.ps1）
    [switch]$NoPause,        # 失敗時不要等 Enter（被其他腳本呼叫時必加，否則會卡住對方）
    [switch]$NoDeploy,       # 只套用檔案，完全不碰輸入法服務（測試用）
    [int]$CloseAfter = 5,    # 成功後幾秒自動關閉（0 = 不自動關）
    [string]$RimeDir         # RIME 使用者資料夾（預設讀小狼毫的設定）
)

$ErrorActionPreference = 'Stop'
try { $Host.UI.RawUI.WindowTitle = 'RIME 更新設定' } catch { }

function Fail-Exit ([string]$msg) {
    Write-Host ''
    Write-Host "✗ $msg" -ForegroundColor Red
    Write-Host ''
    if (-not $NoPause) { Read-Host '按 Enter 關閉…' | Out-Null }
    exit 1
}

Write-Host '════════ RIME 更新設定 ════════'
Write-Host ''

# 來源＝這支腳本所在的 repo
$Repo = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $Repo 'rime'))) { Fail-Exit "$Repo 裡找不到 rime\ 資料夾" }

# 目標＝RIME 使用者資料夾。不寫死：預設是 %APPDATA%\Rime，但可以在小狼毫設定裡改到別處。
if (-not $RimeDir) {
    $r = Get-ItemProperty 'HKCU:\Software\Rime\Weasel' -ErrorAction SilentlyContinue
    if ($r -and $r.RimeUserDir) { $RimeDir = $r.RimeUserDir } else { $RimeDir = Join-Path $env:APPDATA 'Rime' }
}

# 防呆：WeaselDeployer 只會部署「小狼毫設定的那個資料夾」。目標若是別的資料夾，
# 檔案會複製過去、卻去重啟一個跟它無關的輸入法 —— 多半是測試時指錯了，直接擋下。
if (-not $NoDeploy) {
    $r = Get-ItemProperty 'HKCU:\Software\Rime\Weasel' -ErrorAction SilentlyContinue
    $registered = Join-Path $env:APPDATA 'Rime'
    if ($r -and $r.RimeUserDir) { $registered = $r.RimeUserDir }
    if ([IO.Path]::GetFullPath($RimeDir).TrimEnd('\') -ine [IO.Path]::GetFullPath($registered).TrimEnd('\')) {
        Fail-Exit "目標 $RimeDir 不是小狼毫目前使用的資料夾（$registered）。只想複製檔案請加 -NoDeploy。"
    }
}

# 找小狼毫：先問登錄檔（同時裝了多個版本時，這才是「目前在用」的那個），
# 找不到再退回掃 Program Files\Rime\weasel-*（取版本最新的），不寫死版本號。
$server = $null; $deployer = $null; $WeaselRoot = $null
if (-not $NoDeploy) {
    foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Rime\Weasel', 'HKLM:\SOFTWARE\Rime\Weasel') {
        $r = Get-ItemProperty $k -ErrorAction SilentlyContinue
        if ($r -and $r.WeaselRoot -and (Test-Path (Join-Path $r.WeaselRoot 'WeaselServer.exe'))) { $WeaselRoot = $r.WeaselRoot; break }
    }
    if (-not $WeaselRoot) {
        $d = Get-ChildItem (Join-Path $env:ProgramFiles 'Rime') -Directory -Filter 'weasel-*' -ErrorAction SilentlyContinue |
             Sort-Object Name -Descending | Select-Object -First 1
        if ($d) { $WeaselRoot = $d.FullName }
    }
    if (-not $WeaselRoot) { Fail-Exit '找不到小狼毫安裝目錄。請先安裝：https://rime.im/download/' }
    $server   = Join-Path $WeaselRoot 'WeaselServer.exe'
    $deployer = Join-Path $WeaselRoot 'WeaselDeployer.exe'
}

# ── [1/4] 拉取 ────────────────────────────────────────────────────────
Write-Host '[1/4] 拉取最新設定…'
if ($SkipPull) {
    Write-Host '      （呼叫端已經處理，略過 git pull）'
} elseif (-not (Test-Path (Join-Path $Repo '.git'))) {
    Write-Host '      （這份設定不是 git clone 來的，略過 git pull）'
} else {
    git -C $Repo pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host '  常見原因：改過 repo 裡的檔案，或與遠端分岔（例如上游重寫過歷史）。' -ForegroundColor Yellow
        Write-Host "  看狀況：git -C `"$Repo`" status"
        Write-Host '  最簡單的解法：重跑 README 的安裝指令。'
        Fail-Exit 'git pull 失敗，沒有動到輸入法。'
    }
}

# ── [2/4] 套用到使用者資料夾 ──────────────────────────────────────────
Write-Host ''
Write-Host '[2/4] 套用到使用者資料夾…'
try { $applied = & (Join-Path $PSScriptRoot 'rime-apply.ps1') -RimeDir $RimeDir | Select-Object -Last 1 }
catch { Fail-Exit $_.Exception.Message }
$RimeDir = $applied.RimeDir

if ($NoDeploy) {
    Write-Host ''
    Write-Host '✓ 已套用檔案（-NoDeploy：沒有部署、沒有動輸入法服務）。' -ForegroundColor Green
    exit 0
}

$needDeploy  = $Force -or $applied.Build -gt 0 -or $applied.Removed -gt 0
$needRestart = $Force -or $applied.Lua -gt 0 -or $needDeploy

if (-not $needRestart) {
    Write-Host ''
    Write-Host '✓ 已是最新，沒有需要部署或重啟的變更。' -ForegroundColor Green
    Write-Host '  （要強制跑一輪：加上 -Force）'
    if ($CloseAfter -gt 0) { Start-Sleep -Seconds 2 }
    exit 0
}

Write-Host ("      需要部署：{0}；需要重啟：{1}" -f $(if ($needDeploy) { '是' } else { '否' }), $(if ($needRestart) { '是' } else { '否' }))
Write-Host ''

# ── [3/4] 停服務 → 部署 ───────────────────────────────────────────────
# 停在部署之前：部署是同步的，服務活著的話這段時間 IME 收鍵不回字＝看起來卡死。
if (Get-Process WeaselServer -ErrorAction SilentlyContinue) {
    Write-Host '[3/4] 停止 WeaselServer（/quit，不強殺）…'
    # 閒置時 /quit 約 100~200ms 就退出，但服務正在編譯（或剛啟動還在初始化）時
    # 會不理它 —— 實測遇過。所以重送幾次再考慮強殺，別一逾時就 -Force。
    $sw = [Diagnostics.Stopwatch]::StartNew()
    foreach ($attempt in 1..3) {
        & $server /quit
        $deadline = $sw.Elapsed.TotalSeconds + 5
        while ((Get-Process WeaselServer -ErrorAction SilentlyContinue) -and $sw.Elapsed.TotalSeconds -lt $deadline) {
            Start-Sleep -Milliseconds 100
        }
        if (-not (Get-Process WeaselServer -ErrorAction SilentlyContinue)) { break }
        Write-Host ("      第 {0} 次 /quit 沒反應（服務可能正在編譯），再試…" -f $attempt) -ForegroundColor DarkYellow
    }
    if (Get-Process WeaselServer -ErrorAction SilentlyContinue) {
        # 三次都不理才強殺。強殺會讓連線中的視窗卡在具名管線上，是最後手段。
        Write-Host '      仍未退出，改為強制結束（正在打字的視窗可能要重新點一下）' -ForegroundColor Yellow
        Stop-Process -Name WeaselServer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    } else {
        Write-Host ("      已退出（{0}ms）" -f [int]$sw.Elapsed.TotalMilliseconds)
    }
} else {
    Write-Host '[3/4] WeaselServer 沒在執行，略過停止。'
}

if ($needDeploy) {
    Write-Host '      部署中…（動到詞典的話會久一點，請等它跑完）'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    & $deployer /deploy
    $code = $LASTEXITCODE
    Write-Host ("      部署完成（{0:N1} 秒，exit={1}）" -f $sw.Elapsed.TotalSeconds, $code)
    if ($code -ne 0) {
        Write-Host '      ⚠ 部署回傳非 0，服務仍會啟動，但設定可能沒套用。' -ForegroundColor Yellow
        Write-Host '        看部署日誌：%TEMP%\rime.weasel.*.WARNING' -ForegroundColor Yellow
    }
} else {
    Write-Host '      只有 lua 變更，不需要部署（lua 在服務啟動時載入）。'
}
Write-Host ''

# ── [4/4] 啟動並確認 ──────────────────────────────────────────────────
Write-Host '[4/4] 啟動 WeaselServer…'
Start-Process $server
$sw = [Diagnostics.Stopwatch]::StartNew()
while (-not (Get-Process WeaselServer -ErrorAction SilentlyContinue) -and $sw.Elapsed.TotalSeconds -lt 10) {
    Start-Sleep -Milliseconds 100
}
$proc = Get-Process WeaselServer -ErrorAction SilentlyContinue
if (-not $proc) { Fail-Exit "WeaselServer 沒有起來。手動啟動：`"$server`"" }
Write-Host ("      已啟動（PID {0}）" -f $proc.Id)

# ⚠ 不能把「deployer 回傳」當成編譯完成：實測過它有時 0.0 秒就 exit 0，
#   真正的重編是啟動後的 WeaselServer 做的（build\ 在那之後才變動）。
#   所以這裡等 build\ 真的不再變動 —— 這段時間 IME 本來就還不能用，
#   與其讓使用者以為好了卻打不出字（那就是「卡死」的感覺），不如明講還在忙。
if ($needDeploy) {
    Write-Host '      等待編譯完成…'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $last = (Get-ChildItem "$RimeDir\build" -File -ErrorAction SilentlyContinue |
             Measure-Object LastWriteTime -Maximum).Maximum
    $stable = 0
    while ($sw.Elapsed.TotalSeconds -lt 180 -and $stable -lt 4) {
        Start-Sleep -Milliseconds 500
        $now = (Get-ChildItem "$RimeDir\build" -File -ErrorAction SilentlyContinue |
                Measure-Object LastWriteTime -Maximum).Maximum
        if ($now -ne $last) { $last = $now; $stable = 0 } else { $stable++ }
    }
    if ($stable -ge 4) {
        Write-Host ("      build 已穩定（{0:N1} 秒）" -f $sw.Elapsed.TotalSeconds)
    } else {
        Write-Host '      ⚠ 180 秒後 build 仍在變動，可能是大型詞典首次編譯，請再等一下。' -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host "✓ 完成（使用 $(Split-Path $WeaselRoot -Leaf)）。" -ForegroundColor Green
if ($applied.Lua) { Write-Host ("  lua 變更 {0} 個，已隨重啟生效。" -f $applied.Lua) }
if ($CloseAfter -gt 0) {
    Write-Host ''
    Write-Host "  ${CloseAfter} 秒後自動關閉（Ctrl+C 可留下視窗）…"
    Start-Sleep -Seconds $CloseAfter
}
exit 0
