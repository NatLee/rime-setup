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
# 環境變數 NA_NO_LAUNCHERS=1：不產生 na-update.command／na-setup.command（測試用）。
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

# ── 版面編號：擋下「舊版的 repo 去套用新版面的資料夾」──────────────────
# 「使用者資料夾裡的個人檔叫什麼名字、哪些檔歸使用者」每改一次就加 1（rime-apply.ps1 的 $Layout 要一起改），
# 套用時記在 na_manifest.txt 的檔頭。同一台電腦有兩份版本不同的 clone 輪流套用時，舊的那份不認得
# 新的個人選項檔，會把選項寫回預設值 —— 看起來就是「設定一直被重置」。原委見 rime-apply.ps1。
# 環境變數 NA_ALLOW_DOWNGRADE=1：照樣套用（測試用）。
LAYOUT=2
MANIFEST="${RIME_DIR}/na_manifest.txt"
if [ -f "${MANIFEST}" ] && [ -z "${NA_ALLOW_DOWNGRADE:-}" ]; then
    have_layout="$(sed -n 's/^#[[:space:]]*na-layout:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "${MANIFEST}" | head -1)"
    if [ -n "${have_layout}" ] && [ "${have_layout}" -gt "${LAYOUT}" ]; then
        fail "${RIME_DIR} 上次是用比較新版的設定套用的（版面 ${have_layout}），這份 repo（${REPO}）比較舊（版面 ${LAYOUT}）。硬套會把你的選項重置。請先更新這份 repo（git pull），或改用比較新的那一份來套用。"
    fi
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
# repo 裡不可以出現這兩個檔名：它們是使用者的檔（見下面），照一般規則複製會把使用者的內容整個蓋掉
for own in weasel.custom.yaml default.custom.yaml; do
    if cut -f1 "${LIST}" | grep -qx "${own}"; then fail "rime/ 裡不可以放 ${own}（那是使用者的檔）。內容請寫進 na_weasel.yaml／na_default.yaml。"; fi
done

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
# （weasel.custom.yaml、default.custom.yaml 在舊版面的清單上，但現在歸使用者，不可以刪。）
removed=0
cut -f1 "${LIST}" | LC_ALL=C sort > "${TMP}/new"
if [ -f "${MANIFEST}" ]; then
    grep -v "^#" "${MANIFEST}" | grep -v "^[[:space:]]*$" | LC_ALL=C sort > "${TMP}/old"
    LC_ALL=C comm -23 "${TMP}/old" "${TMP}/new" > "${TMP}/gone"
    while IFS= read -r old; do
        case "${old}" in weasel.custom.yaml|default.custom.yaml) continue ;; esac
        if [ -f "${RIME_DIR}/${old}" ]; then rm -f "${RIME_DIR}/${old}" && removed=$(( removed + 1 )); fi
    done < "${TMP}/gone"
fi
{
    echo "# 注音Na+ 安裝腳本裝進來的檔案清單（自動產生，請勿修改；更新時靠它清掉已移除的舊檔）"
    echo "# na-layout: ${LAYOUT}"
    cat "${TMP}/new"
} > "${MANIFEST}"

# ── 舊版的單一選項檔 na_options.custom.yaml → 拆成三個 ───────────────────
# 選項現在分 na_style／na_input／na_menu 三個檔（原因見 rime/core/na_style.yaml 檔頭）。
# 已經裝過的人手上是舊的單一檔，這裡照鍵名分過去，一行都不改；舊檔改名成 .bak 留著。
OLD_OPT="${RIME_DIR}/na_options.custom.yaml"
if [ -f "${OLD_OPT}" ]; then
    # $1＝style／input／menu；$2＝屬於這個檔的鍵（| 分隔）；$3＝檔頭那行裡屬於這個檔的選項名（| 分隔）
    migrate_part() {
        dst="${RIME_DIR}/na_$1.custom.yaml"
        [ -f "${dst}" ] && return 0
        # 鍵本身（縮排兩格）＋它底下縮排更深的內容（例如 schema_list 的清單）
        awk -v keys="$2" '
            /^  [A-Za-z_]+:/ { k = $1; sub(/:.*/, "", k); keep = (("|" keys "|") ~ ("[|]" k "[|]")); if (keep) print; next }
            /^   +[^ ]/      { if (keep) print }
        ' "${OLD_OPT}" > "${TMP}/part"
        [ -s "${TMP}/part" ] || return 0
        head_kv=""
        for kv in $(grep -m1 '^#[[:space:]]*na-options:' "${OLD_OPT}" | sed 's/^#[[:space:]]*na-options://'); do
            case "|$3|" in *"|${kv%%=*}|"*) head_kv="${head_kv}${head_kv:+ }${kv}" ;; esac
        done
        {
            echo "# na_$1.custom.yaml — 個人選項（從舊版的 na_options.custom.yaml 轉過來，不進版控）"
            echo "# 想換：輸入法裡打 '/setup；或手動改下面的值後重新部署。各鍵說明見 na_$1.yaml。"
            if [ -n "${head_kv}" ]; then
                echo "# ↓ 這行是給安裝腳本讀「上次選了什麼」用的，手動改值時請一起改，或整行刪掉。"
                echo "# na-options: ${head_kv}"
            fi
            echo "patch:"
            cat "${TMP}/part"
        } > "${dst}"
    }
    migrate_part style "theme|theme_dark|font_face|comment_font_face|mac_font_face|mac_comment_font_face|font_point|label_font_point|mac_font_point|mac_label_font_point|horizontal|candidate_list_layout" "theme|dark|layout|size|font"
    migrate_part input "emoji|gloss" "emoji|gloss"
    migrate_part menu "schema_list" "langs"
    mv -f "${OLD_OPT}" "${OLD_OPT}.bak"
    build=$(( build + 1 ))   # 選項檔換了名字，要重新部署才會生效
