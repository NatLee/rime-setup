#!/bin/bash
# bootstrap-mac.sh — macOS 首次安裝（只需執行一次）
# 先決條件：已安裝鼠鬚管（https://rime.im，建議最新版，需內建 octagram 外掛支援語言模型）
# 用法：下載本檔後執行 bash bootstrap-mac.sh

set -euo pipefail
RIME_DIR="$HOME/Library/Rime"
REPO="https://github.com/NatLee/rime-config.git"
SQUIRREL="/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"

# 1. 備份既有設定（若存在且尚未是 git repo）
if [[ -d "$RIME_DIR" && ! -d "$RIME_DIR/.git" ]]; then
    BACKUP="$RIME_DIR.backup.$(date +%Y%m%d%H%M)"
    echo "備份既有設定到 $BACKUP"
    mv "$RIME_DIR" "$BACKUP"
fi

# 2. Clone 設定 repo
if [[ ! -d "$RIME_DIR/.git" ]]; then
    git clone "$REPO" "$RIME_DIR"
fi

# 3. 建立本機識別檔（已被 .gitignore 排除，不會被提交；
#    sync_dir 僅供 RIME 本機備份詞庫用，不進 git）
if [[ ! -f "$RIME_DIR/installation.yaml" ]]; then
    cat > "$RIME_DIR/installation.yaml" <<EOF
installation_id: "natlee-mac"
sync_dir: '$HOME/Library/Rime/sync'
EOF
    echo '已建立 installation.yaml（natlee-mac）'
fi

# 4. 部署
if [[ -x "$SQUIRREL" ]]; then
    "$SQUIRREL" --reload
    echo '安裝完成！'
else
    echo '找不到鼠鬚管，請先安裝：https://rime.im'
    exit 1
fi

echo ''
echo '⚠️ 別忘了手動做這件事：'
echo '   系統設定 → 鍵盤 → 輸入方式：關閉「使用大寫鎖定鍵切換輸入法」'
