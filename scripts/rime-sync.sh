#!/bin/bash
# rime-sync.sh — macOS（鼠鬚管）設定同步
# 只同步「設定檔」：git pull → 重新部署 → git commit/push
# 打字紀錄（詞頻資料庫）不進版控，各機器獨立。
# 用法：bash ~/Library/Rime/scripts/rime-sync.sh

set -euo pipefail
RIME_DIR="$HOME/Library/Rime"
SQUIRREL="/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"
cd "$RIME_DIR"

echo '[1/3] git pull...'
git pull --rebase origin main

echo '[2/3] 重新部署（套用遠端設定）...'
"$SQUIRREL" --reload
sleep 15

echo '[3/3] git commit / push...'
git add -A
if [[ -n "$(git status --porcelain)" ]]; then
    git commit -m "config: natlee-mac $(date '+%Y-%m-%d %H:%M')"
    git push origin main
    echo '完成：已推送本機設定變更。'
else
    echo '完成：無變更需要推送。'
fi
