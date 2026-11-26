#!/bin/bash
# install.sh — 注音Na+ 一行安裝／重新設定（macOS 鼠鬚管）
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/NatLee/rime-setup/main/install.sh)"
#
# 第一次跑＝安裝；之後再跑同一行＝更新到最新版＋重新選一次選項。
# 已經裝好的人也可以不連網重選：bash ~/.na-plus/install.sh --local
#
# 不想被問（自動化／固定選項）：用環境變數或參數
#   NA_THEME=light NA_EMOJI=off NA_YES=1 bash -c "$(curl -fsSL <網址>)"
#   bash ~/.na-plus/install.sh --local --theme light --emoji off --langs ja,en --yes
#
#   --theme   matcha | light | fluent | sakura | ocean | latte | dark | midnight | classic
#   --dark    auto（系統深色模式時自動換成 Nat Dark）| off
#   --layout  vertical | horizontal
#   --size    small | medium | large（候選字級）
#   --emoji   on | off
#   --langs   ja,ko,en,extra 任意組合；none＝只留注音
#   --gloss   zh | en | ja
#   --font    huninn（粉圓體，沒裝會自動下載）| system（系統內建的蘋方）
#   --yes     不詢問：沿用上次的選擇（第一次則用預設值）
#   --local   用這支腳本所在的那份 repo，不連網（不 clone、不 pull）
#   --no-deploy  只複製檔案與寫設定，不重新部署（測試用）
#
# 其他環境變數：NA_HOME（repo 放哪，預設 ~/.na-plus）、NA_RIME_DIR（使用者資料夾）、
#   NA_REPO／NA_BRANCH（來源）、NA_SQUIRREL（鼠鬚管執行檔，測試用）
#
# 這支腳本會：
#   確認 git／鼠鬚管（沒有就自動安裝）→ 把設定 repo 下載到 ~/.na-plus（已有就更新）
#   → 第一次：備份既有的 ~/Library/Rime，並還原你的打字詞頻與個人短語
#   → 問選項 → 把檔案套用到使用者資料夾 → 重新部署
#
# ⚠ 寫給維護者：
#   ‧ macOS 內建 bash 是 3.2：沒有關聯陣列、沒有 ${var,,}、沒有 mapfile。
#   ‧ 3.2 底下 `$VAR` 後面緊接中文會把中文吃進變數名 → 一律寫 ${VAR}。
#   ‧ 3.2 底下 `$( case … in 值) … esac )` 的 `)` 會被當成命令替換的結尾 → 寫成 `(值)`。
#   ‧ 測試一律用 /bin/bash 跑（PATH 上的可能是 Homebrew 的 5.x，上面兩個錯都重現不了）。
#   ‧ 全部包在 main() 裡、最後一行才呼叫：curl 下載到一半斷線時不會執行半支腳本。
#   ‧ `bash -c "$(curl …)"` 時 stdin 仍是終端機；但保險起見提問一律讀 /dev/tty。

set -u

