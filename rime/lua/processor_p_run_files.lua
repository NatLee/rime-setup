--- @@ p_run_files
--[[
'/ 選單與指令的「選中即執行」。

兩件事：
  ① 分層選單（'/、'/dev、'/set…）：選中一列就進到那個功能，或直接執行（開速查表、跑更新…）。
  ② 一級指令代碼（'/h、'/git、'/phrase、'/cmd）：打完按空白／Enter 直接執行。

⚠ 在 engine/processors 裡要排在 mix_apc_s2rm_ltk、p_select_keys、selector、speller 之前，
  否則空白／選字鍵會先被它們拿去上屏，選單只會吐出候選文字本身。
  （schema_cycle 排在它前面沒關係，那個只認右 Shift。）
--]]

local generic_open = require("p_components/p_generic_open")
local run_pattern  = require("p_components/p_run_pattern")
local menu_data    = require("mf_components/mf_menu_data")
local registry     = require("mf_components/core/registry")
local key_util     = require("p_components/p_key_util")

local kAccepted, kNoop = 1, 2

local function init(env)
  local config = env.engine.schema.config
  env.prefix = config:get_string("mf_translator/prefix") or ""
  -- 選字鍵（本方案是 Shift+1~6 → "!@#$%^"）。從設定讀，不寫死，改了選字鍵這裡自動跟上。
  -- 本方案**故意不設** menu/alternative_select_keys（設了 macOS 的候選標籤就只會顯示
  -- !@#$%^，見 lua/processor_p_select_keys.lua），所以字串改放在 p_select_keys/keys；
  -- 仍保留讀 menu/alternative_select_keys 的路徑，別的方案照原樣設也認得。
  env.alt_select = config:get_string("menu/alternative_select_keys") or ""
  if env.alt_select == "" then
    env.alt_select = config:get_string("p_select_keys/keys") or ""
  end
  -- 選字鍵是「當頁第幾個」，不是絕對序號；換算時要知道一頁幾列
  env.page_size = config:get_int("menu/page_size") or 6
end

--- 這次按鍵選的是選單的第幾列（1 起算）；不是選擇動作則回 nil。
--- 兩種選法：確認鍵選目前高亮那列；選字鍵（⇧1~6）或小鍵盤數字直接選當頁第 N 列。
local function picked_row(key, repr, seg, env)
  if key_util.is_confirm(repr) then
    return (seg.selected_index or 0) + 1
  end
  local kp = string.match(repr, "^KP_([1-9])$")
  local n = kp and tonumber(kp) or key_util.select_index(key, env.alt_select)
  -- ⇧1 指的是「這一頁的第 1 列」，翻到第 2 頁就要加上該頁起始位置
  return n and key_util.page_base(seg, env.page_size) + n
end

local function processor(key, env)
  if env.prefix == "" then return kNoop end
  local context = env.engine.context
  if context:get_option("ascii_mode") then return kNoop end
  -- 這個 processor 排在鏈首，第一個按鍵時 composition 可能是空的；
  -- 對空 composition 呼叫 back() 是未定義行為（上游註解警告過 core dumped）。
  local comp = context.composition
  if comp:empty() then return kNoop end
  if not key_util.is_plain_press(key) then return kNoop end

  local seg = comp:back()
  if not seg:has_tag("mf_translator") then return kNoop end
  local c_input = context.input
  if #c_input ~= context.caret_pos then return kNoop end   -- 游標不在最後＝還在編輯，不當成選擇

  local repr = key:repr()

  ----------------------------------------------------------------------
  -- ① 分層選單。選單表與 translator 共用 mf_menu_data，候選順序即列序，不另外維護對照表。
  ----------------------------------------------------------------------
  local rows = menu_data.lookup(string.match(c_input, "^" .. env.prefix .. "(.*)$"))
  if rows then
    local n = picked_row(key, repr, seg, env)
    if not n then return kNoop end   -- 其他鍵（含繼續打字）交還給後面的 processor
    local row = rows[n]
    context:clear()
    if row and row.run and run_pattern[row.run] then
      generic_open(run_pattern[row.run].open)     -- 直接執行（開速查表、跑更新腳本…）
    elseif row and row.key then
      context:push_input(env.prefix .. row.key)   -- 進到該功能／子選單
    end
    return kAccepted
  end

  ----------------------------------------------------------------------
  -- ② 一級指令代碼：直接打「前綴 代碼」再按確認鍵，例如 '/h、'/git、'/phrase、'/cmd。
  --
  -- 兩道限制：
  --   a. 只認 p_run_pattern 裡標了 direct = true 的條目。
  --   b. 這個代碼必須真的被 translator 認領（registry.is_direct）。
  --      這個 processor 排在鏈首，少了這道判斷的話，在 p_run_pattern 加一個
  --      鍵名叫 "f" 的條目就會把日期功能整個吃掉（'/f 按空白變成開檔案）。
  --      認領名單由 mf_open_menu.register_direct 產生，它會跳過撞到既有代碼的
  --      條目 —— 兩邊看同一份名單，撞碼就是整條失效，不會半生不熟。
  ----------------------------------------------------------------------
  if not key_util.is_confirm(repr) then return kNoop end
  local code = string.match(c_input, "^" .. env.prefix .. "([a-z]+)$")
  local entry = code and run_pattern[code]
  if entry and entry.direct and registry.is_direct(code) then
    generic_open(entry.open)
    context:clear()
    return kAccepted
  end
  return kNoop
end

return { init = init, func = processor }
