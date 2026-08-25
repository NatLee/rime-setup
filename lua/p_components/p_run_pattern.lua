--[[
快捷開啟（join/joint）檔案/程式/網址之列表。

- 限起始輸入「前綴」「j」「開啟碼」「上屏鍵」。（限起始輸入：防止輸入長碼，未上屏後接 Lua 功能時，誤按使整個長碼跳掉）
- 「開啟碼」限英文 [a-z]+。
- 「t」「c」兩鍵位已使用於開啟方案內設文件，避免為「開啟碼」。
- 多個同編碼的「開啟碼」，以後面條目為用。
- Win 中 open = "路徑"，其路徑名稱包含「中文（非ASCII編碼）」可能無法開啟。
- s = "數字"，為「前綴」「j」提示選單中的順序，如相同以「開啟碼」排序。

- 修改後需「重新部署」才可生效。
--]]

local user_dir = (rime_api and rime_api.get_user_data_dir()) or ""

local run_pattern = {
  -- ["開啟碼"] = { s = "提示選單上的排序", name = "檔案/程式/網址：名稱", open= "檔案/程式/網址位：路徑和相關參數(如：指定開啟程式)" },
--------------------------------------------------------------------------
-- 通用：
--------------------------------------------------------------------------
  ["h"] = { s = 0, direct = false, name = "輸入法速查表 Cheatsheet", open = '"' .. user_dir .. '/cheatsheet.html"' },
--------------------------------------------------------------------------
-- Mac：
--------------------------------------------------------------------------
  -- ["r"] = { s = 1, name = "Rime 官方 GitHub Ⓕ", open = "-a '/Applications/Firefox.app' https://github.com/rime" },                                                     -- mac 專用：指定程式開啟
  -- ["rw"] = { s = 2, name = "Rime 詳解 Ⓕ", open = "-a '/Applications/Firefox.app' https://github.com/LEOYoon-Tsaw/Rime_collections/blob/master/Rime_description.md" },  -- mac 專用：指定程式開啟
  -- ["l"] = { s = 3, name = "librime-lua 官方 GitHub Ⓕ", open = "-a '/Applications/Firefox.app' https://github.com/hchunhui/librime-lua" },                              -- mac 專用：指定程式開啟
  -- ["lw"] = { s = 4, name = "librime-lua 腳本開發指南 Ⓕ", open = "-a '/Applications/Firefox.app' https://github.com/hchunhui/librime-lua/wiki/Scripting" },              -- mac 專用：指定程式開啟
  -- ["o"] = { s = 5, name = "Onion 洋蔥 GitHub Ⓕ", open = "-a '/Applications/Firefox.app' https://github.com/oniondelta/Onion_Rime_Files" },                             -- mac 專用：指定程式開啟
  -- ["ow"] = { s = 6, name = "Onion 洋蔥 GitHub Wiki Ⓕ", open = "-a '/Applications/Firefox.app' https://github.com/oniondelta/Onion_Rime_Files/wiki" },                  -- mac 專用：指定程式開啟
--------------------------------------------------------------------------
  -- ["at"] = { s = 10, name = "文字編輯器", open = "/System/Applications/TextEdit.app" },               -- mac 專用：文字編輯
  -- ["ac"] = { s = 11, name = "計算機", open = "/System/Applications/Calculator.app" },                -- mac 專用：計算機
  -- ["ad"] = { s = 12, name = "字典", open = "/System/Applications/Dictionary.app" },                  -- mac 專用：字典
--------------------------------------------------------------------------
  -- ["ac"] = { s = 14, name = "CotEditor", open = "/Applications/CotEditor.app" },                    -- mac 專用：一般 app
  -- ["as"] = { s = 15, name = "Sublime", open = "/Applications/Sublime' 'Text.app" },                 -- mac 專用：路徑中空格用「' '」標示
  -- ["as"] = { s = 15, name = "Sublime", open = "/Applications/Sublime\\ Text.app" },                 -- mac 專用：路徑中空格用「\\ 」標示
--------------------------------------------------------------------------
  -- ["ft"] = { s = 16, name = "TEST", open = "-a '/Applications/CotEditor.app' /Users/使用者名稱/test.txt" },         -- mac 專用：指定程式開啟
  -- ["ft"] = { s = 17, name = "TEST", open = "-a '/Applications/Sublime Text.app' /Users/使用者名稱/test' '1.txt" },  -- mac 專用：指定程式開啟（此處前方路徑名稱空格不用更動，後方路徑空格需補「' '」或「\\ 」）
--------------------------------------------------------------------------
-- Win：
--------------------------------------------------------------------------
  -- ["r"] = { s = 1, name = "Rime 官方 GitHub Ⓕ", open = [["C:\Program Files (x86)\Mozilla Firefox\firefox.exe" https://github.com/rime]] },                                                     -- win 專用：指定程式開啟
  -- ["rw"] = { s = 2, name = "Rime 詳解 Ⓕ", open = [["C:\Program Files (x86)\Mozilla Firefox\firefox.exe" https://github.com/LEOYoon-Tsaw/Rime_collections/blob/master/Rime_description.md]] },  -- win 專用：指定程式開啟
  -- ["l"] = { s = 3, name = "librime-lua 官方 GitHub Ⓕ", open = [["C:\Program Files (x86)\Mozilla Firefox\firefox.exe" https://github.com/hchunhui/librime-lua]] },                              -- win 專用：指定程式開啟
  -- ["lw"] = { s = 4, name = "librime-lua 腳本開發指南 Ⓕ", open = [["C:\Program Files (x86)\Mozilla Firefox\firefox.exe" https://github.com/hchunhui/librime-lua/wiki/Scripting]] },              -- win 專用：指定程式開啟
  -- ["o"] = { s = 5, name = "Onion 洋蔥 GitHub Ⓕ", open = [["C:\Program Files (x86)\Mozilla Firefox\firefox.exe" https://github.com/oniondelta/Onion_Rime_Files]] },                             -- win 專用：指定程式開啟
  -- ["ow"] = { s = 6, name = "Onion 洋蔥 GitHub Wiki Ⓕ", open = [["C:\Program Files (x86)\Mozilla Firefox\firefox.exe" https://github.com/oniondelta/Onion_Rime_Files/wiki]] },                  -- win 專用：指定程式開啟
--------------------------------------------------------------------------
  -- ["ac"] = { s = 7, name = "計算機", open = [["C:\WINDOWS\system32\calc.exe"]] },                    -- win 專用：計算機
  -- ["ap"] = { s = 8, name = "小畫家", open = [["C:\WINDOWS\system32\mspaint.exe"]] },                 -- win 專用：小畫家
  -- ["at"] = { s = 9, name = "記事本", open = [["C:\WINDOWS\system32\notepad.exe"]] },                 -- win 專用：記事本
--------------------------------------------------------------------------
  -- ["an"] = { s = 10, name = "Notepad++", open = [["C:\Program Files\Notepad++\notepad++.exe"]] },  -- win 專用：路徑中空格不用更動
--------------------------------------------------------------------------
  -- ["ft"] = { s = 11, name = "TEST", open = [["C:\Program Files\Notepad++\notepad++.exe" C:\Users\使用者名稱\AppData\Roaming\Rime\rime.lua]] },         -- win 專用：指定程式開啟
  -- ["ft"] = { s = 12, name = "TEST", open = [["C:\Program Files\Sublime Text\sublime_text.exe"]].." "..[["C:\Users\使用者名稱\Desktop\test 1.txt"]] },  -- win 專用：指定程式開啟（此處前方路徑名稱空格不用更動，後方路徑空格需用特殊格式）
--------------------------------------------------------------------------
-- 測試用：
--------------------------------------------------------------------------
  -- ["rt"] = "https://github.com/rime",
  -- ["xt"] = { name = "缺省測試" },
  -- ["yt"] = { name = "油管", open = "https://www.youtube.com/" },
--------------------------------------------------------------------------
 }

-- print(run_pattern['r'].name)
-- print(run_pattern['r'].open)
-- print(run_pattern['o'].name)
-- print(run_pattern['o'].open)

-- print(run_pattern['no_item'].open)  -->報錯！！！
-- print(run_pattern['no_item'])       -->nil
-- print(run_pattern['wr'].no_item)    -->nil
-- print(run_pattern[nil])             -->nil

--------------------------------------------------------------------------
-- Windows：覆蓋內建「c」（編輯 custom 短語）。
-- 原因：預設用系統關聯開啟，Notepad++ 這類單一實例編輯器第二次起只會在
-- 「既有視窗」加分頁，背景程序（輸入法）無權把它拉到前景，看起來像沒反應。
-- -multiInst 每次開新程序＝新視窗，可正常跳到前景。
--------------------------------------------------------------------------
local get_os_name = require("f_components/f_get_os_name")
if get_os_name() == "Windows" then
  run_pattern["c"] = { s = 2, name = "編輯 custom 短語（開新視窗）",
    open = [["C:\Program Files\Notepad++\notepad++.exe" -multiInst ]] .. '"' .. user_dir .. '/bopomo_onionplus_phrase.txt"' }
end

--------------------------------------------------------------------------
-- git：拉取遠端設定 → 部署 → 重啟服務。
-- 打 '/git（或 '/jgit）＋空白鍵觸發，會開一個終端機視窗顯示過程。
-- 兩邊的啟動方式不同：
--   macOS   open <.command>              → .command 預設關聯到「終端機」，
--                                          會自己開新視窗跑（檔案需有 +x，git 已記錄 755）。
--                                          不寫 `-a Terminal` 是為了少一個會出錯的環節。
--   Windows start "" pwsh -NoExit -File  → 開新主控台視窗，跑完不自動關
-- 直達碼 '/git 的攔截寫在 processor_p_run_files.lua。
--------------------------------------------------------------------------
-- direct = true：這個指令碼可以不加命名空間直接打（'/git，不必 '/cgit）。
-- 只給常用且不會跟日期時間代碼撞名的指令開放。
if get_os_name() == "Mac" then
  run_pattern["git"] = { s = 1, direct = true, name = "更新設定並重新部署",
    open = '"' .. user_dir .. '/scripts/rime-update.command"' }
elseif get_os_name() == "Windows" then
  run_pattern["git"] = { s = 1, direct = true, name = "更新設定並重新部署",
    open = [[pwsh -NoExit -ExecutionPolicy Bypass -File "]] .. user_dir .. [[/scripts/rime-update.ps1"]] }
end

return run_pattern