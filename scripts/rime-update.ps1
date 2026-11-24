# rime-update.ps1 — Windows：拉取最新設定 → 套用到使用者資料夾 →（必要時）部署／重啟
#
# 由輸入法內打 '/git ＋空白鍵觸發：lua 開使用者資料夾裡的 na-update.cmd，
# 它轉給 repo 的 scripts\rime-update.cmd，後者挑 pwsh 或 powershell 來跑這支。
# 安裝腳本 install.ps1 最後一步也是呼叫這支（-SkipPull；第一次安裝加 -Force，只改選項加 -Deploy）。
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
# ① 部署時服務要「活著而且就緒」，絕對不要先把服務停掉
#    小狼毫自己的「重新部署」就是這樣做的：部署器先通知服務進入維護模式，
#    編譯完再通知它恢復。這是唯一安全的順序。
#    這支腳本以前是「先 /quit 停服務 → 部署 → 啟動」，想讓中斷期間乾淨一點，結果出過兩次事：
#    服務一消失，任何開著輸入法的程式都會自動把它叫回來；叫回來的時機如果撞上部署器
#    剛啟動，兩邊互等（部署器 CPU 停在 0），所有用到輸入法的程式跟著沒有回應。
#    第一次以為是腳本自己太早啟動服務（`& $deployer` 對視窗程式不會等待，確實也是錯），
#    修掉之後又發生一次，才確定問題在「先停服務」這個設計本身。
#    代價：部署期間輸入法暫時不能用（維護模式），但其他程式不會被拖住。
#
# ② 重啟服務放在部署器「結束之後」，而且用 /quit 不用強殺
#    lua 只在服務啟動時載入，部署不會重讀，所以 lua 有變還是得重啟一次 ——
#    但那時部署器已經不在了，停、啟都安全。
#    強殺會讓正在連線的應用程式卡在具名管線上，/quit 是官方開關，約 0.2 秒乾淨退出。
#
#    保險：部署器啟動 20 秒仍完全不吃 CPU 就是互鎖了，腳本會把它結束並把服務重新叫起來，
#    不會讓整台電腦的輸入法一直卡著。
#
# ③ 沒變更就什麼都不做
#    以「套用時實際有沒有檔案被改到」為準（rime-apply.ps1 的回傳值）：
#      沒有檔案變動  → 直接結束（完全不動 IME）
#      只有 .lua     → 只重啟（lua 只在服務啟動時載入，部署不會重讀）
#      有 yaml/詞典  → 部署（服務保持運作；lua 也有變才另外重啟）
#    要強制跑一輪：加 -Force
#
# ④ 成功自己關視窗，失敗才停下來等人看
#    這個視窗是 WeaselServer 透過 os.execute 開出來的，留著不關很煩。

[CmdletBinding()]
param(
    [switch]$Force,          # 沒有變更也強制部署＋重啟
    [switch]$Deploy,         # 一定要部署，但不為此重啟服務（個人選項檔變了：那些檔不是這支複製的，它看不到）
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

$needDeploy  = $Force -or $Deploy -or $applied.Build -gt 0 -or $applied.Removed -gt 0
# 重啟只為了 lua：服務活著時部署，部署器結束會通知服務重新載入設定（yaml 的變更就生效了），
# 但 lua 只在服務行程啟動時載入一次，所以 lua 有變才需要真的重啟。
$needRestart = $Force -or $applied.Lua -gt 0

if (-not ($needDeploy -or $needRestart)) {
    Write-Host ''
    Write-Host '✓ 已是最新，沒有需要部署或重啟的變更。' -ForegroundColor Green
    Write-Host '  （要強制跑一輪：加上 -Force）'
    if ($CloseAfter -gt 0) { Start-Sleep -Seconds 2 }
    exit 0
}

Write-Host ("      需要部署：{0}；需要重啟：{1}" -f $(if ($needDeploy) { '是' } else { '否' }), $(if ($needRestart) { '是' } else { '否' }))
Write-Host ''

# ── 共用：服務的狀態與啟停 ────────────────────────────────────────────
function Test-ServerRunning { [bool](Get-Process WeaselServer -ErrorAction SilentlyContinue) }

# 服務「就緒」的判準：行程存在，而且已經活過啟動那一小段。
# 行程剛起來、還在初始化的時候去跑部署器，就是會互鎖的時機，所以剛啟動的服務要等它安靜下來
# （CPU 時間連續一秒不再增加＝方案載完了）；本來就在跑的服務不用等。
function Wait-ServerReady {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 20) {
        $p = Get-Process WeaselServer -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $p) { Start-Sleep -Milliseconds 200; continue }
        if (((Get-Date) - $p.StartTime).TotalSeconds -ge 5) { return $true }   # 早就在跑了
        $cpu1 = $p.TotalProcessorTime.TotalMilliseconds
        Start-Sleep -Milliseconds 1000
        $p.Refresh()
        if ($p.HasExited) { continue }
        if (($p.TotalProcessorTime.TotalMilliseconds - $cpu1) -lt 15 -and ((Get-Date) - $p.StartTime).TotalSeconds -ge 2) { return $true }
    }
    return (Test-ServerRunning)
}

