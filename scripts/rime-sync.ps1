# rime-sync.ps1 — Windows（小狼毫）設定同步
# 只同步「設定檔」：git pull → 重新部署 → git commit/push
# 打字紀錄（詞頻資料庫）不進版控，各機器獨立。
# 用法：pwsh scripts/rime-sync.ps1

$ErrorActionPreference = 'Stop'
$RimeDir = Split-Path $PSScriptRoot -Parent
Set-Location $RimeDir


Write-Host '[1/3] git pull...' -ForegroundColor Cyan
$before = (git rev-parse HEAD).Trim()
git pull --rebase origin main
$after = (git rev-parse HEAD).Trim()
$changed = if ($before -ne $after) { git diff --name-only $before $after } else { @() }
$luaChanged   = @($changed | Where-Object { $_ -match '\.lua$' })
$buildChanged = @($changed | Where-Object { $_ -match '\.(yaml|txt|gram|json)$' -or $_ -match '^opencc/' })

# 套用遠端設定。與 rime-update.ps1 同一套作法，理由見那支腳本開頭：
#   ‧ 沒拉到相關變更就完全不動輸入法（以前不管有沒有變更都部署＋等 20 秒）
#   ‧ 先 /quit 停服務再部署 —— 部署是同步的，服務活著時 IME 收鍵不回字＝像卡死
#   ‧ /quit 不用 Stop-Process -Force —— 強殺會讓正在打字的視窗卡在具名管線上
if ($luaChanged.Count -or $buildChanged.Count) {
    Write-Host '[2/3] 套用遠端設定...' -ForegroundColor Cyan
    # -SkipPull：上面已經 pull 過（而且是 --rebase，rime-update 的 --ff-only 在
    #            本機有未提交變更時會失敗）。-NoPause：失敗別停在 Read-Host 卡住這支。
    & (Join-Path $RimeDir 'scripts\rime-update.ps1') -Force -SkipPull -NoPause -CloseAfter 0
} else {
    Write-Host '[2/3] 沒有設定變更，略過部署與重啟。' -ForegroundColor Cyan
}

Write-Host '[3/3] git commit / push...' -ForegroundColor Cyan
git add -A
if (git status --porcelain) {
    git commit -m "config: natlee-windows $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git push origin main
    Write-Host '完成：已推送本機設定變更。' -ForegroundColor Green
} else {
    Write-Host '完成：無變更需要推送。' -ForegroundColor Green
}
