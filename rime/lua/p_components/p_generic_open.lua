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

--[[
Windows：批次檔（'/setup、'/git 的啟動器）用 `start "" cmd /c ""路徑""` 開。

‧ 明寫 cmd /c：只寫 `start "" "x.cmd"` 的話 start 是用 cmd /K 跑批次檔，跑完視窗不會關。
‧ 路徑外面包兩層引號（""…""）：cmd /c 後面的字串只要不是「剛好一對引號」，它就把頭尾那對
  引號剝掉再執行，包兩層剝完剛好剩一層（帶空白、括號的路徑實測過）。
‧ 斜線換成反斜線，cmd 才不會把 / 當成選項。
‧ 不要用 start /b 讓批次檔沿用同一個主控台來省一個視窗：下面是用 popen 啟動的，
  沿用的話批次檔的輸出會接到 popen 的管線上，畫面上什麼都看不到（試過）。
--]]
local function windows_command(dest)
  local script = dest:match('^"(.+%.[cC][mM][dD])"$') or dest:match('^"(.+%.[bB][aA][tT])"$')
  if script then
    return 'start "" cmd /c ""' .. (script:gsub("/", "\\")) .. '""'
  end
  return 'start "" ' .. dest
end

-- 這個系統上要執行的完整指令；認不出系統時回 nil
local function command_for(dest)
  local os_name = get_os_name()
  if os_name == "Windows" then return windows_command(dest) end
  local launcher = launchers[os_name]
  return launcher and (launcher .. dest)
end

-- 同時吃下 Lua 5.1（回傳 exit code，0＝成功）與 5.4（回傳 true/false, "exit", code）
local function succeeded(a, _, code)
  if type(a) == "number" then return a == 0 end
  if a == true then return true end
  if type(code) == "number" then return code == 0 end
  return false
end

--[[
⚠ Windows 上不可以用 os.execute 開東西 —— 輸入法會整個卡住五秒。

os.execute 是 C 的 system()：起一個 `cmd /c <指令>`，**等它結束**才返回。輸入法服務
（WeaselServer）沒有主控台，系統得先替這個 cmd 開一個主控台視窗，cmd 才跑得起來。
實機量到的（在選項畫面印出來的分段時間）：

    從按下到選單 5.7 秒：輸入法卡在 os.execute 5.3 秒｜批次檔 5.3 秒後才開始跑｜腳本 0.4 秒

同一條指令從「不是輸入法服務」的行程呼叫 system()，只要 0.12 秒。差別只在呼叫的人是誰，
所以推測是互等：服務卡在 system() 裡不回應 → 新視窗一出現就要連輸入法（它也是輸入法的
用戶端）→ 連不上 → 主控台起不來 → cmd 不結束 → system() 不返回，直到某個五秒的逾時放行。
（互等的細節是推測，沒有在原始碼裡找到那個逾時；「卡 5.3 秒」與「換個行程就不卡」是量到的。）

io.popen 建立行程後馬上返回、不等它結束（實測 8～10 ms），服務立刻能回應，就沒有互等。
改完同一台實機：從按下到選單 5.7 秒 → 0.8 秒，輸入法卡住 5.3 秒 → 0.0 秒（連測三次）。
回傳的 handle 不可以馬上 close（close 會等行程結束，等於又卡回去），留到下次再關。
--]]
local pending_handle

local function spawn(command)
  if get_os_name() ~= "Windows" then
    return succeeded(os.execute(command))
  end
  if pending_handle then
    pcall(pending_handle.close, pending_handle)   -- 上一次的過渡 cmd 早就結束了，這裡不會等
    pending_handle = nil
  end
  local ok, handle = pcall(io.popen, command, "r")
  if ok and handle then
    pending_handle = handle
    return true
  end
  return succeeded(os.execute(command))   -- 這個建置的 lua 沒有 popen 時才會走到
end

-- 測試用的保險：使用者資料夾裡有 na_test_open.log 這個檔，就只把「本來要開的東西」記進去，
-- 不真的開。沙盒回歸測試（tools/rime-test.ps1）每次都會建這個檔 —— 以前沒有這道保險，
-- 測「選單選中即執行」只要選到速查表那一列，每跑一次測試就真的開一次瀏覽器；
-- 選到「更新設定」那一列更會真的跑 git pull＋部署。正式的使用者資料夾不會有這個檔。
-- 用檔案而不是環境變數：Lua 的 os.getenv 讀的是 C 執行階段啟動時的快照，
-- 測試行程中途才設的環境變數它不一定看得到。
local user_dir = (rime_api and rime_api.get_user_data_dir()) or "."
local dry_run_log = user_dir .. "/na_test_open.log"

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

-- 啟動時間的量測：開批次檔之前留一個時間戳（檔案的修改時間就是「按下去」的時刻），啟動的
-- 指令返回後再留一個。選項畫面（install.ps1）列出來時拿它們算出「從按下到這裡」分段各花多久，
-- 印在標題旁並寫進 na_launch.log。「'/setup 很慢」慢在哪一段，只有真的從輸入法服務啟動時
-- 量得到；從外面模擬，量到的是另一種行程的啟動時間（上面那個五秒就是這樣找到的）。
local function stamp(name)
  local f = io.open(user_dir .. "/" .. name, "w")
  if f then f:write("launch\n") f:close() end
end

local function generic_open(dest)
  local command = command_for(dest)
  -- 測試時記下「完整的指令」而不只是目標，啟動方式改壞了回歸才抓得到
  if dry_run(command or dest) then return true end
  if command then
    local timed = command:find(" cmd /c ", 1, true) ~= nil
    if timed then stamp("na_launch.stamp") end
    local ok = spawn(command)
    if timed then stamp("na_launch.ret") end
    return ok
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
