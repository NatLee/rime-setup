#!/usr/bin/env bash
# PostToolUse hook：修改 lua 檔後提醒必須重啟輸入法服務
#
# 為什麼需要：lua 只在服務程序啟動時載入一次，「重新部署」只重編 yaml/詞典，
# 不會重讀 lua。只部署不重啟＝改動看不見（見 docs/GOTCHAS.md）。
#
# 跨平台：Windows 走 Git Bash、macOS 走系統 bash，同一份腳本。
# settings.json 以 "shell": "bash" 明確指定，不依賴平台預設。
#
# 刻意不依賴 jq（Windows Git Bash 預設沒有），用 sed 從 stdin JSON 抓 file_path。

set -u

raw="$(cat)"
[ -n "$raw" ] || exit 0

# tool_input.file_path，抓不到就退而找 tool_response 裡的 filePath
path="$(printf '%s' "$raw" \
  | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$path" ] || path="$(printf '%s' "$raw" \
  | sed -n 's/.*"filePath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"

case "$path" in
  *.lua) ;;
  *) exit 0 ;;
esac

name="${path##*[/\\]}"

case "$(uname -s 2>/dev/null)" in
  Darwin)
    restart='"/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" --reload'
    test_hint='Mac 沒有沙盒回歸工具，請推到 Windows 那台跑 rime-test.ps1，或在 Mac 實機驗證。'
    ;;
  MINGW*|MSYS*|CYGWIN*)
    restart="Stop-Process -Name WeaselServer -Force; Start-Process 'C:\\Program Files\\Rime\\weasel-0.17.4\\WeaselServer.exe'"
    test_hint='上線前跑回歸測試（23 條黃金樣本須全 PASS）：pwsh tools\rime-test.ps1 -Sync -Mode basic'
    ;;
  *)
    restart='重啟你平台上的 RIME 服務程序'
    test_hint='上線前請跑回歸測試。'
    ;;
esac

msg="已修改 lua 檔（${name}）。提醒兩件事：
1. lua 只在服務啟動時載入一次，「重新部署」不會重讀 —— 變更要生效必須重啟：
   ${restart}
2. ${test_hint}"

# 逐字跳脫成 JSON 字串
json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'BEGIN{ORS=""} {print (NR>1 ? "\\n" : "") $0}'
}
esc="$(json_escape "$msg")"

# 同時輸出兩種形狀：不同版本的 Claude Code 分別認得其中一種，多餘的鍵會被忽略。
printf '{"additionalContext":"%s","hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}' "$esc" "$esc"
exit 0
