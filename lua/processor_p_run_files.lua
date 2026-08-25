--- @@ p_run_files
--[[
快捷鍵開啟檔案/程式/網站
--]]

----------------------------------------------------------------------------------------
local generic_open = require("p_components/p_generic_open")
local run_pattern = require("p_components/p_run_pattern")
local menu_data = require("mf_components/mf_menu_data")
----------------------------------------------------------------------------------------

-- local function generic_open(dest)
--   if os.execute('start "" ' .. dest) then
--     return true
--   elseif os.execute('open ' .. dest) then
--     return true
--   elseif os.execute('xdg-open ' .. dest) then
--     return true
--   end
-- end


local function init(env)
  local engine = env.engine
  local schema = engine.schema
  local config = schema.config
  local namespace1 = "mf_translator"
  local namespace2 = "lua_custom_phrase"
  local path = rime_api.get_user_data_dir()
  env.prefix = config:get_string(namespace1 .. "/prefix") or ""
  env.textdict = config:get_string(namespace2 .. "/user_dict") or ""
  env.custom_phrase = path .. "/" .. env.textdict .. ".txt" or ""
  env.run_pattern = path .. "/lua/p_components/p_run_pattern.lua" or ""
  -- log.info("lua_custom_phrase: \'" .. env.textdict .. ".txt\' Initilized!")  -- 日誌中提示已經載入 txt 短語
end


-- local function p_open_files(key, env)
local function processor(key, env)
  local engine = env.engine
  local context = engine.context
  local c_input = context.input
  local caret_pos = context.caret_pos
  local comp = context.composition
  local seg = comp:back()
  local o_ascii_mode = context:get_option("ascii_mode")

  -- if env.textdict == "" or env.prefix == "" then
  if env.prefix == "" then
    return 2

  elseif o_ascii_mode then
    return 2
  --- prevent segmentation fault (core dumped) （避免進入死循環，有用到 seg=comp:back() 建議使用去排除？）
  elseif comp:empty() then
    return 2
  --- pass release ctrl alt super
  elseif key:release() or key:ctrl() or key:alt() or key:super() then
    return 2

-----------------------------------------------------------------------------

  --- pass not space Return KP_Enter key_num
  elseif key:repr() ~= "space" and key:repr() ~= "Return" and key:repr() ~= "KP_Enter" then
    return 2

-----------------------------------------------------------------------------

  elseif seg:has_tag("mf_translator") then  -- 開頭

    ----------------------------------------------------------------------
    -- 分層選單跳轉：在 '/、'/dt、'/ca 這些選單畫面按空白，
    -- 依「目前高亮的那一列」跳到對應代碼（go）或直接執行（run）。
    -- 舊版選單的候選文字是 ①②③，選下去只會上屏一個圈圈數字 —— 等於沒反應。
    -- 選單表與 translator 共用 mf_menu_data，索引即列序，不另外維護對照。
    ----------------------------------------------------------------------
    local menu_code = string.match(c_input, "^" .. env.prefix .. "(.*)$")
    local menu = menu_code and menu_data.menus[menu_code]
    if menu and #c_input == caret_pos then
      local row = menu.rows[(seg.selected_index or 0) + 1]
      context:clear()
      if row and row.run and run_pattern[row.run] then
        generic_open(run_pattern[row.run].open)
      elseif row and row.go then
        context:push_input(env.prefix .. row.go)
      end
      -- 純說明列（沒有 go/run）：收起選單就好
      return 1
    end

    -- 一般開啟碼要打「前綴 j 開啟碼」；'/git 是唯一的直達碼（少打一個 j，
    -- 因為這個功能會常用）。直達碼只認完全相符的 "git"，不會攔到其他輸入。
    local op_code = #c_input == caret_pos and (
         string.match(c_input, "^" .. env.prefix .. "j([a-z]+)$")
      or string.match(c_input, "^" .. env.prefix .. "(git)$")
    )
    local run_in = run_pattern[ op_code ] -- 此處不能「.open」，如 op_code 不符合會報錯！
    if op_code then
      if op_code == "t" then
        -- engine:commit_text( "TEST！！！" )  -- 測試用
        generic_open(env.run_pattern)
        context:clear()
        return 1
      elseif run_in ~= nil then
        -- engine:commit_text(run_in)  -- 測試用
        generic_open(run_in.open)  -- 要確定 run_in 不為 nil，才能加.open
        context:clear()
        return 1
      elseif env.textdict == "" then
        return 2
      elseif op_code == "c" then
        -- io.popen("env.custom_phrase")  -- 無效！
        generic_open(env.custom_phrase)
        context:clear()
        return 1
      else  -- 沒有該碼，空白鍵清空
        -- context:confirm_current_selection()
        context:clear()
        return 1
      end
    end
  end

  return 2 -- kNoop
end

-- return p_run_files
-- return { func = processor }
return { init = init, func = processor }