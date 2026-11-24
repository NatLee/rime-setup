--[[
指令清單（快捷開啟檔案／程式／網址）。

■ 每個條目就是一個一級 '/ 代碼
  以前要打「'/ + j + 開啟碼」（'/jh、'/jgit），命名空間那一層在清單縮到剩幾條
  之後只是多按一次，已經拿掉。現在直接打 '/h、'/git、'/phrase、'/cmd。

■ 欄位
  ["代碼"] = {
    s      = 選單排序（小的在前，相同再照代碼字母序）
    name   = 顯示名稱（選單的說明文字）
    open   = 檔案／程式／網址；Win 路徑含非 ASCII 字元可能開不起來
    direct = true 才會被掛成一級代碼；沒標的條目形同停用
  }

■ ⚠ 代碼不可以跟既有的 '/ 代碼撞
  '/ 底下已經有 157 個日期時間碼（開頭字母 d f l m n p s t w y z）、
  內碼 x u c o i、字母 / ; '、以及 dt/dty/dts/num/dev/set/code/case/k/v/g/gc。
  撞到的話這個條目會**自動失效**（processor 與 translator 兩邊都會先讓路給
  既有功能，見 processor_p_run_files.lua 的 registry.has_exact 判斷），
  不會把日期之類的功能弄壞，但你新加的指令也不會動。
  查代碼有沒有被佔用：docs/KEYMAP.md 第 5 節，或 pwsh tools\keymap-dump.ps1。

■ 改完要「重新部署」才生效。
--]]

local user_dir = (rime_api and rime_api.get_user_data_dir()) or ""
local get_os_name = require("f_components/f_get_os_name")
local os_name = get_os_name()

local run_pattern = {
--------------------------------------------------------------------------
  ["h"] = { s = 0, direct = true, name = "輸入法速查表 Cheatsheet",
    open = '"' .. user_dir .. '/cheatsheet.html"' },
--------------------------------------------------------------------------
-- 範例：想加常用網站／程式就照這樣寫（記得 direct = true）
--  ["rime"] = { s = 10, direct = true, name = "Rime 官方 GitHub",
--    open = "https://github.com/rime" },
--  Mac 指定程式開啟： open = "-a '/Applications/Firefox.app' https://github.com/rime"
--  Win 指定程式開啟： open = [["C:\Program Files\...\firefox.exe" https://github.com/rime]]
--  Mac 路徑含空格用「' '」或「\ 」標示；Win 路徑含空格不用處理
--------------------------------------------------------------------------
}

--------------------------------------------------------------------------
-- 編輯 自訂短語（打 email 出信箱那種）。
-- Windows 指定 Notepad++ ＋ -multiInst：預設用系統關聯開啟時，Notepad++ 這類
-- 單一實例編輯器第二次起只會在既有視窗加分頁，而背景程序（輸入法）無權把它
-- 拉到前景，看起來就像沒反應。-multiInst 每次開新程序＝新視窗，會正常跳前景。
--------------------------------------------------------------------------
if os_name == "Windows" then
  run_pattern["phrase"] = { s = 1, direct = true, name = "編輯 自訂短語（開新視窗）",
    open = [["C:\Program Files\Notepad++\notepad++.exe" -multiInst ]] ..
           '"' .. user_dir .. '/bopomo_onionplus_phrase.txt"' }
else
  run_pattern["phrase"] = { s = 1, direct = true, name = "編輯 自訂短語",
    open = '"' .. user_dir .. '/bopomo_onionplus_phrase.txt"' }
end

--------------------------------------------------------------------------
-- 編輯 這個檔案本身（要加／改指令就開它）
--------------------------------------------------------------------------
run_pattern["cmd"] = { s = 2, direct = true, name = "編輯 指令清單（本檔）",
  open = '"' .. user_dir .. '/lua/p_components/p_run_pattern.lua"' }

--------------------------------------------------------------------------
-- git：拉取遠端設定 → 部署 → 重啟服務。打 '/git ＋空白鍵觸發，會開一個終端機
-- 視窗顯示過程。兩邊啟動方式不同：
--   macOS   open <.command>              → .command 預設關聯到「終端機」，會自己
--                                          開新視窗跑（檔案需有 +x，git 已記錄 755）
--   Windows start "" pwsh -NoExit -File  → 開新主控台視窗，跑完不自動關
--------------------------------------------------------------------------
if os_name == "Mac" then
  run_pattern["git"] = { s = 3, direct = true, name = "更新設定並重新部署",
    open = '"' .. user_dir .. '/scripts/rime-update.command"' }
elseif os_name == "Windows" then
  run_pattern["git"] = { s = 3, direct = true, name = "更新設定並重新部署",
    open = [[pwsh -NoExit -ExecutionPolicy Bypass -File "]] .. user_dir ..
           [[/scripts/rime-update.ps1"]] }
end

return run_pattern
