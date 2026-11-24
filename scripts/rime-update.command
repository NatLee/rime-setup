#!/bin/bash
# rime-update.command — macOS：拉取最新設定 → 套用到使用者資料夾 →（必要時）重新部署
#
# 由輸入法內打 '/git ＋空白鍵觸發：lua 開使用者資料夾裡的 na-update.command
# （安裝時產生的啟動器），它再呼叫這支。副檔名用 .command 是為了讓 `open`
# 直接在「終端機」開一個視窗跑，看得到過程。
#
# repo 與使用者資料夾是分開的兩個地方（repo 的 rime/ 按功能分類，使用者資料夾是攤平的），
# 中間靠 rime-apply.sh 複製。這支腳本所在的 repo 就是來源。
#
# ⚠ macOS 內建 bash 3.2：`$VAR` 後面緊接中文會被吃進變數名，一律寫 ${VAR}。
#
# ── 與 Windows 版（rime-update.ps1）一致的地方 ──────────────────────────
# 套用時沒有任何檔案變動就**什麼都不做**，不付一次輸入法中斷的代價。
# 強制跑一輪：bash rime-update.command --force
#
# ── 與 Windows 版不同的地方 ────────────────────────────────────────────
# 鼠鬚管沒有獨立的部署器，也沒有 WeaselServer.exe /quit 那種關閉開關；
# `Squirrel --reload` 一個動作就同時做「重編 yaml/詞典」與「重載 lua」。
# 所以這邊沒有「先停服務再部署」那一段 —— 那是為了避開小狼毫「服務活著時
# 部署，IME 收鍵不回字」的問題，鼠鬚管的 reload 沒有這個行為。
#
# 參數：--force 強制重新部署｜--skip-pull 不 git pull｜--no-pause 結束時不等 Enter
#       --no-deploy 只套用檔案（測試用）
# 環境變數：NA_RIME_DIR（使用者資料夾）、NA_SQUIRREL（鼠鬚管執行檔，測試用）

set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
RIME_DIR="${NA_RIME_DIR:-${HOME}/Library/Rime}"
SQUIRREL="${NA_SQUIRREL:-/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel}"
FORCE=0; SKIP_PULL=0; NO_PAUSE=0; NO_DEPLOY="${NA_NO_DEPLOY:-}"
for a in "$@"; do
    case "${a}" in
        --force)     FORCE=1 ;;
        --skip-pull) SKIP_PULL=1 ;;
        --no-pause)  NO_PAUSE=1 ;;
        --no-deploy) NO_DEPLOY=1 ;;
    esac
done

printf '\033]0;RIME 更新設定\007'   # 設定終端機視窗標題
echo "════════ RIME 更新設定 ════════"
echo

pause() { [ "${NO_PAUSE}" = "1" ] || read -r -p "按 Enter 關閉…" _; }
fail() {
    echo
    echo "✗ $1"
    echo
    pause
    exit 1
}

[ -d "${REPO}/rime" ] || fail "${REPO} 裡找不到 rime/ 資料夾"

echo "[1/3] 拉取最新設定…"
if [ "${SKIP_PULL}" = "1" ]; then
    echo "      （呼叫端已經處理，略過 git pull）"
elif [ ! -e "${REPO}/.git" ]; then
    echo "      （這份設定不是 git clone 來的，略過 git pull）"
elif ! git -C "${REPO}" pull --ff-only; then
    echo
    echo "  常見原因：改過 repo 裡的檔案，或與遠端分岔（例如上游重寫過歷史）。"
    echo "  看狀況：git -C \"${REPO}\" status"
    echo "  最簡單的解法：重跑 README 的安裝指令。"
    fail "git pull 失敗，沒有動到輸入法。"
fi
echo

echo "[2/3] 套用到使用者資料夾…"
if ! OUT="$(bash "${REPO}/scripts/rime-apply.sh" "${RIME_DIR}")"; then
    echo "${OUT}"
    fail "套用失敗。"
fi
echo "${OUT}" | grep -v "^NA_APPLY "
RESULT="$(echo "${OUT}" | grep "^NA_APPLY " | tail -1)"
CHANGED=1
case "${RESULT}" in
    "NA_APPLY lua=0 build=0 removed=0") CHANGED=0 ;;
    NA_APPLY*) CHANGED=1 ;;
    *) fail "看不懂 rime-apply.sh 的結果：${RESULT}" ;;
esac
echo

if [ -n "${NO_DEPLOY}" ]; then
    echo "✓ 已套用檔案（--no-deploy：沒有重新部署）。"
    exit 0
fi

if [ "${CHANGED}" = "0" ] && [ "${FORCE}" = "0" ]; then
    echo "✓ 已是最新，沒有需要重新部署的變更。"
    echo "  （要強制跑一輪：加上 --force）"
    echo
    sleep 2
    exit 0
fi

echo "[3/3] 重新部署（鼠鬚管的 reload 會一併重載 lua）…"
[ -x "${SQUIRREL}" ] || fail "找不到鼠鬚管：${SQUIRREL}"
"${SQUIRREL}" --reload
echo

echo "✓ 完成。若剛才有詞典變更，首次編譯可能還要跑一兩分鐘。"
echo "  部署出錯的話看這裡："
echo "  tail -50 \"\$(ls -t /tmp/rime.squirrel.ERROR* | head -1)\""
echo
pause
