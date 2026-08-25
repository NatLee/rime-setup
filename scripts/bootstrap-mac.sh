#!/bin/bash
# bootstrap-mac.sh — macOS（鼠鬚管）首次安裝，只需執行一次
#
# 先決條件：
#   1. 已安裝鼠鬚管 https://rime.im （需新版，語言模型靠內建 octagram 外掛）
#   2. 這台機器的 SSH key 已加到 GitHub（本 repo 為 private，HTTPS 會卡帳密）
#
# 用法：
#   bash bootstrap-mac.sh
#
# 這支腳本會：
#   備份既有設定 → clone repo 到 ~/Library/Rime → 從備份還原你的打字詞頻
#   → 建立本機識別檔 → 部署

set -euo pipefail

# ⚠ macOS 內建的是 bash 3.2（2007 年，GPLv2 之故一直沒升）。
#   在 3.2 底下，`$VAR` 後面若緊接中文字（例如「$BACKUP，」），
#   變數名會把那個多位元組字元一起吃進去 → `unbound variable`。
#   本檔一律寫 `${VAR}`，不要圖省事拿掉大括號。

RIME_DIR="$HOME/Library/Rime"
REPO_SSH="git@github.com:NatLee/rime-config.git"
SQUIRREL_APP="/Library/Input Methods/Squirrel.app"
SQUIRREL="$SQUIRREL_APP/Contents/MacOS/Squirrel"
BACKUP=""

die() { echo "✗ $*" >&2; exit 1; }

# ── 0. 先決條件 ────────────────────────────────────────────────
command -v git >/dev/null 2>&1 || die '找不到 git，請先執行：xcode-select --install'
[[ -d "$SQUIRREL_APP" ]] || die "找不到鼠鬚管（${SQUIRREL_APP}），請先安裝：https://rime.im"
[[ -x "$SQUIRREL" ]]     || die "鼠鬚管安裝不完整，找不到執行檔：$SQUIRREL"

git ls-remote "$REPO_SSH" >/dev/null 2>&1 \
  || die "無法以 SSH 存取 $REPO_SSH
   請先把這台機器的 SSH key 加到 GitHub，或改用你自己的方式取得 repo。
   測試指令：ssh -T git@github.com"

# ── 1. 備份既有設定 ────────────────────────────────────────────
if [[ -d "$RIME_DIR/.git" ]]; then
    echo "→ ${RIME_DIR} 已經是 git repo，改為拉取最新設定"
    git -C "$RIME_DIR" pull --ff-only || echo "  ⚠ pull 失敗（可能有本機未提交的變更），沿用現有內容繼續"
elif [[ -d "$RIME_DIR" ]]; then
    BACKUP="$RIME_DIR.backup.$(date +%Y%m%d%H%M%S)"
    echo "→ 備份既有設定到 $BACKUP"
    mv "$RIME_DIR" "$BACKUP"
fi

# ── 2. Clone 設定 repo ─────────────────────────────────────────
if [[ ! -d "$RIME_DIR/.git" ]]; then
    echo "→ clone 設定 repo..."
    git clone "$REPO_SSH" "$RIME_DIR"
fi

# ── 3. 還原打字詞頻 ────────────────────────────────────────────
# *.userdb/ 與 sync/ 不進版控（見 .gitignore），但它們是你累積的打字習慣，
# 重裝時要從備份搬回來，否則等於把詞頻歸零。
if [[ -n "$BACKUP" ]]; then
    restored=0
    for db in "$BACKUP"/*.userdb; do
        [[ -d "$db" ]] || continue
        cp -R "$db" "$RIME_DIR/" && restored=$((restored + 1))
    done
    if [[ -d "$BACKUP/sync" ]]; then
        cp -R "$BACKUP/sync" "$RIME_DIR/"
    fi
    echo "→ 已從備份還原 ${restored} 個詞頻資料庫（*.userdb）"
    echo "  備份保留在 ${BACKUP}，確認一切正常後可自行刪除。"
fi

# ── 4. 本機識別檔 ──────────────────────────────────────────────
# 已被 .gitignore 排除，不會被提交。sync_dir 僅供 RIME 本機備份詞庫。
if [[ ! -f "$RIME_DIR/installation.yaml" ]]; then
    cat > "$RIME_DIR/installation.yaml" <<EOF
installation_id: "natlee-mac"
sync_dir: '$HOME/Library/Rime/sync'
EOF
    echo '→ 已建立 installation.yaml（natlee-mac）'
fi

# ── 5. 部署 ────────────────────────────────────────────────────
echo '→ 部署中（首次編譯詞典約需 1～3 分鐘，請耐心等候）...'
"$SQUIRREL" --reload

cat <<'TIPS'

✓ 安裝完成。

還有兩件事要你手動做（macOS 專屬，腳本改不到）：

  1. 系統設定 → 鍵盤 → 輸入方式
     關閉「使用大寫鎖定鍵切換輸入法」
     （否則 Caps Lock 會被系統攔走，中英切換失效）

  2. 系統設定 → 鍵盤
     開啟「將 F1、F2 等按鍵作為標準功能鍵」
     （否則 F4 叫不出方案選單、Ctrl+Shift+F1~F4 也切不了方案；
       不想開的話，改用 Ctrl+` 開選單、Ctrl+Opt+1~4 切方案）

驗證：隨便開個輸入框，按 Ctrl+` 應該跳出方案選單。
TIPS