# 等服務「閒下來」：CPU 時間連續 1.5 秒沒有增加，最多等 30 秒。
function Wait-ServerIdle {
    Start-Sleep -Seconds 2
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30) {
        $p = Get-Process WeaselServer -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $p) { return }
        $cpu1 = $p.TotalProcessorTime.TotalMilliseconds
        Start-Sleep -Milliseconds 1500
        $p.Refresh()
        if ($p.HasExited -or ($p.TotalProcessorTime.TotalMilliseconds - $cpu1) -lt 15) { return }
    }
}

function Start-Server {
    if (-not (Test-ServerRunning)) { Start-Process $server }
    return (Wait-ServerReady)
}
function Stop-Server {
    if (-not (Test-ServerRunning)) { return }
    # 用官方的 /quit，不要一開始就強殺：強殺會讓正在連線的視窗卡在具名管線上。
    # 閒置時 /quit 約 100~200ms 就退出，但服務正在忙時會不理它，所以重送幾次再考慮強殺。
    $sw = [Diagnostics.Stopwatch]::StartNew()
    foreach ($attempt in 1..3) {
        # ⚠ 不可以用 Start-Process -ArgumentList '/quit'：Windows PowerShell 5.1 組出來的命令列
        #   結尾會多一個空白（"…WeaselServer.exe" /quit␠），小狼毫是整串比對，認不出這是 /quit，
        #   於是把它當成「啟動一個新的服務」—— 新的把舊的擠掉自己留下來，看起來就像 /quit 沒反應，
        #   連送三次都一樣，最後落到強殺。用 .NET 直接給參數就沒有這個問題。
        [void][Diagnostics.Process]::Start($server, '/quit')
        $deadline = $sw.Elapsed.TotalSeconds + 8
        while ((Test-ServerRunning) -and $sw.Elapsed.TotalSeconds -lt $deadline) { Start-Sleep -Milliseconds 100 }
        if (-not (Test-ServerRunning)) { return }
        Write-Host ("      第 {0} 次 /quit 沒反應，再試…" -f $attempt) -ForegroundColor DarkYellow
    }
    Write-Host '      仍未退出，改為強制結束（正在打字的視窗可能要重新點一下）' -ForegroundColor Yellow
    Stop-Process -Name WeaselServer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

# ── [3/4] 部署（服務保持運作）────────────────────────────────────────
if ($needDeploy) {
    Write-Host '[3/4] 部署…'
    # 已經有部署在跑（例如使用者剛從工作列按了「重新部署」）就等它，不要再開一個
    $other = Get-Process WeaselDeployer -ErrorAction SilentlyContinue
    if ($other) {
        Write-Host '      已經有一個部署在執行，等它結束…'
        $other | ForEach-Object { [void]$_.WaitForExit(600000) }
        if (Get-Process WeaselDeployer -ErrorAction SilentlyContinue) {
            Fail-Exit '另一個 WeaselDeployer 十分鐘後仍在執行（可能卡住了）。請在工作管理員結束它之後再試。'
        }
    }

    # 部署前確定服務「已經在跑而且就緒」。沒在跑就先把它叫起來、等它就緒。
    # 不這樣做的話，部署到一半會有別的程式把服務叫起來，而且正好叫在最糟的時機。
    if (-not (Start-Server)) { Fail-Exit "WeaselServer 沒有起來，不敢在沒有服務的狀態下部署。手動啟動：`"$server`"" }

    Write-Host '      部署中…期間輸入法暫時不能用（動到詞典的話要重新編譯，可能要好幾分鐘）'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    # ⚠ 一定要 Start-Process 拿到行程再等它結束，不可以寫成 `& $deployer /deploy`：
    #   WeaselDeployer.exe 是視窗程式，PowerShell 的 & 對視窗程式不會等待。
    #   參數用 .NET 直接給，理由同 /quit（5.1 的 Start-Process 會在命令列尾端多一個空白）。
    $proc = [Diagnostics.Process]::Start($deployer, '/deploy')
    $nextNote = 15
    while (-not $proc.WaitForExit(1000)) {
        if ($sw.Elapsed.TotalSeconds -ge $nextNote) {
            Write-Host ("      …還在編譯（已 {0:N0} 秒）" -f $sw.Elapsed.TotalSeconds)
            $nextNote += 30
        }
        # 互鎖的特徵：部署器起來了卻完全不吃 CPU。正常的部署一開始就會用到 CPU。
        # 真的發生就把它結束掉 —— 留著的話，所有開著輸入法的程式都會跟著沒有回應。
        if ($sw.Elapsed.TotalSeconds -ge 20 -and $proc.TotalProcessorTime.TotalSeconds -lt 0.2) {
            Write-Host '      ✗ 部署器啟動 20 秒仍沒有任何進展，判定為卡住，把它結束。' -ForegroundColor Red
            try { $proc.Kill() } catch { }
            Stop-Process -Name WeaselServer -Force -ErrorAction SilentlyContinue   # 被它拖住的服務也重來
            Start-Sleep -Seconds 1
            [void](Start-Server)
            Fail-Exit '部署沒有完成，已把輸入法服務重新啟動（設定仍是更新前的）。請稍後再打 ''/git 試一次，或從開始功能表按「重新部署」。'
        }
        if ($sw.Elapsed.TotalMinutes -ge 20) {
            Fail-Exit '部署超過 20 分鐘還沒結束。請在工作管理員確認 WeaselDeployer 的狀態。'
        }
    }
    $code = $proc.ExitCode
    Write-Host ("      部署完成（{0:N1} 秒，exit={1}）" -f $sw.Elapsed.TotalSeconds, $code)
    if ($code -ne 0) {
        Write-Host '      ⚠ 部署回傳非 0，設定可能沒套用。' -ForegroundColor Yellow
        Write-Host '        看部署日誌：%TEMP%\rime.weasel\*.WARNING' -ForegroundColor Yellow
    }
} else {
    Write-Host '[3/4] 只有 lua 變更，不需要部署（lua 在服務啟動時載入）。'
}
Write-Host ''

# ── [4/4] 重啟服務（部署器已經結束，這時候停、啟都安全）──────────────
if ($needRestart) {
    Write-Host '[4/4] 重啟 WeaselServer（讓 lua 的變更生效）…'
    # 部署器剛通知服務「恢復」，服務正在重新載入設定；這時候送 /quit 它會不理
    # （實測連送三次、等了 15 秒都沒退出，最後只能強殺）。等它安靜下來再送就是 0.1 秒的事。
    if ($needDeploy) { Wait-ServerIdle }
    Stop-Server
    if (-not (Start-Server)) { Fail-Exit "WeaselServer 沒有起來。手動啟動：`"$server`"" }
    $srv = Get-Process WeaselServer -ErrorAction SilentlyContinue | Select-Object -First 1
    Write-Host ("      已啟動（PID {0}）" -f $srv.Id)
} else {
    Write-Host '[4/4] 沒有 lua 變更，不需要重啟服務（設定已由部署器通知服務重新載入）。'
    if (-not (Test-ServerRunning)) { [void](Start-Server) }
}

Write-Host ''
Write-Host "✓ 完成（使用 $(Split-Path $WeaselRoot -Leaf)）。" -ForegroundColor Green
if ($applied.Lua) { Write-Host ("  lua 變更 {0} 個，已隨重啟生效。" -f $applied.Lua) }
if ($CloseAfter -gt 0) {
    Write-Host ''
    # 想留下視窗看訊息：按任意鍵就好（以前要按 Ctrl+C，那會連腳本一起中斷、視窗反而關掉）。
    Write-Host "  ${CloseAfter} 秒後自動關閉（按任意鍵可留下視窗）…"
    $deadline = (Get-Date).AddSeconds($CloseAfter)
    while ((Get-Date) -lt $deadline) {
        $pressed = $false
        try { $pressed = [Console]::KeyAvailable } catch { }   # 輸入被重導向時會丟例外：那就單純等到時間到
        if ($pressed) {
            [void][Console]::ReadKey($true)
            Read-Host '  已留下視窗，按 Enter 關閉…' | Out-Null
            break
        }
        Start-Sleep -Milliseconds 100
    }
}
exit 0
