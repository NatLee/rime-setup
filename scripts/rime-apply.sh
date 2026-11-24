#!/bin/bash
# rime-apply.sh — 把 repo 的 rime/ 「攤平」套用到 RIME 使用者資料夾（macOS／Linux）
#
# repo 裡為了好維護，檔案按功能分在 rime/<分類>/ 底下；但 RIME 引擎只認使用者資料夾
# 「根目錄」的方案／設定／詞典檔。這支腳本負責中間那一步：
#
#   rime/lua/**、rime/opencc/**   → <使用者資料夾>/lua/**、/opencc/**   （保留資料夾）
#   rime/<其他分類>/<檔案>        → <使用者資料夾>/<檔案>               （攤平到根目錄）
#
# 只做複製，不部署。平常不用直接跑它（install.sh 與 rime-update.command 會呼叫）；
# 手動安裝的人可以自己跑：bash scripts/rime-apply.sh [使用者資料夾]
#
# 最後一行固定輸出「NA_APPLY lua=<n> build=<n> removed=<n>」：這次實際變動了幾個 lua 檔／
# 幾個會進 build 的檔／刪了幾個舊檔。rime-update.command 靠它決定要不要重新部署。
#
# 環境變數 NA_NO_LAUNCHERS=1：不產生 na-update.command（測試用）。
#
# ⚠ macOS 內建 bash 3.2：`$VAR` 後面緊接中文會被吃進變數名，一律寫 ${VAR}；
#   沒有關聯陣列、mapfile。檔名一律假設不含換行。

set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${REPO}/rime"
RIME_DIR="${1:-${NA_RIME_DIR:-${HOME}/Library/Rime}}"

fail() { echo "✗ $*" >&2; exit 1; }

[ -d "${SRC}" ] || fail "找不到 ${SRC}"
mkdir -p "${RIME_DIR}" || fail "建立不了 ${RIME_DIR}"
RIME_DIR="$(cd "${RIME_DIR}" && pwd)"

# 防呆：目標不可以是 repo 自己（或在 repo 裡面），否則會把攤平的檔案倒進版控目錄
case "${RIME_DIR}/" in
    "${REPO}/"*) fail "使用者資料夾（${RIME_DIR}）不可以是設定 repo 本身或它的子資料夾。" ;;
esac
# 舊版安裝：使用者資料夾本身就是 git clone，要先由安裝腳本備份搬走
if [ -e "${RIME_DIR}/.git" ]; then
    fail "${RIME_DIR} 是舊版安裝（資料夾本身是 git repo）。請重跑 README 的安裝指令，它會幫你備份並遷移。"
fi

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t naplus)" || fail "建立不了暫存資料夾"
trap 'rm -rf "${TMP}"' EXIT
LIST="${TMP}/list"        # 每行：相對目標路徑<TAB>來源檔
: > "${LIST}"
TAB="$(printf '\t')"

# ── 列出「來源 → 相對目標路徑」────────────────────────────────────────
for cat_dir in "${SRC}"/*/; do
    cat_dir="${cat_dir%/}"
    cat_name="${cat_dir##*/}"
    ( cd "${cat_dir}" && find . -type f ! -name ".DS_Store" | sed "s:^\./::" ) | while IFS= read -r inner; do
        case "${cat_name}" in
            lua|opencc) target="${cat_name}/${inner}" ;;   # 這兩類保留資料夾結構
            *)          target="${inner}" ;;               # 其餘分類攤平
        esac
        printf '%s\t%s\n' "${target}" "${cat_dir}/${inner}" >> "${LIST}"
    done
done

dup="$(cut -f1 "${LIST}" | sort | uniq -d | head -1)"
if [ -n "${dup}" ]; then fail "檔名衝突：有兩個分類攤平後都是 ${dup}"; fi

# ── 複製（內容沒變就不動，避免無謂的重新編譯）──────────────────────────
lua=0; build=0
while IFS="${TAB}" read -r target src; do
    dst="${RIME_DIR}/${target}"
    if [ -f "${dst}" ] && cmp -s "${src}" "${dst}"; then continue; fi
    mkdir -p "$(dirname "${dst}")"
    cp -p "${src}" "${dst}" || fail "複製失敗：${dst}"
    case "${target}" in
        *.lua) lua=$(( lua + 1 )) ;;
        *)     build=$(( build + 1 )) ;;
    esac
done < "${LIST}"

# ── 清掉「上次裝過、這次 repo 已經沒有」的檔 ────────────────────────────
# 不清的話，repo 刪掉的 lua 模組會一直留在使用者資料夾被 require 到（踩過，見 GOTCHAS）。
# 只刪清單上列過的檔，使用者自己放的東西不會被動到。
MANIFEST="${RIME_DIR}/na_manifest.txt"
removed=0
cut -f1 "${LIST}" | LC_ALL=C sort > "${TMP}/new"
if [ -f "${MANIFEST}" ]; then
    grep -v "^#" "${MANIFEST}" | grep -v "^[[:space:]]*$" | LC_ALL=C sort > "${TMP}/old"
    LC_ALL=C comm -23 "${TMP}/old" "${TMP}/new" > "${TMP}/gone"
    while IFS= read -r old; do
        if [ -f "${RIME_DIR}/${old}" ]; then rm -f "${RIME_DIR}/${old}" && removed=$(( removed + 1 )); fi
    done < "${TMP}/gone"
fi
{
    echo "# 注音Na+ 安裝腳本裝進來的檔案清單（自動產生，請勿修改；更新時靠它清掉已移除的舊檔）"
    cat "${TMP}/new"
} > "${MANIFEST}"

# ── 個人短語檔：第一次從範本複製（之後永遠不覆蓋）──────────────────────
if [ ! -f "${RIME_DIR}/bopomo_onionplus_phrase.txt" ] && [ -f "${RIME_DIR}/bopomo_onionplus_phrase.sample.txt" ]; then
    cp "${RIME_DIR}/bopomo_onionplus_phrase.sample.txt" "${RIME_DIR}/bopomo_onionplus_phrase.txt"
fi

# ── 啟動器：讓輸入法（'/git）找得到 repo 裡的更新腳本 ───────────────────
# .command 檔用 open 開會在「終端機」開新視窗執行，需要可執行權限。
if [ -z "${NA_NO_LAUNCHERS:-}" ]; then
    {
        echo "#!/bin/bash"
        echo "# 由 rime-apply.sh 產生：更新設定（git pull → 套用 → 重新部署）"
        printf 'exec bash %q "$@"\n' "${REPO}/scripts/rime-update.command"
    } > "${RIME_DIR}/na-update.command"
    chmod +x "${RIME_DIR}/na-update.command"
fi

echo "      套用到 ${RIME_DIR}：更新 $(( lua + build )) 個檔（lua ${lua}）、移除 ${removed} 個舊檔"
echo "NA_APPLY lua=${lua} build=${build} removed=${removed}"
