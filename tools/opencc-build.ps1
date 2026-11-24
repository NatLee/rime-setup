<#
.SYNOPSIS
  把 rime/opencc/*.txt（文字格式的 OpenCC 字典）編成 .ocd2 二進位字典。

.DESCRIPTION
  文字格式的字典每次載入方案都要整份重新解析；最大的那個（字集過濾用，五萬五千行）
  光這一步就要 30 毫秒以上，而且每切一次方案、每開一個新視窗都要再付一次。
  .ocd2 是 OpenCC 自己的二進位格式（marisa trie），載入幾乎不花時間。

  .ocd2 直接提交進 repo，一般使用者不需要跑這支；只有改了 rime/opencc/*.txt 之後才要重編。
  *.json 設定檔指向的是 .ocd2，所以**改了 .txt 沒重編，輸入法看到的還是舊內容**。

  轉檔用的是 OpenCC 官方的 opencc_dict。小狼毫沒有附這個工具，Windows 上也沒有現成的
  執行檔，所以借 Docker 開一個 Debian 容器來跑（apt 裝 opencc 套件）。

.EXAMPLE
  pwsh tools\opencc-build.ps1            # 重編全部
  pwsh tools\opencc-build.ps1 -Check     # 只檢查 .ocd2 有沒有比 .txt 舊，不動檔案

.NOTES
  需要 Docker Desktop（或任何能跑 linux 容器的 docker）。第一次會下載 debian 映像與 opencc 套件。
#>
[CmdletBinding()]
param(
  [string]$Repo = (Split-Path $PSScriptRoot -Parent),
  [switch]$Check
)
$ErrorActionPreference = 'Stop'
$dir = Join-Path $Repo 'rime\opencc'
$txts = @(Get-ChildItem $dir -Filter *.txt | Sort-Object Name)
if (-not $txts.Count) { throw "$dir 裡沒有 .txt 字典" }

if ($Check) {
  $stale = 0
  foreach ($t in $txts) {
    $o = Join-Path $dir ($t.BaseName + '.ocd2')
    if (-not (Test-Path $o)) { Write-Host "缺少 $($t.BaseName).ocd2" -ForegroundColor Red; $stale++ }
    elseif ((Get-Item $o).LastWriteTimeUtc -lt $t.LastWriteTimeUtc) { Write-Host "$($t.BaseName).ocd2 比 .txt 舊" -ForegroundColor Yellow; $stale++ }
  }
  if ($stale) { Write-Host '→ 請跑 pwsh tools\opencc-build.ps1 重編' ; exit 1 }
  Write-Host '全部 .ocd2 都是新的。' -ForegroundColor Green; exit 0
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw '找不到 docker。請先安裝並啟動 Docker Desktop。' }

# 容器裡做的事：裝 opencc → 每個 .txt 轉一個同名 .ocd2
$script = @'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null
apt-get install -y -qq --no-install-recommends opencc >/dev/null
cd /work
for f in *.txt; do
  opencc_dict -i "$f" -o "${f%.txt}.ocd2" -f text -t ocd2
  echo "  $f -> ${f%.txt}.ocd2 ($(wc -c < "${f%.txt}.ocd2") bytes)"
done
opencc --version 2>/dev/null | head -1 || true
'@ -replace "`r`n", "`n"

Write-Host "用 Docker 編譯 $($txts.Count) 個字典…（第一次要下載映像，會久一點）"
$script | docker run --rm -i -v "${dir}:/work" debian:stable-slim bash -s
if ($LASTEXITCODE -ne 0) { throw "docker 執行失敗（exit $LASTEXITCODE）" }

foreach ($t in $txts) {
  $o = Join-Path $dir ($t.BaseName + '.ocd2')
  if (-not (Test-Path $o) -or (Get-Item $o).Length -eq 0) { throw "沒有產生 $($t.BaseName).ocd2" }
}
Write-Host '完成。記得跑回歸與快照，確認轉換結果跟文字版一字不差：' -ForegroundColor Green
Write-Host '  pwsh tools\rime-test.ps1 -Sync -Mode basic'
