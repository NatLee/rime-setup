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
  -- log.info("lua_custom_phrase: \'" .. env.textdict .. ".txt\' Initilized!")  -- 日誌中提示已經載入 txt 短語
end


-- local function p_open_files(key, env)
local function processor(key, env)
  local engine = env.engine
  local context = engine.context
  local c_input = context.input
  local caret_pos = context.caret_pos
  local comp = context.composition
  -- 這個 processor 排在鏈首，第一個按鍵時 composition 可能是空的；
  -- 對空 composition 呼叫 back() 是未定義行為（上游註解警告過 core dumped）。
  local seg = not comp:empty() and comp:back() or nil
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

  ----------------------------------------------------------------------
  -- 分層選單（'/、'/dt、'/ca）：選中一列就進到那個功能或直接執行。
  -- 接受兩種選法 —— 空白／Enter 選目前高亮那列，或 Shift+1~6 直接選第 N 列。
  -- 這段必須放在下面「只收空白/Enter」的過濾之前，選字鍵才進得來；
  -- 也必須排在 engine/processors 的 selector 之前，否則選字鍵會先被拿去上屏。
  -- 選單表與 translator 共用 mf_menu_data，候選順序即列序，不另外維護對照表。
  ----------------------------------------------------------------------
  elseif seg:has_tag("mf_translator")
     and #c_input == caret_pos
     and menu_data.lookup(string.match(c_input, "^" .. env.prefix .. "(.*)$")) then

    local rows = menu_data.lookup(string.match(c_input, "^" .. env.prefix .. "(.*)$"))
    local repr = key:repr()
    local n

    if repr == "space" or repr == "Return" or repr == "KP_Enter" then
      n = (seg.selected_index or 0) + 1
    else
      -- ⇧1~6 進到這裡時已經是 KP_1~KP_6：key_binder 把「Shift＋符號」轉送成
      -- 小鍵盤數字（見 bopomo_onionplus.custom.yaml）。本 processor 排在
      -- key_binder **之前**，所以原始的「!」會先進來一次、在這裡不match（正確，
      -- 交還給後面）；key_binder 轉送後的 KP_n 會從鏈首再跑一遍，這次才命中。
      local kp = string.match(repr, "^KP_([1-9])$")
      if kp then
        n = tonumber(kp)
      else
        -- 相容路徑：方案若真的設了 menu/alternative_select_keys，仍認得該組鍵
        local kc = key.keycode
        local ch = (kc and kc >= 0x20 and kc < 0x7f) and string.char(kc) or nil
        n = ch and env.alt_select ~= "" and string.find(env.alt_select, ch, 1, true) or nil  -- plain find，$ ^ 等不當正規符號
      end
      if n then
        -- ⇧1 指的是「這一頁的第 1 列」，翻到第 2 頁就要加上該頁起始位置
        local ps = env.page_size
        n = ps * math.floor((seg.selected_index or 0) / ps) + n
      end
    end

    if not n then return 2 end   -- 其他鍵（含繼續打字）交還給後面的 processor

    local row = rows[n]
    local target = row and row.key and (env.prefix .. row.key) or nil
    context:clear()
    if row and row.run and run_pattern[row.run] then
      generic_open(run_pattern[row.run].open)     -- 直接執行（開速查表、跑更新腳本…）
    elseif target == c_input then
      -- 選到的就是「目前已經打好的這一串」——push 回去等於沒動，畫面不變會被
      -- 當成當掉。這種列沒有 run（動作寫在下面的指令分支，如 '/jt 編輯指令清單、
      -- Mac 的 '/jc 編輯自訂短語），所以直接把該分支的動作做掉。
      -- 目前 jt／jc 都不是任何代碼的字首、走不到這裡，但加了代碼就可能踩到。
      local op = string.match(c_input, "^" .. env.prefix .. "j([a-z]+)$")
      if op == "t" then
        generic_open(env.run_pattern)
      elseif op == "c" and env.textdict ~= "" then
        generic_open(env.custom_phrase)
      end
    elseif target then
      context:push_input(target)                  -- 進到該功能／子選單
    end
    return 1

-----------------------------------------------------------------------------

  --- pass not space Return KP_Enter key_num
  elseif key:repr() ~= "space" and key:repr() ~= "Return" and key:repr() ~= "KP_Enter" then
    return 2

-----------------------------------------------------------------------------

  elseif seg:has_tag("mf_translator") then  -- 開頭

    -- 指令的兩種打法：
    --   ① 命名空間形式「前綴 j 指令碼」，例如 '/jgit、'/jh。j＝join（上游沿用）。
    --      曾短暫改用 c＝command，但 '/c 已是「內碼十進制」的代碼、'/cs 是 devkit
    --      的命名風格轉換，撞碼後指令選單被靜默遮蔽 —— 已改回 j，勿再動。
    --   ② 直達形式「前綴 指令碼」，例如 '/git —— 但只有 p_run_pattern 裡標了
    --      direct = true 的條目才開放，否則 '/f、'/t 這些日期代碼會被當成開啟碼吃掉
    --      （下面找不到碼時會 context:clear()，等於把日期功能整個弄壞）。
    local op_code = #c_input == caret_pos and
      string.match(c_input, "^" .. env.prefix .. "j([a-z]+)$")

    if not op_code and #c_input == caret_pos then
      local bare = string.match(c_input, "^" .. env.prefix .. "([a-z]+)$")
      if bare and run_pattern[bare] and run_pattern[bare].direct then
        op_code = bare
      end
    end
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