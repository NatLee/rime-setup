--[[
開啟檔案/程式/網址（跨平台）

原本的寫法是依序 `start` → `open` → `xdg-open`，靠前一個「失敗」才往下走。
這在 macOS 上有兩個問題：
  1. `start` 不存在，shell 會噴 `sh: start: command not found`（雜訊）。
  2. os.execute 的回傳值語意隨 Lua 版本不同：Lua 5.4 失敗回 false，
     Lua 5.1／LuaJIT 卻是回 exit code（127 在 Lua 裡是「真值」），
     會被誤判成「開啟成功」而永遠不試 `open`。
改成先問作業系統，行為就與 librime-lua 的建置方式無關。
--]]

local get_os_name = require("f_components/f_get_os_name")

local launchers = {
  Windows = 'start "" ',
  Mac     = 'open ',
  Linux   = 'xdg-open ',
  BSD     = 'xdg-open ',
  Solaris = 'xdg-open ',
}

-- 同時吃下 Lua 5.1（回傳 exit code，0＝成功）與 5.4（回傳 true/false, "exit", code）
local function succeeded(a, _, code)
  if type(a) == "number" then return a == 0 end
  if a == true then return true end
  if type(code) == "number" then return code == 0 end
  return false
end

-- 測試用的保險：使用者資料夾裡有 na_test_open.log 這個檔，就只把「本來要開的東西」記進去，
-- 不真的開。沙盒回歸測試（tools/rime-test.ps1）每次都會建這個檔 —— 以前沒有這道保險，
-- 測「選單選中即執行」只要選到速查表那一列，每跑一次測試就真的開一次瀏覽器；
-- 選到「更新設定」那一列更會真的跑 git pull＋部署。正式的使用者資料夾不會有這個檔。
-- 用檔案而不是環境變數：Lua 的 os.getenv 讀的是 C 執行階段啟動時的快照，
-- 測試行程中途才設的環境變數它不一定看得到。
local dry_run_log = ((rime_api and rime_api.get_user_data_dir()) or ".") .. "/na_test_open.log"

local function dry_run(dest)
  local probe = io.open(dry_run_log, "r")
  if not probe then return false end
  probe:close()
  local log = io.open(dry_run_log, "a")
  if log then
    log:write(dest, "\n")
    log:close()
  end
  return true
end

local function generic_open(dest)
  if dry_run(dest) then return true end
  local cmd = launchers[get_os_name()]
  if cmd then
    return succeeded(os.execute(cmd .. dest))
  end
  -- 認不出系統時才退回逐一嘗試
  for _, fallback in ipairs({ 'open ', 'xdg-open ', 'start "" ' }) do
    if succeeded(os.execute(fallback .. dest)) then
      return true
    end
  end
  return false
end

return generic_open
