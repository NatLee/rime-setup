# rime-sync.ps1 — Windows（小狼毫）設定同步
# 只同步「設定檔」：git pull → 重新部署 → git commit/push
# 打字紀錄（詞頻資料庫）不進版控，各機器獨立。
# 用法：pwsh scripts/rime-sync.ps1

$ErrorActionPreference = 'Stop'
$RimeDir = Split-Path $PSScriptRoot -Parent
Set-Location $RimeDir

# 找到小狼毫安裝路徑
$weaselRoot = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Rime\Weasel' -ErrorAction SilentlyContinue).WeaselRoot
if (-not $weaselRoot) { $weaselRoot = (Get-ItemProperty 'HKLM:\SOFTWARE\Rime\Weasel').WeaselRoot }
$deployer = Join-Path $weaselRoot 'WeaselDeployer.exe'

Write-Host '[1/3] git pull...' -ForegroundColor Cyan
git pull --rebase origin main

Write-Host '[2/3] 重新部署（套用遠端設定）...' -ForegroundColor Cyan
& $deployer /deploy
Start-Sleep -Seconds 20

Write-Host '[3/3] git commit / push...' -ForegroundColor Cyan
git add -A
if (git status --porcelain) {
    git commit -m "config: natlee-windows $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git push origin main
    Write-Host '完成：已推送本機設定變更。' -ForegroundColor Green
} else {
    Write-Host '完成：無變更需要推送。' -ForegroundColor Green
}
