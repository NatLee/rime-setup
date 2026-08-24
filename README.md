# rime-config

NatLee 的 RIME 輸入法設定，Windows（小狼毫）與 macOS（鼠鬚管）共用。
主方案：洋蔥注音 plus（bopomo_onionplus），含八股文語言模型、Shift+數字選字、NatMatcha 主題。

## 同步架構

- **只同步設定**：設定檔／方案／詞典／lua 直接走 git（本 repo 就是 RIME 使用者資料夾）
- **打字紀錄（詞頻資料庫）不同步**：`*.userdb/` 與 `sync/` 已被 `.gitignore` 排除，各機器獨立維護，避免互相污染
- **機器專屬檔**（`installation.yaml`、`user.yaml`、`build/`）也已排除，**永遠不要提交**

| 機器 | installation_id | 使用者資料夾 |
|---|---|---|
| Windows | `natlee-windows` | `C:\RIME` |
| macOS | `natlee-mac` | `~/Library/Rime` |

## 日常同步（改了設定或想同步詞庫時執行）

- **Windows**：`pwsh scripts/rime-sync.ps1`
- **macOS**：`bash ~/Library/Rime/scripts/rime-sync.sh`

腳本流程：`git pull` → 重新部署 → `git commit + push`（只提交設定變更）。
兩台機器輪流執行即可；同時改到同一個設定檔時 git 會提示衝突，手動解掉再 push。

## macOS 首次安裝

1. 安裝最新版[鼠鬚管](https://rime.im)（語言模型需要新版內建的 octagram 外掛）
2. 執行 `bash bootstrap-mac.sh`（會自動備份舊設定 → clone 本 repo 到 `~/Library/Rime` → 建立本機識別檔 → 部署）
3. **系統設定 → 鍵盤 → 輸入方式**：關閉「使用大寫鎖定鍵切換輸入法」（避免 Caps 被系統搶走）

## 常用功能備忘

| 功能 | 操作 |
|---|---|
| **速查表** | 打 `'/jh`＋空格，或 Windows 按 `Ctrl+Alt+H`（[cheatsheet.html](cheatsheet.html)） |
| 功能總覽／快捷鍵說明 | 打 `'/` 單獨、`'/kk`、`'/ko` |
| 計算機 | `'/123+45*2`；運算符字母別名 `a`+ `r`− `x`× `v`÷ `s`^ `q`( `w`) |
| 選字 | `Shift+1`～`Shift+6`（標籤 ⇧1.～⇧6.） |
| 中英切換 | `Shift` 或 `Caps Lock` |
| 打出 email | 連按 `email` 後選字 |
| emoji | `` ` `` 開頭 |
| 日期時間等 | `'/` 開頭 |
| 自訂詞 | 編輯 `bopomo_onionplus_phrase.txt` 後重新部署 |

主題定義：Windows 在 `weasel.custom.yaml`、macOS 在 `squirrel.custom.yaml`（配色同步維護，樣式鍵不同勿互抄）。
