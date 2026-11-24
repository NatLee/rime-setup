#!/bin/bash
# rime-sync.sh — macOS（鼠鬚管）設定同步【維護者／fork 擁有者用】
# 會 commit 並 push 到 origin，所以只有對 origin 有寫入權限的人才用得到；
# 一般使用者要更新請在輸入法內打 '/git（那支只拉不推）。
#
# 流程：git pull --rebase → 套用到使用者資料夾（有變動才重新部署）→ git commit + push
# 在 repo 裡改設定（rime/ 底下），改完跑這支，就會套用到這台並推上去。
# 打字紀錄與個人檔（詞頻、個人短語、安裝選項）在使用者資料夾，不在 repo 裡，不會被推。
# 用法：bash scripts/rime-sync.sh

set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO}"

echo '[1/3] git pull...'
git pull --rebase --autostash origin main

echo '[2/3] 套用到使用者資料夾...'
bash "${REPO}/scripts/rime-update.command" --skip-pull --no-pause

echo '[3/3] git commit / push...'
git add -A
if [[ -n "$(git status --porcelain)" ]]; then
    git commit -m "config: mac $(date '+%Y-%m-%d %H:%M')"
    git push origin main
    echo '完成：已推送本機設定變更。'
else
    echo '完成：無變更需要推送。'
fi