main() {
    local REPO="${NA_REPO:-https://github.com/NatLee/rime-setup.git}"
    local BRANCH="${NA_BRANCH:-main}"
    local RIME_DIR="${NA_RIME_DIR:-${HOME}/Library/Rime}"
    local SRC_DIR="${NA_HOME:-${HOME}/.na-plus}"      # 設定 repo 放這裡，跟使用者資料夾分開
    local USE_LOCAL="${NA_LOCAL:-}"                    # 用 SRC_DIR 那份、不連網
    local SQUIRREL_APP="/Library/Input Methods/Squirrel.app"
    local SQUIRREL="${NA_SQUIRREL:-${SQUIRREL_APP}/Contents/MacOS/Squirrel}"
    local YES="${NA_YES:-}" NO_DEPLOY="${NA_NO_DEPLOY:-}"
    local G_THEME="${NA_THEME:-}" G_LAYOUT="${NA_LAYOUT:-}" G_EMOJI="${NA_EMOJI:-}"
    local G_LANGS="${NA_LANGS:-}" G_GLOSS="${NA_GLOSS:-}" G_DARK="${NA_DARK:-}" G_SIZE="${NA_SIZE:-}" G_FONT="${NA_FONT:-}"
    local BACKUP=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --theme|--dark|--layout|--size|--font|--emoji|--langs|--gloss)
                [ $# -ge 2 ] || { echo "✗ $1 後面要接一個值" >&2; return 2; }
                case "$1" in
                    --theme)  G_THEME="$2" ;;
                    --dark)   G_DARK="$2" ;;
                    --size)   G_SIZE="$2" ;;
                    --font)   G_FONT="$2" ;;
                    --layout) G_LAYOUT="$2" ;;
                    --emoji)  G_EMOJI="$2" ;;
                    --langs)  G_LANGS="$2" ;;
                    --gloss)  G_GLOSS="$2" ;;
                esac
                shift 2 ;;
            --yes|-y)    YES=1; shift ;;
            --no-deploy) NO_DEPLOY=1; shift ;;
            --local)     USE_LOCAL=1; shift ;;
            *) echo "✗ 不認得的參數：$1" >&2; return 2 ;;
        esac
    done

    # --local 且沒指定 NA_HOME：用「這支腳本所在的那份 repo」（開發用的 clone 也適用）
    if [ -n "${USE_LOCAL}" ] && [ -z "${NA_HOME:-}" ] && [ -f "$0" ] && [ -d "$(dirname "$0")/rime" ]; then
        SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
    fi

    say()  { printf '%s\n' "$*"; }
    step() { printf '\n\033[36m→ %s\033[0m\n' "$*"; }
    warn() { printf '  \033[33m⚠ %s\033[0m\n' "$*"; }
    ok()   { printf '  \033[32m✓ %s\033[0m\n' "$*"; }
    die()  { printf '\n\033[31m✗ %s\033[0m\n\n' "$*" >&2; return 1; }
    lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

    # 兩個 remote 是不是同一個 repo：只比最後兩段（owner/repo），
    # https://github.com/a/b.git 與 git@github.com:a/b.git 視為相同。
    repo_key() {
        printf '%s' "$1" | sed -e 's/\.git$//' -e 's:/*$::' | tr ':\\' '//' | awk -F/ '{ if (NF>=2) print tolower($(NF-1) "/" $NF); else print tolower($0) }'
    }

    # 能不能問問題：有 --yes 就不問；否則要有終端機可讀
    local INTERACTIVE=0 TTY=/dev/tty
    if [ -z "${YES}" ]; then
        if [ -n "${NA_FORCE_INTERACTIVE:-}" ]; then INTERACTIVE=1; TTY=/dev/stdin   # 測試用：從 stdin 餵答案
        elif { : < /dev/tty; } 2>/dev/null; then INTERACTIVE=1
        fi
    fi
    ask() { # ask <提示>  → 結果放在 REPLY
        printf '%s' "$1"
        IFS= read -r REPLY < "${TTY}" || REPLY=""
    }

    # ── 選項定義 ──────────────────────────────────────────────────────
    theme_scheme() { # 值 → color_scheme
        case "$1" in
            matcha)  echo "NatMatcha" ;;
            light)   echo "NatLight" ;;
            fluent)  echo "NatFluent" ;;
            sakura)  echo "NatSakura" ;;
            ocean)   echo "NatOcean" ;;
            latte)   echo "NatLatte" ;;
            dark)    echo "NatDark" ;;
            midnight) echo "NatMidnight" ;;
            classic) echo "NatLee" ;;
            *) return 1 ;;
        esac
    }
    size_points() { # 值 → "小狼毫候選字 小狼毫標籤與註釋 鼠鬚管候選字 鼠鬚管標籤與註釋"（pt）
        case "$1" in
            small)  echo "15 12 18 13" ;;
            medium) echo "17 13 21 15" ;;
            large)  echo "20 15 24 17" ;;
            *) return 1 ;;
        esac
    }
    lang_schemas() { # 值 → 多行「方案id<TAB>名稱」
        case "$1" in
            ja) printf 'jpnin1\t日文\n' ;;
            ko) printf 'hangeul_hnc\t韓文\n' ;;
            en) printf 'easy_en_lower\t英文\n' ;;
            extra) printf 'allbpm\t注音文\nfullshape\t全形\neasy_en_upper\t英文（大寫）\neasy_en_lcomment\t英文（附釋義）\nsymbols_bpmf\t符號\n' ;;
            *) return 1 ;;
        esac
    }
    gloss_num() { case "$1" in zh) echo 0 ;; en) echo 1 ;; ja) echo 2 ;; *) return 1 ;; esac; }

    # choose_one <標題> <目前值> <值1> <文字1> <值2> <文字2> …  → 結果放在 CHOICE
    choose_one() {
        local title="$1" current="$2"; shift 2
        local n=$(( $# / 2 )) i=1 cur=1 v t
        printf '\n\033[36m%s\033[0m\n' "${title}"
        while [ ${i} -le ${n} ]; do
            eval "v=\${$(( i * 2 - 1 ))}; t=\${$(( i * 2 ))}"
            if [ "${v}" = "${current}" ]; then cur=${i}; printf '  * %d) %s\n' "${i}" "${t}"
            else printf '    %d) %s\n' "${i}" "${t}"; fi
            i=$(( i + 1 ))
        done
        while :; do
            ask "  選擇 1-${n}（直接按 Enter＝${cur}）："
            [ -z "${REPLY}" ] && REPLY=${cur}
            case "${REPLY}" in
                ''|*[!0-9]*) ;;
                *) if [ "${REPLY}" -ge 1 ] && [ "${REPLY}" -le ${n} ]; then
                       eval "CHOICE=\${$(( REPLY * 2 - 1 ))}"; return 0
                   fi ;;
            esac
            say '  請輸入清單上的數字。'
        done
    }

    # ── 開始 ──────────────────────────────────────────────────────────
    say ''
    say '════════ 注音Na+ 安裝／設定（macOS 鼠鬚管）════════'

    # ── 缺的程式自動裝 ────────────────────────────────────────────────
    # 預設是「要裝」：--yes 直接裝；能問就問；沒有終端機就不裝。
    confirm_install() { # confirm_install <名稱>
        [ -n "${YES}" ] && return 0
        [ ${INTERACTIVE} = 1 ] || return 1
        ask "  找不到${1}。要自動安裝嗎？[Y/n] "
        case "${REPLY}" in n|N|no|NO) return 1 ;; esac
        return 0
    }
    # /usr/bin/git 在還沒裝 Command Line Tools 時只是個殼：command -v 找得到，一執行就失敗
    # （還會自己跳安裝視窗）。所以要看 xcode-select -p，不能只看 command -v。
    git_ready() {
        local g
        g="$(command -v git 2>/dev/null)" || return 1
        if [ "${g}" = /usr/bin/git ]; then xcode-select -p >/dev/null 2>&1 || return 1; fi
        git --version >/dev/null 2>&1
    }
    # 鼠鬚管官方安裝檔（.pkg）：沒有 Homebrew，或 brew 失敗時用
    install_squirrel_pkg() {
        local url tmp pkg rc
        url="$(curl -fsSL https://api.github.com/repos/rime/squirrel/releases/latest |
               grep -o '"browser_download_url": *"[^"]*\.pkg"' | head -1 | sed 's/.*"\(https:[^"]*\)"$/\1/')"
        [ -n "${url}" ] || { warn '查不到鼠鬚管的最新版本（GitHub 連不上？）'; return 1; }
        tmp="$(mktemp -d)" || return 1
        pkg="${tmp}/${url##*/}"
        say "  下載 ${url##*/}…"
        if ! curl -fL --progress-bar -o "${pkg}" "${url}"; then rm -rf "${tmp}"; return 1; fi
        say '  安裝中（要輸入這台 Mac 的登入密碼；輸入時畫面不會顯示）…'
        sudo /usr/sbin/installer -pkg "${pkg}" -target /; rc=$?
        rm -rf "${tmp}"
        return ${rc}
    }
    local BREW=""
    BREW="$(command -v brew 2>/dev/null || true)"
    if [ -z "${BREW}" ]; then   # 裝了 Homebrew 但這個 shell 沒設 PATH（Apple 晶片常見）
        for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "${b}" ] && { BREW="${b}"; break; }; done
    fi

    # ── [1] git ───────────────────────────────────────────────────────
    step '檢查 git'
    if ! git_ready && confirm_install ' git（Apple 的 Command Line Tools）'; then
        # 跳出系統的安裝視窗，這裡等它裝完就接著往下走，不必重跑指令
        xcode-select --install >/dev/null 2>&1 || true
        say '  請在跳出的視窗按「安裝」（約 5～15 分鐘）。裝好後這裡會自動繼續；要中止按 Ctrl+C。'
        local waited=0
        while ! git_ready && [ ${waited} -lt 3600 ]; do sleep 5; waited=$(( waited + 5 )); done
    fi
    git_ready || { die '需要 git。請先執行：xcode-select --install，裝完再跑一次這行指令。'; return 1; }
    ok "$(git --version)"

    # ── [2] 鼠鬚管 ────────────────────────────────────────────────────
    step '檢查鼠鬚管（Squirrel）'
    if [ ! -x "${SQUIRREL}" ] && [ -z "${NO_DEPLOY}" ]; then
        if confirm_install '鼠鬚管'; then
            if [ -n "${BREW}" ]; then
                "${BREW}" install --cask squirrel-app || "${BREW}" install --cask squirrel || true
            fi
            [ -x "${SQUIRREL}" ] || install_squirrel_pkg || true
            if [ -x "${SQUIRREL}" ]; then
                ok '鼠鬚管裝好了，已加進輸入方式。如果選單列切不到它，登出再登入一次。'
            fi
        fi
        if [ ! -x "${SQUIRREL}" ]; then
            die "找不到鼠鬚管（${SQUIRREL_APP}）。請先安裝 https://rime.im/download/ ，
  安裝後登出再登入、到「系統設定 → 鍵盤 → 輸入方式」加入「鼠鬚管」，再跑一次這行指令。"
            return 1
        fi
    fi
    if [ -x "${SQUIRREL}" ]; then ok "${SQUIRREL}"; else warn '找不到鼠鬚管（--no-deploy，略過）'; fi

    step "RIME 使用者資料夾：${RIME_DIR}"

    # ── [3] 設定來源（repo）──────────────────────────────────────────
    # repo 與使用者資料夾是分開的：repo 裡的 rime/ 按功能分類，使用者資料夾必須是攤平的
    # （RIME 只認根目錄的方案檔），中間靠 scripts/rime-apply.sh 複製。
    local origin=""
    if [ -n "${USE_LOCAL}" ]; then
        [ -d "${SRC_DIR}/rime" ] || { die "${SRC_DIR} 裡找不到 rime/ 資料夾。"; return 1; }
        step "使用本機的設定（不連網）：${SRC_DIR}"
    elif [ -e "${SRC_DIR}/.git" ]; then
        origin="$(git -C "${SRC_DIR}" remote get-url origin 2>/dev/null || true)"
        if [ -z "${origin}" ] || [ "$(repo_key "${origin}")" != "$(repo_key "${REPO}")" ]; then
            die "${SRC_DIR} 已經是另一個 git repo（${origin}）。請把它移走，或用 NA_HOME 指定別的位置。"; return 1
        fi
        step "更新設定到最新版：${SRC_DIR}"
        if ! git -C "${SRC_DIR}" pull --ff-only; then
            warn 'git pull 失敗（改過裡面的檔案，或上游重寫過歷史），沿用目前的版本繼續。'
            warn "想強制對齊上游：刪掉 ${SRC_DIR} 後重跑這行指令。"
        fi
    elif [ -d "${SRC_DIR}" ] && [ -n "$(ls -A "${SRC_DIR}" 2>/dev/null)" ]; then
        die "${SRC_DIR} 已經存在而且不是這份設定的 repo。請把它移走，或用 NA_HOME 指定別的位置。"; return 1
    else
        step "下載設定到 ${SRC_DIR}（約 100 MB，視網速需要一點時間）"
        [ -d "${SRC_DIR}" ] && rmdir "${SRC_DIR}"
        if ! git clone --depth 1 --branch "${BRANCH}" "${REPO}" "${SRC_DIR}" || [ ! -d "${SRC_DIR}/rime" ]; then
            die 'git clone 失敗。請檢查網路後再試（還沒有動到你的輸入法設定）。'; return 1
        fi
    fi

    # ── [3b] 使用者資料夾：裝過就直接更新，否則先備份 ─────────────────
    # 判斷「裝過」看 na_manifest.txt（rime-apply.sh 留下的清單）。
    # 沒有清單但有東西＝別的方案，或舊版安裝（資料夾本身是 git clone）→ 整個搬去備份，
    # 再把屬於「你」的東西搬回來。
    if [ -f "${RIME_DIR}/na_manifest.txt" ]; then
        step '這台已經裝過 → 更新檔案並重新設定選項'
    elif [ -d "${RIME_DIR}" ] && [ -n "$(ls -A "${RIME_DIR}" 2>/dev/null)" ]; then
        BACKUP="${RIME_DIR}.backup.$(date +%Y%m%d%H%M%S)"
        step "備份既有設定 → ${BACKUP}"
        mv "${RIME_DIR}" "${BACKUP}" || { die "搬不動 ${RIME_DIR}"; return 1; }
    fi
    mkdir -p "${RIME_DIR}" || { die "建立不了 ${RIME_DIR}"; return 1; }

    if [ -n "${BACKUP}" ]; then
        # 詞頻資料庫（*.userdb）、同步資料、機器識別檔、個人短語、上次的選項 —— 這些是
        # 「你的」東西，不在 repo 裡，要從備份搬回來，否則等於把打字習慣歸零。
        local restored=0 db f
        for db in "${BACKUP}"/*.userdb; do
            [ -d "${db}" ] || continue
            cp -R "${db}" "${RIME_DIR}/" && restored=$(( restored + 1 ))
        done
        [ -d "${BACKUP}/sync" ] && cp -R "${BACKUP}/sync" "${RIME_DIR}/"
        for f in installation.yaml user.yaml bopomo_onionplus_phrase.txt \
                 na_style.custom.yaml na_input.custom.yaml na_menu.custom.yaml na_options.custom.yaml; do
            [ -f "${BACKUP}/${f}" ] && cp "${BACKUP}/${f}" "${RIME_DIR}/"
        done
        ok "已從備份還原 ${restored} 個詞頻資料庫與個人檔案"
        say "    備份留在 ${BACKUP}，確認一切正常後可自行刪除。"
    fi

    # ── [4] 選項 ──────────────────────────────────────────────────────
    # 選項分三個檔（原因見 rime/core/na_style.yaml 檔頭）：長相 na_style、輸入行為 na_input、方案清單 na_menu。
    # 上次的選擇記在各檔檔頭那行「# na-options: k=v k=v」。na_options.custom.yaml 是舊版的單一檔，
    # 先讀它、再讓新檔蓋過去（舊檔之後由 rime-apply.sh 收掉）。
    local STYLE_FILE="${RIME_DIR}/na_style.custom.yaml" INPUT_FILE="${RIME_DIR}/na_input.custom.yaml" MENU_FILE="${RIME_DIR}/na_menu.custom.yaml"
    local FIRST_INSTALL=1; [ -f "${RIME_DIR}/na_manifest.txt" ] && FIRST_INSTALL=0
    local P_DARK="" P_SIZE="" P_FONT=""
    local P_THEME="" P_LAYOUT="" P_EMOJI="" P_LANGS="" P_GLOSS="" line kv pf
    for pf in "${RIME_DIR}/na_options.custom.yaml" "${STYLE_FILE}" "${INPUT_FILE}" "${MENU_FILE}"; do
        [ -f "${pf}" ] || continue
        line="$(grep -m1 '^#[[:space:]]*na-options:' "${pf}" 2>/dev/null | sed 's/^#[[:space:]]*na-options://' || true)"
        for kv in ${line}; do
            case "${kv}" in
                theme=*)  P_THEME="${kv#theme=}" ;;
                dark=*)   P_DARK="${kv#dark=}" ;;
                size=*)   P_SIZE="${kv#size=}" ;;
                font=*)   P_FONT="${kv#font=}" ;;
                layout=*) P_LAYOUT="${kv#layout=}" ;;
                emoji=*)  P_EMOJI="${kv#emoji=}" ;;
                langs=*)  P_LANGS="${kv#langs=}" ;;
                gloss=*)  P_GLOSS="${kv#gloss=}" ;;
            esac
        done
    done
    # 參數／環境變數 > 上次的選擇 > 預設值
    local THEME LAYOUT EMOJI LANGS GLOSS DARK SIZE
    THEME="$(lower "${G_THEME:-${P_THEME:-matcha}}")"
    DARK="$(lower "${G_DARK:-${P_DARK:-auto}}")"
    SIZE="$(lower "${G_SIZE:-${P_SIZE:-medium}}")"
    local FONT; FONT="$(lower "${G_FONT:-${P_FONT:-huninn}}")"
    # 舊值相容：以前「跟隨系統」是主題的一個選項（auto），現在拆成獨立的 dark 選項
    if [ "${THEME}" = "auto" ]; then THEME=light; [ -z "${G_DARK}" ] && DARK=auto; fi
    LAYOUT="$(lower "${G_LAYOUT:-${P_LAYOUT:-vertical}}")"
    EMOJI="$(lower "${G_EMOJI:-${P_EMOJI:-on}}")"
    LANGS="$(lower "${G_LANGS:-${P_LANGS:-ja,ko,en,extra}}")"
    GLOSS="$(lower "${G_GLOSS:-${P_GLOSS:-zh}}")"

    # 系統現在是不是深色模式：選項畫面用來提示「為什麼換了主題沒變」（NA_SYS_DARK=1/0 給測試用）
    local SYS_DARK="${NA_SYS_DARK:-}"
    if [ -z "${SYS_DARK}" ]; then
        SYS_DARK=0; [ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" = "Dark" ] && SYS_DARK=1
    fi
    dark_note_needed() { # 系統深色＋跟隨系統＋主題本身不是深色 → 實際看到的是 Nat Dark
        [ "${SYS_DARK}" = 1 ] && [ "${DARK}" = "auto" ] && case "${THEME}" in dark|midnight) return 1 ;; *) return 0 ;; esac
    }

    local TUI_KEYS="${NA_TUI_KEYS:-}" SCREEN_DONE=0
    if [ ${INTERACTIVE} = 1 ] || [ -n "${TUI_KEYS}" ]; then
        # ════ 選項畫面（install.ps1 的 Show-OptionsScreen 的 bash 版）════════════
        # 一個畫面、方向鍵操作：↑↓ 選項目、←→ 直接換值；右邊用主題真正的顏色畫一個候選窗，
        # 換到哪個就看到哪個；改了什麼列在下面，Backspace 還原那一項，Esc 全部不算。
        # 版面、按鍵、文字跟 Windows 版一致；改了一邊記得看另一邊。幾個刻意的決定：
        #   ‧ bash 3.2：沒有關聯陣列、read -t 只吃整數秒（所以單按 Esc 要等一秒才生效；q 也是取消）。
        #   ‧ 繪製時不開子 shell（每開一個約 1～2 ms，畫一格要上百個）：函式一律把結果放進全域變數。
        #   ‧ 中日文字佔幾格：用「字元數＋(位元組數−字元數)/2」估。中日文字（3 位元組）算 2 格，
        #     ASCII 算 1 格，箭頭這類 3 位元組的窄字元會多算一格 —— 只會讓截斷提早一點，不會溢出折行。
        #   ‧ 所有文字都用絕對座標定位（同 Windows 版），寬度估錯只會歪一個字。
        #   ‧ 顏色讀 repo 的 squirrel.custom.yaml，預覽畫的就是鼠鬚管會用的那組顏色。終端機有
        #     COLORTERM=truecolor（macOS 26 起的「終端機」、iTerm2…）用真彩色，否則換算成 256 色。
        #   ‧ 用替代畫面（離開後終端機回到原本的內容）；Ctrl+C 也會把終端機還原。
        #   ‧ 終端機太小、不是終端機、或 NA_PLAIN=1 → 退回下面「輸入編號」的版本。
        #   ‧ 測試用：NA_TUI_KEYS（例如 "Down,Right,Enter"；Wait＝停四秒）＝不讀鍵盤，照這串按鍵走；
        #     NA_TUI_DUMP＝把最後一格畫面（含控制碼）寫進這個檔；NA_TUI_COLS＝假裝的終端機寬度。

        # 選項的值與文字：key|值|短名|說明（短名放在列上，說明放在下面那行）
        local IT_KEY=() IT_ID=() IT_SHORT=() IT_DETAIL=() it_a it_b it_c it_d
        while IFS='|' read -r it_a it_b it_c it_d; do
            [ -n "${it_a}" ] || continue
            IT_KEY[${#IT_KEY[@]}]="${it_a}"; IT_ID[${#IT_ID[@]}]="${it_b}"
            IT_SHORT[${#IT_SHORT[@]}]="${it_c}"; IT_DETAIL[${#IT_DETAIL[@]}]="${it_d}"
        done <<'ITEMS'
theme|matcha|Nat Matcha 抹茶奶油色|
theme|light|Nat Light 明亮白底|
theme|fluent|Nat Fluent 低調淡灰＋藍色條|
theme|sakura|Nat Sakura 櫻花粉|
theme|ocean|Nat Ocean 海洋藍|
theme|latte|Nat Latte 拿鐵棕|
theme|dark|Nat Dark 深色|
theme|midnight|Nat Midnight 午夜藍（深色）|
theme|classic|Nat Classic 經典黃綠|
dark|auto|跟隨系統|系統切到深色模式時，候選窗自動換成 Nat Dark
dark|off|不跟隨|永遠用上面選的主題
layout|vertical|直排|
layout|horizontal|橫排|
size|small|小|
size|medium|中|
size|large|大|
font|huninn|粉圓體|圓潤的開源字型 jf open 粉圓（沒裝會自動下載安裝，約 5 MB）
font|system|系統字型|蘋方
emoji|on|開|候選裡附帶對應的 emoji
emoji|off|關|
langs|ja|日文|
langs|ko|韓文|
langs|en|英文|
langs|extra|其他|注音文、全形、英文大寫、英文附釋義、符號
gloss|zh|中文|
gloss|en|英文|
gloss|ja|日文|
ITEMS
        # 畫面上的列（外觀在前、輸入在後）
        local R_KEY=(theme dark layout size font emoji langs gloss)
        local R_GROUP=(外觀 外觀 外觀 外觀 外觀 輸入 輸入 輸入)
        local R_TITLE=(主題 系統深色模式 候選排列 候選字級 候選字型 '候選附 emoji' 選單裡的語言 釋義語言)
        local R_HINT=('候選窗的配色。用 ←→ 換，右邊就是它實際的顏色。'
                      '系統切到深色模式時，候選窗要不要跟著換成深色。'
                      '候選字直的排，還是橫的排成一列。'
                      '候選字的大小，標籤與註釋會跟著調整。'
                      '候選字用哪一套字型。'
                      '打字時候選裡要不要附上對應的 emoji。這是預設狀態，之後仍可在方案選單臨時切換。'
                      '方案選單與右 Shift 循環裡要放哪些語言（注音一定有）。←→ 移動，空白鍵勾選。'
                      '日文、英文候選旁邊的釋義，用哪種語言顯示。')

        # 讀寫選項值（結果放 V）
        optv() { case "$1" in theme) V="${THEME}" ;; dark) V="${DARK}" ;; layout) V="${LAYOUT}" ;; size) V="${SIZE}" ;;
                 font) V="${FONT}" ;; emoji) V="${EMOJI}" ;; langs) V="${LANGS}" ;; gloss) V="${GLOSS}" ;; esac; }
        setv() { case "$1" in theme) THEME="$2" ;; dark) DARK="$2" ;; layout) LAYOUT="$2" ;; size) SIZE="$2" ;;
                 font) FONT="$2" ;; emoji) EMOJI="$2" ;; langs) LANGS="$2" ;; gloss) GLOSS="$2" ;; esac; }
        snapv() { eval "V=\"\${SNAP_$1}\""; }
        # 某一項的選項範圍（IS＝第一個在 IT_* 的位置、IN＝個數）
        item_range() {
            local i=0; IS=-1; IN=0
            while [ ${i} -lt ${#IT_KEY[@]} ]; do
                if [ "${IT_KEY[i]}" = "$1" ]; then [ ${IS} -lt 0 ] && IS=${i}; IN=$(( IN + 1 )); fi
                i=$(( i + 1 ))
            done
        }
        # 值 → 短名（SHORT）、說明（DETAIL）、在這一項裡是第幾個（POS，從 0 起；找不到 -1）
        item_of() {
            local i=0; SHORT="$2"; DETAIL=""; POS=-1
            while [ ${i} -lt ${#IT_KEY[@]} ]; do
                if [ "${IT_KEY[i]}" = "$1" ]; then
                    POS=$(( POS + 1 ))
                    if [ "${IT_ID[i]}" = "$2" ]; then SHORT="${IT_SHORT[i]}"; DETAIL="${IT_DETAIL[i]}"; return 0; fi
                fi
                i=$(( i + 1 ))
            done
            POS=-1
        }
        langs_text() { # langs 值 → LT（例如「日文、英文」）
            local l; LT=""
            for l in ja ko en extra; do
                case ",$1," in *",${l},"*) item_of langs "${l}"; LT="${LT}${LT:+、}${SHORT}" ;; esac
            done
            LT="${LT:-只有注音}"
        }
        # 字串在終端機上大約佔幾格（CELLS）；超過寬度就截掉補 …（FIT）
        cells() { local s="$1" n; n=${#s}; local LC_ALL=C; CELLS=$(( n + (${#s} - n) / 2 )); }
        fit() {
            local s="$1" n
            cells "${s}"; if [ ${CELLS} -le $2 ]; then FIT="${s}"; return; fi
            n=${#s}
            while [ ${n} -gt 0 ]; do n=$(( n - 1 )); cells "${s:0:n}"; [ ${CELLS} -le $(( $2 - 1 )) ] && break; done
            FIT="${s:0:n}…"
        }

        tui_run() {
            local ESC=$'\033'
            local CSI="${ESC}["
            local K_RESET="${CSI}0m" K_DIM="${CSI}90m" K_ACC="${CSI}36m" K_BOLD="${CSI}1m" K_REV="${CSI}7m"
            local TRUECOLOR=0
            case "${NA_TRUECOLOR:-${COLORTERM:-}}" in truecolor|24bit|1) TRUECOLOR=1 ;; esac
            local SCRIPTED="${TUI_KEYS}" QUEUE="" DUMP="${NA_TUI_DUMP:-}"
            [ -n "${SCRIPTED}" ] && QUEUE="$(printf '%s' "${SCRIPTED}" | tr ' ' ',')"
            # 字元處理要 UTF-8（從 Finder 開的 .command 有時沒有 LANG）
            case "$(locale charmap 2>/dev/null)" in UTF-8|utf8|UTF8) ;; *) local LC_ALL=en_US.UTF-8 ;; esac

            # 各主題的顏色（鼠鬚管的 0xBBGGRR）→ PC_<配色>_<鍵>
            local tf="${SRC_DIR}/rime/theme/squirrel.custom.yaml" ln cur="" ck cv
            if [ -f "${tf}" ]; then
                while IFS= read -r ln; do
                    case "${ln}" in
                        '  "preset_color_schemes/'*'":'*) cur="${ln#*preset_color_schemes/}"; cur="${cur%%\"*}"
                            case "${cur}" in *[!A-Za-z0-9_]*|'') cur="" ;; esac ;;
                        '    '[a-z]*': 0x'*)
                            [ -n "${cur}" ] || continue
                            ck="${ln#    }"; ck="${ck%%:*}"; cv="${ln#*: 0x}"; cv="${cv%% *}"
                            case "${ck}${cv}" in *[!A-Za-z0-9_]*) continue ;; esac
                            eval "PC_${cur}_${ck}=\${cv}" ;;
                        '  '[!\ ]*|[!\ ]*) cur="" ;;
                    esac
                done < "${tf}"
            fi
            # 顏色 → SGR 片段（GC 放 "38;2;r;g;b" 或 "38;5;n"）。$1＝配色、$2＝鍵、$3＝沒有這個鍵時的後備鍵、$4＝38 前景／48 背景
            pc() {
                local h="" v r g b
                eval "h=\"\${PC_$1_$2:-}\""
                [ -z "${h}" ] && [ -n "$3" ] && eval "h=\"\${PC_$1_$3:-}\""
                [ -z "${h}" ] && h=FFFFFF
                v=$(( 16#${h} )); r=$(( v & 255 )); g=$(( (v >> 8) & 255 )); b=$(( (v >> 16) & 255 ))
                if [ ${TRUECOLOR} = 1 ]; then GC="$4;2;${r};${g};${b}"; return; fi
                c6() { if [ $1 -lt 48 ]; then C6=0; elif [ $1 -lt 115 ]; then C6=1; else C6=$(( ($1 - 35) / 40 )); fi; }
                c6 ${r}; r=${C6}; c6 ${g}; g=${C6}; c6 ${b}; b=${C6}
                GC="$4;5;$(( 16 + 36 * r + 6 * g + b ))"
            }

            # 進來時的樣子：Esc／Backspace 還原回這裡，「改了什麼」也是跟它比
            local k
            for k in ${R_KEY[@]}; do optv "${k}"; eval "local SNAP_${k}=\"\${V}\""; done
            local NROWS=${#R_KEY[@]} focus=0 chip=0 F=""
            local PAD='                                                                '   # 64 格空白，畫色塊用

            put()   { F="${F}$1"; }
            at()    { F="${F}${CSI}$1;$2H"; }
            block() { at $1 $2; F="${F}${CSI}${3}m${PAD:0:$4}${K_RESET}"; }   # block <列> <欄> <背景SGR> <寬>
            ink()   { at $1 $2; F="${F}${CSI}${3};${4}m${5:+${K_BOLD}}$6${K_RESET}"; }   # ink <列> <欄> <背景SGR> <前景SGR> <粗體?> <字>
            changed() { optv "$1"; local cv1="${V}"; snapv "$1"; [ "${cv1}" != "${V}" ]; }

            render() {
                local cols="${NA_TUI_COLS:-}" r y i key group="" on
                if [ -z "${cols}" ]; then cols="$(stty size 2>/dev/null < /dev/tty)"; cols="${cols#* }"; fi
                case "${cols}" in ''|*[!0-9]*) cols=120 ;; esac
                F="${CSI}?25l"
                r=1; while [ ${r} -le 22 ]; do at ${r} 1; put "${CSI}2K"; r=$(( r + 1 )); done
                at 2 3; put "${K_BOLD}注音Na+ 設定${K_RESET}"

                # ── 左邊：選項 ──
                local top=4 xl=5 xv=22
                y=$(( top - 1 )); i=0
                while [ ${i} -lt ${NROWS} ]; do
                    key="${R_KEY[i]}"; on=0; [ ${i} = ${focus} ] && on=1
                    if [ "${R_GROUP[i]}" != "${group}" ]; then
                        if [ -n "${group}" ]; then y=$(( y + 2 )); else y=$(( y + 1 )); fi
                        group="${R_GROUP[i]}"
                        at ${y} 3; put "${K_DIM}${group}${K_RESET}"
                    fi
                    y=$(( y + 1 ))
                    if changed "${key}"; then at ${y} 1; put "${K_ACC}●${K_RESET}"; fi
                    if [ ${on} = 1 ]; then at ${y} 3; put "${K_ACC}▸${K_RESET}"; at ${y} ${xl}; put "${K_BOLD}${R_TITLE[i]}${K_RESET}"
                    else at ${y} ${xl}; put "${R_TITLE[i]}"; fi
                    at ${y} ${xv}
                    optv "${key}"
                    if [ "${key}" = "langs" ]; then
                        # 可複選的那一項：一排核取方塊，←→ 移動、空白鍵勾選
                        local j=0 lv="${V}" box id
                        item_range langs
                        while [ ${j} -lt ${IN} ]; do
                            id="${IT_ID[IS + j]}"
                            case ",${lv}," in *",${id},"*) box='[x] ' ;; *) box='[ ] ' ;; esac
                            if [ ${on} = 1 ] && [ ${j} = ${chip} ]; then put "${K_REV}${box}${IT_SHORT[IS + j]}${K_RESET}  "
                            else put "${box}${IT_SHORT[IS + j]}  "; fi
                            j=$(( j + 1 ))
                        done
                    else
                        item_of "${key}" "${V}"; item_range "${key}"
                        if [ ${on} = 1 ]; then put "${K_DIM}‹ ${K_RESET}${K_ACC}${K_BOLD}${SHORT}${K_RESET}${K_DIM} ›   $(( POS + 1 ))/${IN}${K_RESET}"
                        else put "${SHORT}"; fi
                    fi
                    i=$(( i + 1 ))
                done

                # ── 下面：這一項在做什麼、目前這個值的說明 ──
                key="${R_KEY[focus]}"
                local more=""
                if [ "${key}" = "langs" ]; then
                    item_range langs; more="${IT_DETAIL[IS + chip]}"
                    [ -z "${more}" ] && more='注音一定有；勾起來的語言會出現在方案選單（Ctrl+` 或 F4）與右 Shift 的循環裡。'
                else optv "${key}"; item_of "${key}" "${V}"; more="${DETAIL}"; fi
                if { [ "${key}" = theme ] || [ "${key}" = dark ]; } && dark_note_needed; then
                    more='系統現在是深色模式，所以實際看到的是 Nat Dark。想在深色模式也用這個主題：把「系統深色模式」換成不跟隨。'
                fi
                fit "${R_HINT[focus]}" $(( cols - 4 )); at 16 3; put "${FIT}"
                fit "${more}" $(( cols - 4 )); at 17 3; put "${K_DIM}${FIT}${K_RESET}"

                # ── 改了什麼 ──
                local diff="" names="" n=0 old new
                i=0
                while [ ${i} -lt ${NROWS} ]; do
                    key="${R_KEY[i]}"
                    if changed "${key}"; then
                        if [ "${key}" = langs ]; then snapv langs; langs_text "${V}"; old="${LT}"; langs_text "${LANGS}"; new="${LT}"
                        else snapv "${key}"; item_of "${key}" "${V}"; old="${SHORT}"; optv "${key}"; item_of "${key}" "${V}"; new="${SHORT}"; fi
                        diff="${diff}${diff:+　｜　}${R_TITLE[i]}：${old} → ${new}"
                        names="${names}${names:+、}${R_TITLE[i]}"; n=$(( n + 1 ))
                    fi
                    i=$(( i + 1 ))
                done
                if [ ${n} -gt 0 ]; then
                    # 一行放得下就列出「舊 → 新」；放不下改成只列改了哪幾項（寧可少講，也不要被截掉一半）
                    diff="已修改　${diff}"
                    cells "${diff}"; [ ${CELLS} -gt $(( cols - 4 )) ] && diff="已修改 ${n} 項　${names}"
                    fit "${diff}" $(( cols - 4 ))
                    at 19 1; put "${K_ACC}●${K_RESET}"; at 19 3; put "${FIT}"
                else
                    at 19 3; put "${K_DIM}還沒有修改。直接按 Enter 就是什麼都不改。${K_RESET}"
                fi

                # ── 按鍵提示（每一段各自定位）──
                local x=3 hk hd
                for hk in '↑↓|選項目' '←→|換一個' '空白|勾選' 'Backspace|還原這一項' 'Enter|套用' 'Esc|取消'; do
                    hd="${hk#*|}"; hk="${hk%%|*}"
                    at 21 ${x}; put "${K_ACC}${hk}${K_RESET} ${K_DIM}${hd}${K_RESET}"
                    cells "${hk}${hd}"; x=$(( x + CELLS + 4 ))
                    case "${hk}" in "↑↓"|"←→") x=$(( x - 2 )) ;; esac   # 箭頭是窄字元，估算時多算了兩格
                done

                # ── 右邊：用主題真正的顏色畫一個候選窗 ──
                local px=70 pw=32
                if [ ${cols} -ge $(( px + pw + 2 )) ]; then
                    local name scheme caption
                    item_of theme "${THEME}"; name="${SHORT#Nat }"; name="Nat ${name%% *}"
                    item_of layout "${LAYOUT}"; caption="${name} · ${SHORT}"
                    item_of size "${SIZE}"; caption="${caption} · 字級${SHORT}"
                    scheme="$(theme_scheme "${THEME}")"
                    if [ "${R_KEY[focus]}" = dark ] && [ "${DARK}" = auto ]; then
                        case "${THEME}" in dark|midnight) ;; *) scheme=NatDark; caption='系統切到深色模式時 → Nat Dark' ;; esac
                    fi
                    local back frame text hb ht label cand cmt hcb hct hcl hcc ix=$(( px + 2 )) iw=$(( pw - 4 )) tall=8
                    pc ${scheme} back_color '' 48; back="${GC}"
                    pc ${scheme} border_color back_color 48; frame="${GC}"
                    pc ${scheme} text_color '' 38; text="${GC}"
                    pc ${scheme} hilited_back_color back_color 48; hb="${GC}"
                    pc ${scheme} hilited_text_color text_color 38; ht="${GC}"
                    pc ${scheme} label_color text_color 38; label="${GC}"
                    pc ${scheme} candidate_text_color text_color 38; cand="${GC}"
                    pc ${scheme} comment_text_color label_color 38; cmt="${GC}"
                    pc ${scheme} hilited_candidate_back_color hilited_back_color 48; hcb="${GC}"
                    pc ${scheme} hilited_candidate_text_color hilited_text_color 38; hct="${GC}"
                    pc ${scheme} hilited_candidate_label_color hilited_candidate_text_color 38; hcl="${GC}"
                    pc ${scheme} hilited_comment_text_color hilited_candidate_text_color 38; hcc="${GC}"
                    [ "${LAYOUT}" = horizontal ] && tall=5
                    r=0; while [ ${r} -lt ${tall} ]; do block $(( top + r )) ${px} "${frame}" ${pw}; r=$(( r + 1 )); done
                    r=1; while [ ${r} -lt $(( tall - 1 )) ]; do block $(( top + r )) ${ix} "${back}" ${iw}; r=$(( r + 1 )); done
                    # 編碼列：已確定的部分＋高亮段（鼠鬚管的翻頁箭頭畫在候選窗左緣，這裡不畫）
                    ink $(( top + 1 )) $(( ix + 2 )) "${back}" "${text}" '' 'ㄋㄧ'
                    ink $(( top + 1 )) $(( ix + 7 )) "${hb}" "${ht}" '' ' ㄏㄠ '
                    local cw=(你好 妳好 さくら hello) cc=('' '' 櫻花 哈囉) cx
                    if [ "${LAYOUT}" = horizontal ]; then
                        cx=$(( ix + 1 )); r=0
                        while [ ${r} -lt 3 ]; do
                            cells "${cw[r]}"
                            if [ ${r} = 0 ]; then
                                block $(( top + 3 )) ${cx} "${hcb}" $(( CELLS + 4 ))
                                ink $(( top + 3 )) $(( cx + 1 )) "${hcb}" "${hcl}" '' 1
                                ink $(( top + 3 )) $(( cx + 3 )) "${hcb}" "${hct}" 1 "${cw[r]}"
                            else
                                ink $(( top + 3 )) $(( cx + 1 )) "${back}" "${label}" '' $(( r + 1 ))
                                ink $(( top + 3 )) $(( cx + 3 )) "${back}" "${cand}" 1 "${cw[r]}"
                            fi
                            cx=$(( cx + CELLS + 4 )); r=$(( r + 1 ))
                        done
                    else
                        r=0
                        while [ ${r} -lt 4 ]; do
                            y=$(( top + 3 + r ))
                            if [ ${r} = 0 ]; then
                                block ${y} $(( ix + 1 )) "${hcb}" $(( iw - 2 ))
                                ink ${y} $(( ix + 3 )) "${hcb}" "${hcl}" '' 1
                                ink ${y} $(( ix + 6 )) "${hcb}" "${hct}" 1 "${cw[r]}"
                                [ -n "${cc[r]}" ] && { cells "${cw[r]}"; ink ${y} $(( ix + 8 + CELLS )) "${hcb}" "${hcc}" '' "${cc[r]}"; }
                            else
                                ink ${y} $(( ix + 3 )) "${back}" "${label}" '' $(( r + 1 ))
                                ink ${y} $(( ix + 6 )) "${back}" "${cand}" 1 "${cw[r]}"
                                [ -n "${cc[r]}" ] && { cells "${cw[r]}"; ink ${y} $(( ix + 8 + CELLS )) "${back}" "${cmt}" '' "${cc[r]}"; }
                            fi
                            r=$(( r + 1 ))
                        done
                    fi
                    fit "${caption}" ${pw}; at $(( top + tall )) ${px}; put "${K_DIM}${FIT}${K_RESET}"
                fi
                at 22 1
            }

            # 讀一個鍵（KEY）。方向鍵是 ESC [ A 這種序列；bash 3.2 的 read -t 只吃整數秒
            read_key() {
                KEY=""
                if [ -n "${SCRIPTED}" ]; then
                    if [ -n "${QUEUE}" ]; then
                        KEY="${QUEUE%%,*}"
                        case "${QUEUE}" in *,*) QUEUE="${QUEUE#*,}" ;; *) QUEUE="" ;; esac
                    else KEY=Enter; fi
                    return
                fi
                local c="" rest=""
                IFS= read -rsn1 c < /dev/tty || { KEY=Esc; return; }
                case "${c}" in
                    "${ESC}")
                        IFS= read -rsn2 -t 1 rest < /dev/tty
                        case "${rest}" in
                            '[A'|OA) KEY=Up ;; '[B'|OB) KEY=Down ;; '[C'|OC) KEY=Right ;; '[D'|OD) KEY=Left ;;
                            '[H'|OH) KEY=Home ;; '[F'|OF) KEY=End ;;
                            '[3') IFS= read -rsn1 -t 1 rest < /dev/tty; KEY=Backspace ;;   # Delete（fn+Backspace）
                            '[5') IFS= read -rsn1 -t 1 rest < /dev/tty; KEY=Home ;;
                            '[6') IFS= read -rsn1 -t 1 rest < /dev/tty; KEY=End ;;
                            '') KEY=Esc ;;
                            *) KEY=Other ;;
                        esac ;;
                    '') KEY=Enter ;;
                    ' ') KEY=Space ;;
                    $'\t') KEY=Down ;;
                    $'\177'|$'\010') KEY=Backspace ;;
                    q|Q) KEY=Esc ;;
                    k|K) KEY=Up ;; j|J) KEY=Down ;; h|H) KEY=Left ;; l|L) KEY=Right ;;
                    [1-9]) KEY="${c}" ;;
                    *) KEY=Other ;;
                esac
            }

            # 不管怎麼離開，終端機都要回到正常狀態（游標、顏色、回顯、原本的畫面）
            local STTY_SAVED=""
            tui_restore() {
                printf '%s' "${CSI}0m${CSI}?25h${CSI}?1049l"
                [ -n "${STTY_SAVED}" ] && stty "${STTY_SAVED}" 2>/dev/null < /dev/tty
            }
            if [ -z "${SCRIPTED}" ]; then
                STTY_SAVED="$(stty -g 2>/dev/null < /dev/tty)"
                stty -echo 2>/dev/null < /dev/tty
            fi
            trap 'tui_restore; printf "\n已取消。\n"; exit 130' INT TERM
            printf '%s' "${CSI}?1049h"

            local row dir id set ni
            while :; do
                render
                printf '%s' "${F}"
                [ -n "${DUMP}" ] && printf '%s' "${F}" > "${DUMP}"
                read_key
                row="${R_KEY[focus]}"; dir=0
                case "${KEY}" in
                    Wait) sleep 4; continue ;;   # 只有按鍵腳本會有：停在這一格（截圖用）
                    Enter) break ;;
                    Esc|Escape|Q)
                        for k in ${R_KEY[@]}; do snapv "${k}"; setv "${k}" "${V}"; done
                        break ;;
                    Up|K)      focus=$(( (focus + NROWS - 1) % NROWS )) ;;
                    Down|J|Tab) focus=$(( (focus + 1) % NROWS )) ;;
                    Home|PageUp) focus=0 ;;
                    End|PageDown) focus=$(( NROWS - 1 )) ;;
                    [1-9]) [ ${KEY} -le ${NROWS} ] && focus=$(( KEY - 1 )) ;;
                    Backspace|Delete) snapv "${row}"; setv "${row}" "${V}" ;;   # 還原這一項
                    Left|H)   dir=-1 ;;
                    Right|L)  dir=1 ;;
                    Space)    dir=2 ;;   # 空白鍵：單選是「下一個」，複選是「勾／取消」
                esac
                [ ${dir} = 0 ] && continue
                item_range "${row}"
                if [ "${row}" = langs ]; then
                    if [ ${dir} = 2 ]; then
                        id="${IT_ID[IS + chip]}"; set=""
                        # 照清單的順序排，不然同樣的選擇會因為勾的先後不同而被當成有變動
                        for k in ja ko en extra; do
                            case ",${LANGS}," in *",${k},"*) [ "${k}" = "${id}" ] || set="${set}${set:+,}${k}" ;;
                                *) [ "${k}" = "${id}" ] && set="${set}${set:+,}${k}" ;; esac
                        done
                        LANGS="${set:-none}"
                    else chip=$(( (chip + dir + IN) % IN )); fi
                else
                    [ ${dir} = 2 ] && dir=1
                    optv "${row}"; item_of "${row}" "${V}"; ni=${POS}; [ ${ni} -lt 0 ] && ni=0
                    ni=$(( (ni + dir + IN) % IN ))
                    setv "${row}" "${IT_ID[IS + ni]}"
                fi
            done
            tui_restore
            trap - INT TERM
            return 0
        }

        local use_screen=0 tsize=""
        if [ -n "${TUI_KEYS}" ]; then use_screen=1
        elif [ -z "${NA_PLAIN:-}" ] && [ "${TTY}" = /dev/tty ] && [ -t 1 ] && [ "${TERM:-dumb}" != dumb ]; then
            tsize="$(stty size 2>/dev/null < /dev/tty)"
            case "${tsize}" in *' '*) [ "${tsize% *}" -ge 23 ] 2>/dev/null && [ "${tsize#* }" -ge 72 ] 2>/dev/null && use_screen=1 ;; esac
        fi
        if [ ${use_screen} = 1 ]; then tui_run && SCREEN_DONE=1; fi
    fi

    if [ ${INTERACTIVE} = 1 ] && [ ${SCREEN_DONE} = 0 ]; then
        # ════ 輸入編號的版本（終端機不支援上面那個畫面時用）════
        # 一個畫面列出全部設定：想改哪一項就輸入它的編號，都不改就直接按 Enter。
        # （以前是一題一題問完七題才結束，只想換個主題也得按六次 Enter。）
        local CHOICE="" pick=""
        theme_label() { case "$1" in
            matcha) echo 'Nat Matcha 抹茶奶油色' ;; light) echo 'Nat Light 明亮白底' ;; fluent) echo 'Nat Fluent 低調淡灰＋藍色條' ;; sakura) echo 'Nat Sakura 櫻花粉' ;;
            ocean) echo 'Nat Ocean 海洋藍' ;; latte) echo 'Nat Latte 拿鐵棕' ;; dark) echo 'Nat Dark 深色' ;;
            midnight) echo 'Nat Midnight 午夜藍（深色）' ;; classic) echo 'Nat Classic 經典黃綠' ;; *) echo "$1" ;; esac; }
        langs_label() {
            local out="" l
            for l in ja ko en extra; do
                case ",$1," in *",${l},"*)
                    case "${l}" in ja) out="${out}${out:+、}日文" ;; ko) out="${out}${out:+、}韓文" ;; en) out="${out}${out:+、}英文" ;; extra) out="${out}${out:+、}其他" ;; esac ;;
                esac
            done
            echo "${out:-只有注音}"
        }
        while :; do
            printf '\n\033[36m%s\033[0m\n' '目前的設定'
            printf '  1) 主題　　　　　%s\n' "$(theme_label "${THEME}")"
            printf '  2) 系統深色模式　%s\n' "$( [ "${DARK}" = "auto" ] && echo '跟隨系統（深色模式時換成 Nat Dark）' || echo '不跟隨' )"
            printf '  3) 候選排列　　　%s\n' "$( [ "${LAYOUT}" = "horizontal" ] && echo '橫排' || echo '直排' )"
            printf '  4) 候選字級　　　%s\n' "$( case "${SIZE}" in (small) echo '小' ;; (large) echo '大' ;; (*) echo '中' ;; esac )"
            printf '  5) 候選附 emoji　%s\n' "$( [ "${EMOJI}" = "off" ] && echo '關' || echo '開' )"
            printf '  6) 選單裡的語言　%s\n' "$(langs_label "${LANGS}")"
            printf '  7) 釋義語言　　　%s\n' "$( case "${GLOSS}" in (en) echo '英文' ;; (ja) echo '日文' ;; (*) echo '中文' ;; esac )"
            printf '  8) 候選字型　　　%s\n' "$( [ "${FONT}" = "system" ] && echo '系統字型（蘋方）' || echo '粉圓體' )"
            # 最常見的「換了主題怎麼沒變」：系統在深色模式＋跟隨系統，看到的一直是 Nat Dark
            if dark_note_needed; then
                printf '\033[90m%s\033[0m\n' '  ※ 系統現在是深色模式，所以候選窗顯示的是 Nat Dark；第 1 項的主題要等系統切回淺色才看得到。'
                printf '\033[90m%s\033[0m\n' '    想在深色模式也用第 1 項的主題：把第 2 項改成「不跟隨」。'
            fi
            ask '  輸入編號 1-8 修改那一項；直接按 Enter 套用：'
            pick="${REPLY}"
            [ -z "${pick}" ] && break
            case "${pick}" in
            1)  choose_one '主題（候選窗配色，長相見 README 的預覽圖）' "${THEME}" \
                    matcha 'Nat Matcha   抹茶奶油色（預設）' light 'Nat Light    明亮白底' fluent 'Nat Fluent   低調淡灰＋藍色條' \
                    sakura 'Nat Sakura   櫻花粉' \
                    ocean 'Nat Ocean    海洋藍' latte 'Nat Latte    拿鐵棕' dark 'Nat Dark     深色' \
                    midnight 'Nat Midnight 午夜藍（深色）' classic 'Nat Classic  經典黃綠'
                THEME="${CHOICE}" ;;
            2)  choose_one '系統深色模式' "${DARK}" \
                    auto '跟隨系統：系統切到深色模式時，候選窗自動換成 Nat Dark（預設）' off '不跟隨：永遠用上面選的主題'
                DARK="${CHOICE}" ;;
            3)  choose_one '候選排列' "${LAYOUT}" vertical '直排（預設）' horizontal '橫排'
                LAYOUT="${CHOICE}" ;;
            4)  choose_one '候選字級' "${SIZE}" small '小' medium '中（預設）' large '大'
                SIZE="${CHOICE}" ;;
            5)  choose_one '打字時候選附帶 emoji（之後仍可在方案選單臨時切換）' "${EMOJI}" \
                    on '開：候選裡附帶對應的 emoji（預設）' off '關'
                EMOJI="${CHOICE}" ;;
            6)  local cur_nums="" i=1 l mark picked tok bad
                printf '\n\033[36m%s\033[0m\n' '方案選單要放哪些語言（注音一定有）'
                for l in ja ko en extra; do
                    case ",${LANGS}," in *",${l},"*) mark='*'; cur_nums="${cur_nums}${cur_nums:+ }${i}" ;; *) mark=' ' ;; esac
                    case "${l}" in
                        ja) printf '  %s %d) %s\n' "${mark}" ${i} '日文' ;;
                        ko) printf '  %s %d) %s\n' "${mark}" ${i} '韓文' ;;
                        en) printf '  %s %d) %s\n' "${mark}" ${i} '英文' ;;
                        extra) printf '  %s %d) %s\n' "${mark}" ${i} '其他：注音文、全形、英文大寫、英文附釋義、符號' ;;
                    esac
                    i=$(( i + 1 ))
                done
                while :; do
                    ask "  可複選，用空白隔開，例如 1 3；0＝都不要（直接按 Enter＝${cur_nums:-都不要}）："
                    [ -z "${REPLY}" ] && break
                    if [ "${REPLY}" = "0" ]; then LANGS="none"; break; fi
                    picked=""; bad=0
                    for tok in $(printf '%s' "${REPLY}" | tr ',' ' '); do
                        case "${tok}" in
                            1) l=ja ;; 2) l=ko ;; 3) l=en ;; 4) l=extra ;;
                            *) bad=1; l="" ;;
                        esac
                        if [ -n "${l}" ]; then case ",${picked}," in *",${l},"*) ;; *) picked="${picked}${picked:+,}${l}" ;; esac; fi
                    done
                    if [ ${bad} = 0 ] && [ -n "${picked}" ]; then LANGS="${picked}"; break; fi
                    say '  請輸入清單上的數字。'
                done ;;
            7)  choose_one '日文／英文候選的釋義要用哪種語言顯示' "${GLOSS}" zh '中文（預設）' en '英文' ja '日文'
                GLOSS="${CHOICE}" ;;
            8)  choose_one '候選字型' "${FONT}" \
                    huninn '粉圓體：圓潤的開源字型 jf open 粉圓（預設；沒裝會自動下載安裝，約 5 MB）' system '系統字型：蘋方'
                FONT="${CHOICE}" ;;
            *)  say '  請輸入清單上的數字。' ;;
            esac
        done
    fi
    # 檢查（參數／環境變數／手改的檔頭都可能給出不認得的值）
    local scheme scheme_dark pts
    scheme="$(theme_scheme "${THEME}")" || { die "不認得的主題：${THEME}（可用：matcha light fluent sakura ocean latte dark midnight classic）"; return 1; }
    # 本身就是深色的主題：系統深色模式時不必再換
    # 不跟隨、或主題本身就是深色 → theme_dark 留空（~），深色模式直接沿用 color_scheme。
    # 不可以寫成跟 theme 同名：那會把深色模式釘死在安裝當下的主題（原委見 rime-apply.ps1）。
    case "${THEME}" in dark|midnight) [ "${DARK}" = "auto" ] && scheme_dark="~" ;; esac
    case "${DARK}" in auto) scheme_dark="${scheme_dark:-NatDark}" ;; off) scheme_dark="~" ;; *) die "不認得的深色模式設定：${DARK}（可用：auto off）"; return 1 ;; esac
    pts="$(size_points "${SIZE}")" || { die "不認得的字級：${SIZE}（可用：small medium large）"; return 1; }
    case "${FONT}" in huninn|system) ;; *) die "不認得的字型：${FONT}（可用：huninn system）"; return 1 ;; esac

    # ── 字型：粉圓體（jf open 粉圓，SIL OFL 授權的開源字型）──
    # 沒裝才下載，裝在使用者自己的 ~/Library/Fonts，不需要管理員密碼。
    # 下載失敗就退回系統字型，不中斷安裝。鼠鬚管認字型用的是 PostScript 名稱 jf-openhuninn-2.1。
    local FONT_DIR="${NA_FONT_DIR:-${HOME}/Library/Fonts}" FONT_URL="${NA_FONT_URL:-https://github.com/justfont/open-huninn-font/releases/download/v2.1/jf-openhuninn-2.1.ttf}"
    if [ "${FONT}" = "huninn" ]; then
        # 兩個資料夾各自檢查：寫成一個 ls 的話，只要其中一個沒有就算失敗，每次都會重新下載
        local have_font=0 ff
        for ff in "${FONT_DIR}"/jf-openhuninn-*.ttf /Library/Fonts/jf-openhuninn-*.ttf; do [ -f "${ff}" ] && have_font=1; done
        if [ ${have_font} = 0 ]; then
            step '下載並安裝粉圓體（jf open 粉圓，約 5 MB）'
            mkdir -p "${FONT_DIR}"
            if curl -fsSL "${FONT_URL}" -o "${FONT_DIR}/jf-openhuninn-2.1.ttf.part" \
               && [ "$(wc -c < "${FONT_DIR}/jf-openhuninn-2.1.ttf.part")" -gt 1000000 ]; then
                mv "${FONT_DIR}/jf-openhuninn-2.1.ttf.part" "${FONT_DIR}/jf-openhuninn-2.1.ttf"
                ok '已安裝 jf open 粉圓 2.1'
            else
                rm -f "${FONT_DIR}/jf-openhuninn-2.1.ttf.part"
                warn '粉圓體下載失敗，先改用系統字型。之後重跑安裝指令可以再試。'
                FONT=system
            fi
        fi
    fi
    local mac_font='PingFangTC-Semibold' mac_comment='PingFangTC-Regular' win_font='Microsoft JhengHei:bold, Segoe UI Emoji' win_comment='Microsoft JhengHei, Segoe UI'
    if [ "${FONT}" = "huninn" ]; then
        # 粉圓體只有一種字重。後面接蘋方／正黑當後備，粉圓沒有的字才會用到。
        mac_font='jf-openhuninn-2.1, PingFangTC-Semibold'; mac_comment='jf-openhuninn-2.1, PingFangTC-Regular'
        win_font='jf open 粉圓 2.1, Microsoft JhengHei, Segoe UI Emoji'; win_comment='jf open 粉圓 2.1, Microsoft JhengHei, Segoe UI'
    fi
    case "${LAYOUT}" in vertical|horizontal) ;; *) die "不認得的排列：${LAYOUT}（可用：vertical horizontal）"; return 1 ;; esac
    case "${EMOJI}" in on|off) ;; *) die "不認得的 emoji 設定：${EMOJI}（可用：on off）"; return 1 ;; esac
    local gnum
    gnum="$(gloss_num "${GLOSS}")" || { die "不認得的釋義語言：${GLOSS}（可用：zh en ja）"; return 1; }
    # 語言：正規化成固定順序、去重
    local norm="" l want
    want=",$(printf '%s' "${LANGS}" | tr ' ' ','),"
    for l in $(printf '%s' "${LANGS}" | tr ',' ' '); do
        case "${l}" in ja|ko|en|extra|none) ;; *) die "不認得的語言：${l}（可用：ja ko en extra none）"; return 1 ;; esac
    done
    for l in ja ko en extra; do
        case "${want}" in *",${l},"*) norm="${norm}${norm:+,}${l}" ;; esac
    done
    LANGS="${norm:-none}"

    local horizontal=false mac=stacked emoji_num=1
    [ "${LAYOUT}" = "horizontal" ] && { horizontal=true; mac=linear; }
    [ "${EMOJI}" = "off" ] && emoji_num=0

    # 只重寫內容真的變了的檔：RIME 是看檔案時間決定要不要重編的，沒變卻重寫等於白白重編一輪。
    # 用法：先把內容寫進 ${OPT_TMP}，再 write_option <目標檔>（不能用管線接：管線右邊是子 shell，計數帶不出來）
    local OPT_CHANGED=0 OPT_TMP="${RIME_DIR}/.na_option.tmp"
    write_option() {
        if [ -f "$1" ] && cmp -s "${OPT_TMP}" "$1"; then rm -f "${OPT_TMP}"; return 0; fi
        mv "${OPT_TMP}" "$1" || return 1
        OPT_CHANGED=$(( OPT_CHANGED + 1 ))
    }
    local note='# ↓ 這行是給安裝腳本讀「上次選了什麼」用的，手動改值時請一起改，或整行刪掉。'
    {
        printf '%s\n' "# na_style.custom.yaml — 個人選項：候選窗的長相（由 '/setup 產生，不進版控）"
        printf '%s\n' "# 想換：輸入法裡打 '/setup；或手動改下面的值後重新部署。各鍵說明見 na_style.yaml。"
        printf '%s\n' "${note}"
        printf '# na-options: theme=%s dark=%s layout=%s size=%s font=%s\n' "${THEME}" "${DARK}" "${LAYOUT}" "${SIZE}" "${FONT}"
        printf 'patch:\n'
        printf '  theme: %s\n' "${scheme}"
        printf '  theme_dark: %s\n' "${scheme_dark}"
        printf '  font_point: %s\n  label_font_point: %s\n  mac_font_point: %s\n  mac_label_font_point: %s\n' ${pts}
        printf '  font_face: "%s"\n  comment_font_face: "%s"\n  mac_font_face: "%s"\n  mac_comment_font_face: "%s"\n' "${win_font}" "${win_comment}" "${mac_font}" "${mac_comment}"
        printf '  horizontal: %s\n' "${horizontal}"
        printf '  candidate_list_layout: %s\n' "${mac}"
    } > "${OPT_TMP}" && write_option "${STYLE_FILE}" || { die "寫不進 ${STYLE_FILE}"; return 1; }
    {
        printf '%s\n' "# na_input.custom.yaml — 個人選項：輸入時的行為（由 '/setup 產生，不進版控）"
        printf '%s\n' "# 想換：輸入法裡打 '/setup；或手動改下面的值後重新部署。各鍵說明見 na_input.yaml。"
        printf '%s\n' "${note}"
        printf '# na-options: emoji=%s gloss=%s\n' "${EMOJI}" "${GLOSS}"
        printf 'patch:\n'
        printf '  emoji: %s\n' "${emoji_num}"
        printf '  gloss: %s\n' "${gnum}"
    } > "${OPT_TMP}" && write_option "${INPUT_FILE}" || { die "寫不進 ${INPUT_FILE}"; return 1; }
    {
        printf '%s\n' "# na_menu.custom.yaml — 個人選項：方案選單裡的語言（由 '/setup 產生，不進版控）"
        printf '%s\n' "# 想換：輸入法裡打 '/setup；或手動改下面的清單後重新部署。說明見 na_menu.yaml。"
        printf '%s\n' "${note}"
        printf '# na-options: langs=%s\n' "${LANGS}"
        printf 'patch:\n'
        printf '  schema_list:\n'
        printf '    - { schema: bopomo_onionplus } # 注音Na+\n'
        for l in ja ko en extra; do
            case ",${LANGS}," in *",${l},"*)
                lang_schemas "${l}" | while IFS="$(printf '\t')" read -r sid sname; do
                    printf '    - { schema: %s } # %s\n' "${sid}" "${sname}"
                done ;;
            esac
        done
    } > "${OPT_TMP}" && write_option "${MENU_FILE}" || { die "寫不進 ${MENU_FILE}"; return 1; }
    if [ ${OPT_CHANGED} -gt 0 ]; then step '已寫入選項'; else step '選項沒有變動'; fi
    say "    主題 ${THEME}｜深色模式 ${DARK}｜排列 ${LAYOUT}｜字級 ${SIZE}｜字型 ${FONT}｜emoji ${EMOJI}｜語言 ${LANGS}｜釋義 ${GLOSS}"

    # ── [5] 套用檔案＋重新部署 ────────────────────────────────────────
    # 交給 repo 裡的 rime-update.command：把 rime/ 攤平複製到使用者資料夾，有變動才重新部署。
    # 個人選項檔不是它複製的、它看不到，所以選項有變（或第一次安裝）時由這裡加 --force。
    # 以前不管有沒有變都 --force，只是進來看一眼選項也要重新部署一輪。
    if [ -n "${NO_DEPLOY}" ]; then
        step '套用檔案（--no-deploy：不重新部署）'
        NA_RIME_DIR="${RIME_DIR}" NA_SQUIRREL="${SQUIRREL}" bash "${SRC_DIR}/scripts/rime-update.command" --skip-pull --no-pause --no-deploy \
            || { die '套用沒有成功，請看上面的訊息。'; return 1; }
    elif [ ${FIRST_INSTALL} = 1 ] || [ ${OPT_CHANGED} -gt 0 ]; then
        if [ ${FIRST_INSTALL} = 1 ]; then step '套用檔案並重新部署（第一次要編譯詞典，約 2～5 分鐘；期間輸入法可能暫時沒反應）'
        else step '套用檔案並重新部署'; fi
        NA_RIME_DIR="${RIME_DIR}" NA_SQUIRREL="${SQUIRREL}" bash "${SRC_DIR}/scripts/rime-update.command" --skip-pull --no-pause --force \
            || { die '套用／部署沒有成功，請看上面的訊息。'; return 1; }
    else
        step '套用檔案（有變動才重新部署）'
        NA_RIME_DIR="${RIME_DIR}" NA_SQUIRREL="${SQUIRREL}" bash "${SRC_DIR}/scripts/rime-update.command" --skip-pull --no-pause \
            || { die '套用／部署沒有成功，請看上面的訊息。'; return 1; }
    fi

    say ''
    printf '\033[32m✓ 完成。\033[0m\n'
    say "  ‧ 設定來源放在 ${SRC_DIR}（更新靠它，請不要刪）"
    say "  ‧ 想重選主題／語言／emoji：再跑一次同一行安裝指令（或 bash \"${SRC_DIR}/install.sh\" --local）"
    cat <<'TIPS'
  ‧ 切到鼠鬚管後按 Ctrl+` 開方案選單；打 '/h 再按空白鍵可開速查表
  ‧ 之後更新：輸入法內打 '/git 再按空白鍵

  還有兩件事要手動做（macOS 系統設定，腳本改不到）：
  1. 系統設定 → 鍵盤 → 輸入方式：關閉「使用大寫鎖定鍵切換輸入法」
     （否則 Caps Lock 會被系統攔走，中英切換失效）
  2. 系統設定 → 鍵盤：開啟「將 F1、F2 等按鍵作為標準功能鍵」
     （否則 F4 叫不出方案選單；不想開的話改用 Ctrl+` 開選單、Ctrl+Opt+1~4 切方案）
  部署出錯時看日誌：tail -50 "$(ls -t /tmp/rime.squirrel.ERROR* | head -1)"

TIPS
}

main "$@"
