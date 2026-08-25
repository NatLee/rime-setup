#!/bin/bash
# rime-update.command — macOS：拉取遠端設定 → 重新部署（含重載 lua）
#
# 由輸入法內打 '/git ＋空白鍵觸發（見 lua/p_components/p_run_pattern.lua）。
# 副檔名用 .command 是為了讓 `open` 直接在「終端機」開一個視窗跑，看得到過程。
# 需要可執行權限；git 已記錄 755，clone 下來就有。
#
# ⚠ macOS 內建 bash 3.2：`$VAR` 後面緊接中文會被吃進變數名，一律寫 ${VAR}。

RIME_DIR="$HOME/Library/Rime"
SQUIRREL="/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"

printf '\033]0;RIME 更新設定\007'   # 設定終端機視窗標題
echo "════════ RIME 更新設定 ════════"
echo

cd "$RIME_DIR" || { echo "✗ 找不到 ${RIME_DIR}"; echo; read -r -p "按 Enter 關閉…"; exit 1; }

echo "[1/2] 拉取遠端設定…"
if ! git pull --ff-only; then
    echo
    echo "✗ git pull 失敗。"
    echo "  常見原因：本機有未提交的變更，或與遠端分岔。"
    echo "  先看看狀況：git -C \"${RIME_DIR}\" status"
    echo "  想同步本機變更請改跑：bash \"${RIME_DIR}/scripts/rime-sync.sh\""
    echo
    read -r -p "按 Enter 關閉…"
    exit 1
fi
echo

echo "[2/2] 重新部署（鼠鬚管的 reload 會一併重載 lua）…"
if [[ ! -x "$SQUIRREL" ]]; then
    echo "✗ 找不到鼠鬚管：${SQUIRREL}"
    echo
    read -r -p "按 Enter 關閉…"
    exit 1
fi
"$SQUIRREL" --reload
echo

echo "✓ 完成。若剛才有詞典變更，首次編譯可能還要跑一兩分鐘。"
echo "  部署出錯的話看這裡："
echo "  tail -50 \"\$(ls -t /tmp/rime.squirrel.ERROR* | head -1)\""
echo
read -r -p "按 Enter 關閉…"
