# rime-config

NatLee 的 RIME 輸入法設定，Windows（小狼毫）與 macOS（鼠鬚管）共用。
主方案：注音Na+（bopomo_onionplus，基於 [Onion Rime Files](https://github.com/oniondelta/Onion_Rime_Files) 二次開發），含八股文語言模型、Shift+數字選字、三語候選釋義、NatMatcha 主題。

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

只想「把另一台改好的設定拉下來套用」（不推送本機變更）時，不必開終端機 ——
直接在輸入法裡打 `'/jgit`＋空格即可（`scripts/rime-update.command` / `rime-update.ps1`）。

腳本流程：`git pull` → 重新部署 → `git commit + push`（只提交設定變更）。
兩台機器輪流執行即可；同時改到同一個設定檔時 git 會提示衝突，手動解掉再 push。

## macOS 首次安裝

1. 安裝最新版[鼠鬚管](https://rime.im)（語言模型需要新版內建的 octagram 外掛）
2. 確認這台機器的 SSH key 已加到 GitHub（本 repo 是 private，腳本走 SSH）：`ssh -T git@github.com`
3. 執行 `bash scripts/bootstrap-mac.sh`
   自動備份舊設定 → clone 本 repo 到 `~/Library/Rime` → **從備份還原 `*.userdb` 詞頻** → 建立本機識別檔 → 部署
4. 兩個系統設定要手動改：
   - **鍵盤 → 輸入方式**：關閉「使用大寫鎖定鍵切換輸入法」（否則 Caps 被系統搶走，中英切換失效）
   - **鍵盤**：開啟「將 F1、F2 等按鍵作為標準功能鍵」（否則 F4 叫不出方案選單、`Ctrl+Shift+F1~F4` 也失效）

不想開標準功能鍵的話，Mac 上改用 `Ctrl+` `` ` `` 開方案選單、`Ctrl+Opt+1~4` 直接切方案。

## 常用功能備忘

| 功能 | 操作 |
|---|---|
| **更新設定** | 打 `'/jgit`（或直達碼 `'/git`）＋空格 —— 拉取遠端設定 → 部署 → 重啟，開終端機視窗顯示過程 |
| **速查表** | 打 `'/jh`＋空格（[cheatsheet.html](cheatsheet.html)） |
| 功能總覽 | 打 `'/` 單獨 —— 6 大類的分層選單（指令、更新、日期、計算機、開發工具、編碼），**每個功能都有入口**、不必背代碼，**用 ⇧1~6 或空白選中就直接進入**（不必記代碼） |
| 快捷鍵說明 | `'/kk`、`'/ko` |
| 計算機 | `'/123+45*2`；運算符字母別名 `a`+ `r`− `x`× `v`÷ `s`^ `q`( `w`) |
| 指令清單 | 打 `'/j` —— 速查表、更新設定、常用網站，選中即執行 |
| 方案選單 | `Ctrl+` `` ` ``（Mac 建議用這個）或 `F4` |
| 直接切方案 | `Ctrl+Shift+F1~F4`（Win）／`Ctrl+Opt+1~4`（Mac 備援） |
| 選字 | `Shift+1`～`Shift+6`（標籤 ⇧1.～⇧6.） |
| 中英切換 | `Shift` 或 `Caps Lock` |
| 打出 email | 連按 `email` 後選字 |
| emoji | `` ` `` 開頭 |
| 日期時間等 | `'/` 開頭 |
| 自訂詞 | 編輯 `bopomo_onionplus_phrase.txt` 後重新部署 |

主題定義：Windows 在 `weasel.custom.yaml`、macOS 在 `squirrel.custom.yaml`（配色同步維護，樣式鍵不同勿互抄）。