fi

# ── 舊格式的個人選項：「不跟隨系統深色模式」原本寫成 theme_dark 跟 theme 同名 ──
# 那等於把深色模式釘死在安裝當下的主題。現在寫成 theme_dark: ~（空值），
# 前端讀不到就退回用 color_scheme。這裡把舊檔改過來（原委見 rime-apply.ps1）。
OPT_FILE="${RIME_DIR}/na_style.custom.yaml"
if [ -f "${OPT_FILE}" ]; then
    opt_theme="$(sed -n 's/^  theme:[[:space:]]*\([^[:space:]]*\).*/\1/p' "${OPT_FILE}" | head -1)"
    opt_dark="$(sed -n 's/^  theme_dark:[[:space:]]*\([^[:space:]]*\).*/\1/p' "${OPT_FILE}" | head -1)"
    if [ -n "${opt_theme}" ] && [ "${opt_dark}" = "${opt_theme}" ]; then
        sed 's/^  theme_dark:[[:space:]]*[^[:space:]]*/  theme_dark: ~/' "${OPT_FILE}" > "${TMP}/opt" && cat "${TMP}/opt" > "${OPT_FILE}"
        build=$(( build + 1 ))   # 選項檔變了，要重新部署才會生效
    fi
fi

# ── weasel.custom.yaml、default.custom.yaml 是「使用者的」：只建立，不覆蓋 ──
# repo 的內容在 na_weasel.yaml／na_default.yaml，這兩個檔只放一行 __include 把它接進來；
# 寫在那一行底下的鍵會蓋過 repo 的值，更新不會動它。原委見 rime-apply.ps1（Windows 上小狼毫的
# 設定對話框會寫這兩個檔；macOS 沒有那個對話框，但兩邊的檔案配置保持一樣，
# weasel.custom.yaml 鼠鬚管不讀，放著無妨）。
for pair in "weasel.custom.yaml:na_weasel" "default.custom.yaml:na_default"; do
    own_dst="${RIME_DIR}/${pair%%:*}"
    own_ref="${pair##*:}:/patch"
    # 已經接上了（不看註解行）→ 是使用者的檔，不碰
    if [ -f "${own_dst}" ] && grep -v '^[[:space:]]*#' "${own_dst}" | grep -q "${own_ref}"; then continue; fi
    # 沒有這個檔，或是舊版面留下來的（整個檔是從 repo 複製來的）→ 換成新格式。
    # 原本有內容就留一份 .bak（也可能是使用者自己把 __include 那一行拿掉的檔，不能讓他寫的東西無聲無息消失）。
    if [ -s "${own_dst}" ]; then cp -p "${own_dst}" "${own_dst}.bak"; fi
    {
        echo "# ${pair%%:*} — 這個檔是你的，更新不會覆蓋它。"
        echo "# __include 那一行把這套設定（${pair##*:}.yaml）接進來，請留著；寫在它底下的鍵會蓋過這套設定的值。"
        echo "patch:"
        echo "  __include: ${own_ref}"
    } > "${own_dst}" || fail "寫不進 ${own_dst}"
    build=$(( build + 1 ))
done

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
    {
        echo "#!/bin/bash"
        echo "# 由 rime-apply.sh 產生：開選項畫面（主題、字級、語言…），改完自動套用"
        printf 'bash %q --local\n' "${REPO}/install.sh"
        echo 'read -r -p "按 Enter 關閉…" _'
    } > "${RIME_DIR}/na-setup.command"
    chmod +x "${RIME_DIR}/na-setup.command"
fi

echo "      套用到 ${RIME_DIR}：更新 $(( lua + build )) 個檔（lua ${lua}）、移除 ${removed} 個舊檔"
echo "NA_APPLY lua=${lua} build=${build} removed=${removed}"
