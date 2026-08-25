# rime-update.ps1 — Windows：拉取遠端設定 → 部署 → 重啟 WeaselServer
#
# 由輸入法內打 '/git ＋空白鍵觸發（見 lua/p_components/p_run_pattern.lua）。
# 以 `start "" pwsh -NoExit -File ...` 開新主控台視窗執行，看得到過程。
#
# 為什麼要重啟服務：lua 只在 WeaselServer 啟動時載入一次，
# 「部署」只重編 yaml/詞典，不會重讀 lua（見 docs/GOTCHAS.md）。

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'RIME 更新設定'

function Pause-Exit ([int]$code = 0) {
    Write-Host ''
    Read-Host '按 Enter 關閉…' | Out-Null
    exit $code
}

Write-Host '════════ RIME 更新設定 ════════'
Write-Host ''

$RimeDir = 'C:\RIME'
if (-not (Test-Path $RimeDir)) { Write-Host "✗ 找不到 $RimeDir" ; Pause-Exit 1 }

# 自動找目前安裝的小狼毫版本，不寫死 0.17.4
$WeaselDir = Get-ChildItem 'C:\Program Files\Rime' -Directory -Filter 'weasel-*' -ErrorAction SilentlyContinue |
             Sort-Object Name -Descending | Select-Object -First 1
if (-not $WeaselDir) { Write-Host '✗ 找不到小狼毫安裝目錄（C:\Program Files\Rime\weasel-*）'; Pause-Exit 1 }

Set-Location $RimeDir

Write-Host '[1/3] 拉取遠端設定…'
git pull --ff-only
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host '✗ git pull 失敗。'
    Write-Host '  常見原因：本機有未提交的變更，或與遠端分岔。'
    Write-Host "  先看看狀況：git -C `"$RimeDir`" status"
    Write-Host "  想同步本機變更請改跑：pwsh `"$RimeDir\scripts\rime-sync.ps1`""
    Pause-Exit 1
}
Write-Host ''

Write-Host '[2/3] 部署…'
& (Join-Path $WeaselDir.FullName 'WeaselDeployer.exe') /deploy
Write-Host ''

Write-Host '[3/3] 重啟 WeaselServer（讓 lua 變更生效）…'
Stop-Process -Name WeaselServer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Start-Process (Join-Path $WeaselDir.FullName 'WeaselServer.exe')
Write-Host ''

Write-Host "✓ 完成（使用 $($WeaselDir.Name)）。"
Write-Host '  若剛才有詞典變更，首次編譯可能還要跑一兩分鐘。'
Pause-Exit 0
