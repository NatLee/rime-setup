#!/bin/bash
# rime-update.command — macOS：拉取遠端設定 →（必要時）重新部署（含重載 lua）
#
# 由輸入法內打 '/git ＋空白鍵觸發（見 lua/p_components/p_run_pattern.lua）。
# 副檔名用 .command 是為了讓 `open` 直接在「終端機」開一個視窗跑，看得到過程。
# 需要可執行權限；git 已記錄 755，clone 下來就有。
#
# ⚠ macOS 內建 bash 3.2：`$VAR` 後面緊接中文會被吃進變數名，一律寫 ${VAR}。
#
# ── 與 Windows 版（rime-update.ps1）一致的地方 ──────────────────────────
# 沒拉到會影響輸入法的變更就**什麼都不做**。以前不管有沒有更新都 --reload
# 一次，等於每次「確認一下有沒有更新」都要付一次輸入法中斷。
# 強制跑一輪：bash rime-update.command --force
#
# ── 與 Windows 版不同的地方 ────────────────────────────────────────────
# 鼠鬚管沒有獨立的部署器，也沒有 WeaselServer.exe /quit 那種關閉開關；
# `Squirrel --reload` 一個動作就同時做「重編 yaml/詞典」與「重載 lua」。
# 所以這邊沒有「先停服務再部署」那一段 —— 那是為了避開小狼毫「服務活著時
# 部署，IME 收鍵不回字」的問題，鼠鬚管的 reload 沒有這個行為。

set -u

RIME_DIR="$HOME/Library/Rime"
SQUIRREL="/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

printf '\033]0;RIME 更新設定\007'   # 設定終端機視窗標題
echo "════════ RIME 更新設定 ════════"
echo

fail() {
    echo
    echo "✗ $1"
    echo
    read -r -p "按 Enter 關閉…"
    exit 1
}

cd "$RIME_DIR" || fail "找不到 ${RIME_DIR}"

echo "[1/2] 拉取遠端設定…"
BEFORE=$(git rev-parse HEAD)
if ! git pull --ff-only; then
    echo
    echo "  常見原因：本機有未提交的變更，或與遠端分岔。"
    echo "  先看看狀況：git -C \"${RIME_DIR}\" status"
    echo "  想同步本機變更請改跑：bash \"${RIME_DIR}/scripts/rime-sync.sh\""
    fail "git pull 失敗，沒有動到輸入法。"
fi
AFTER=$(git rev-parse HEAD)
echo

# 只有這些副檔名會影響輸入法：lua（行為）、yaml/txt/gram/json 與 opencc（進 build）
NEED=0
if [ "$BEFORE" != "$AFTER" ]; then
    CHANGED=$(git diff --name-only "$BEFORE" "$AFTER")
    if echo "$CHANGED" | grep -qE '\.(lua|yaml|txt|gram|json)$|^opencc/'; then
        NEED=1
    fi
    COUNT=$(echo "$CHANGED" | grep -c .)
else
    COUNT=0
fi
[ "$FORCE" = "1" ] && NEED=1

if [ "$NEED" = "0" ]; then
    if [ "$COUNT" = "0" ]; then
        echo "✓ 已是最新，沒有需要重新部署的變更。"
    else
        echo "✓ 拉到 ${COUNT} 個檔案，但都不影響輸入法（文件／腳本之類），不用重載。"
    fi
    echo "  （要強制跑一輪：bash rime-update.command --force）"
    echo
    sleep 2
    exit 0
fi

echo "      變更 ${COUNT} 個檔案，需要重新部署。"
echo
echo "[2/2] 重新部署（鼠鬚管的 reload 會一併重載 lua）…"
[ -x "$SQUIRREL" ] || fail "找不到鼠鬚管：${SQUIRREL}"
"$SQUIRREL" --reload
echo

echo "✓ 完成。若剛才有詞典變更，首次編譯可能還要跑一兩分鐘。"
echo "  部署出錯的話看這裡："
echo "  tail -50 \"\$(ls -t /tmp/rime.squirrel.ERROR* | head -1)\""
echo
read -r -p "按 Enter 關閉…"
