# rime-sync.ps1 — Windows（小狼毫）設定同步【維護者／fork 擁有者用】
# 會 commit 並 push 到 origin，所以只有對 origin 有寫入權限的人才用得到；
# 一般使用者要更新請在輸入法內打 '/git（那支只拉不推）。
#
# 流程：git pull --rebase → 套用到使用者資料夾（有變動才部署／重啟）→ git commit + push
# 在 repo 裡改設定（rime\ 底下），改完跑這支，就會套用到這台並推上去。
# 打字紀錄與個人檔（詞頻、個人短語、安裝選項）在使用者資料夾，不在 repo 裡，不會被推。
# 用法：pwsh scripts\rime-sync.ps1
#
# ⚠ 本檔存成 UTF-8 含 BOM（Windows PowerShell 5.1 相容，見 docs\GOTCHAS.md）。

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

Write-Host '[1/3] git pull...' -ForegroundColor Cyan
git pull --rebase --autostash origin main
if ($LASTEXITCODE -ne 0) { Write-Host 'git pull 失敗，請先處理衝突。' -ForegroundColor Red; exit 1 }

# 套用＋（必要時）部署重啟，邏輯只有一份，在 rime-update.ps1。
#   -SkipPull：上面已經 pull 過（而且是 --rebase；rime-update 的 --ff-only 在分岔時會失敗）
#   -NoPause ：失敗別停在 Read-Host 卡住這支
#   沒有檔案變動時它會自己判斷不動輸入法。
Write-Host '[2/3] 套用到使用者資料夾...' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'rime-update.ps1') -SkipPull -NoPause -CloseAfter 0
if ($LASTEXITCODE -ne 0) { Write-Host '套用失敗，先不推送。' -ForegroundColor Red; exit 1 }

Write-Host '[3/3] git commit / push...' -ForegroundColor Cyan
git add -A
if (git status --porcelain) {
    git commit -m "config: windows $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git push origin main
    Write-Host '完成：已推送本機設定變更。' -ForegroundColor Green
} else {
    Write-Host '完成：無變更需要推送。' -ForegroundColor Green
}
