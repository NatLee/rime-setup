# PostToolUse hook：修改 lua 檔後提醒必須重啟 WeaselServer
# lua 只在 WeaselServer 程序啟動時載入一次，「重新部署」不會重讀 lua。
$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }

$path = $j.tool_input.file_path
if (-not $path) { $path = $j.tool_response.filePath }
if (-not $path -or $path -notmatch '\.lua$') { exit 0 }

$name = Split-Path $path -Leaf
$msg = @"
已修改 lua 檔（$name）。提醒兩件事：
1. lua 只在 WeaselServer 啟動時載入一次，「重新部署」不會重讀 —— 變更要生效必須重啟：
   Stop-Process -Name WeaselServer -Force; Start-Process 'C:\Program Files\Rime\weasel-0.17.4\WeaselServer.exe'
2. 上線前跑回歸測試（23 條黃金樣本須全 PASS）：
   pwsh tools\rime-test.ps1 -Sync -Mode basic
"@

@{ hookSpecificOutput = @{ hookEventName = 'PostToolUse'; additionalContext = $msg } } |
  ConvertTo-Json -Compress
exit 0
