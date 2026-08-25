# rime-update.ps1 — Windows：拉取遠端設定 →（必要時）部署 →（必要時）重啟服務
#
# 由輸入法內打 '/git ＋空白鍵觸發（見 lua/p_components/p_run_pattern.lua）。
# 以 `start "" pwsh -NoExit -File ...` 開新主控台視窗執行，看得到過程。
# rime-sync.ps1 也會呼叫這支（加 -SkipPull -NoPause），套用設定只有一份邏輯。
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
#    以前不管 git pull 有沒有拉到東西都照樣部署＋重啟 —— 光是「確認一下有沒有
#    更新」就要付十幾秒的 IME 中斷。現在比對 pull 前後的 HEAD：
#      沒變更        → 直接結束（實測 2 秒，完全不動 IME）
#      只有 .lua     → 只重啟（lua 只在服務啟動時載入，部署不會重讀）
#      有 yaml/詞典  → 部署＋重啟
#    要強制跑一輪：pwsh rime-update.ps1 -Force
#
# ④ 成功自己關視窗，失敗才停下來等人看
#    這個視窗是 WeaselServer 透過 os.execute 開出來的，留著不關很煩。

[CmdletBinding()]
param(
    [switch]$Force,          # 沒有變更也強制部署＋重啟
    [switch]$SkipPull,       # 不自己 git pull（給已經拉過的呼叫端，如 rime-sync.ps1）
    [switch]$NoPause,        # 失敗時不要等 Enter（被其他腳本呼叫時必加，否則會卡住對方）
    [int]$CloseAfter = 5     # 成功後幾秒自動關閉（0 = 不自動關）
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

$RimeDir = 'C:\RIME'
if (-not (Test-Path $RimeDir)) { Fail-Exit "找不到 $RimeDir" }

# 自動找目前安裝的小狼毫版本，不寫死 0.17.4
$WeaselDir = Get-ChildItem 'C:\Program Files\Rime' -Directory -Filter 'weasel-*' -ErrorAction SilentlyContinue |
             Sort-Object Name -Descending | Select-Object -First 1
if (-not $WeaselDir) { Fail-Exit '找不到小狼毫安裝目錄（C:\Program Files\Rime\weasel-*）' }
$server   = Join-Path $WeaselDir.FullName 'WeaselServer.exe'
$deployer = Join-Path $WeaselDir.FullName 'WeaselDeployer.exe'

Set-Location $RimeDir

# ── [1/3] 拉取 ────────────────────────────────────────────────────────
Write-Host '[1/3] 拉取遠端設定…'
$before = (git rev-parse HEAD).Trim()
if ($SkipPull) {
    Write-Host '      （呼叫端已經拉過，略過 git pull）'
} else {
    git pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host '  常見原因：本機有未提交的變更，或與遠端分岔。' -ForegroundColor Yellow
        Write-Host "  看狀況：git -C `"$RimeDir`" status"
        Write-Host "  想同步本機變更請改跑：pwsh `"$RimeDir\scripts\rime-sync.ps1`""
        Fail-Exit 'git pull 失敗，沒有動到輸入法。'
    }
}
$after = (git rev-parse HEAD).Trim()

# ── 判斷要做什麼 ──────────────────────────────────────────────────────
$changed = if ($before -ne $after) { @(git diff --name-only $before $after) } else { @() }
$luaChanged   = @($changed | Where-Object { $_ -match '\.lua$' })
# 會進 build\ 的：方案／設定 yaml、詞典、短語 txt、語言模型、opencc 對照表
$buildChanged = @($changed | Where-Object { $_ -match '\.(yaml|txt|gram|json)$' -or $_ -match '^opencc/' })

$needDeploy  = $Force -or $buildChanged.Count -gt 0
$needRestart = $Force -or $luaChanged.Count -gt 0 -or $needDeploy

if (-not $needRestart) {
    Write-Host ''
    if ($changed.Count) {
        Write-Host ("✓ 拉到 {0} 個檔案，但都不影響輸入法（文件／腳本之類），不用重啟。" -f $changed.Count) -ForegroundColor Green
    } else {
        Write-Host '✓ 已是最新，沒有需要部署或重啟的變更。' -ForegroundColor Green
    }
    Write-Host '  （要強制跑一輪：加上 -Force）'
    if ($CloseAfter -gt 0) { Start-Sleep -Seconds 2 }
    exit 0
}

Write-Host ''
Write-Host ("      變更 {0} 個檔案；需要部署：{1}；需要重啟：{2}" -f `
            $changed.Count, $(if ($needDeploy) { '是' } else { '否' }), $(if ($needRestart) { '是' } else { '否' }))
Write-Host ''

# ── [2/3] 停服務 → 部署 ───────────────────────────────────────────────
# 停在部署之前：部署是同步的，服務活著的話這段時間 IME 收鍵不回字＝看起來卡死。
if (Get-Process WeaselServer -ErrorAction SilentlyContinue) {
    Write-Host '[2/3] 停止 WeaselServer（/quit，不強殺）…'
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
    Write-Host '[2/3] WeaselServer 沒在執行，略過停止。'
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

# ── [3/3] 啟動並確認 ──────────────────────────────────────────────────
Write-Host '[3/3] 啟動 WeaselServer…'
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
Write-Host "✓ 完成（使用 $($WeaselDir.Name)）。" -ForegroundColor Green
if ($luaChanged.Count) { Write-Host ("  lua 變更 {0} 個，已隨重啟生效。" -f $luaChanged.Count) }
if ($CloseAfter -gt 0) {
    Write-Host ''
    Write-Host "  ${CloseAfter} 秒後自動關閉（Ctrl+C 可留下視窗）…"
    Start-Sleep -Seconds $CloseAfter
}
exit 0
