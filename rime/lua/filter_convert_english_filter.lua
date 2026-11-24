--- @@ convert_english_filter
--[[
easy 英文尾綴「;」或「;;」生成全大寫或首字母大寫。
--]]

--[[
從 f_components 資料夾匯入假名相關轉換函數。
--]]
local f_e_s = require("f_components/f_english_style")
local english_s = f_e_s.english_s
local english_u1 = f_e_s.english_u1
local english_s2u = f_e_s.english_s2u


--- 以下新的寫法：合併寫法
----------------------------------------------------------------------------------------
local change_preedit = require("filter_cand/change_preedit")
----------------------------------------------------------------------------------------
-- local M={}
local function init(env)
-- function M.init(env)
  local engine = env.engine
  local schema = engine.schema
  local config = schema.config
  -- namespace = "p_convert_english_filter"
  -- env.check_plus = config:get_string(namespace .. "/tags") or ""

  -- local check_plus = config:get_string("translator/dictionary") or ""  -- 檢查為獨立方案或掛接方案
  -- if check_plus ~= "easy_en_lower" then
  --   local p_prefix = config:get_string("easy_en/prefix") or ""
  --   env.match_pattern = p_prefix .. "([-/a-z.,']+)([;/']*)( ?)$"  -- "[.3]([-/a-z.,']+)([;/']*)( ?)$"
  --   env.tips_en = "《Easy》"
  --   -- env.enable_tips = true -- 可以用 option  做 tips 開關
  -- else
  --   env.match_pattern = "^([-/a-z.,']+)([;/']*)( ?)$"  -- "^([-/a-z.,']+)([;/']*)$"
  --   env.tips_en = ""
  --   -- env.enable_tips = false
  -- end

  local check_schema_id = config:get_string("schema/schema_id") or ""
  -- local check_mount = config:get_string("translator/dictionary") or ""  -- 檢查為獨立方案或掛接方案
  env.p_prefix = check_schema_id ~= "easy_en_lower" and config:get_string("easy_en/prefix") or ""
  -- env.p_prefix = check_mount ~= "easy_en_lower" and config:get_string("easy_en/prefix") or ""
  -- env.enable_tips = check_mount ~= "easy_en_lower" and true or false
  env.match_pattern = check_schema_id ~= "bopomo_onionplus_space" and env.p_prefix .. "([-/a-z.,']+)([;/']*)( ?)$" or env.p_prefix .. "([- /a-z.,']+)([;/']*)( ?)$"  -- "[.3]?([-/a-z.,']+)([;/']*)( ?)$"：會有Bug
  env.tips_en = "《Easy》"

  env.english_pattern = {
    [";;"] = {comment = "〔全大寫〕", func = string.upper},
    [";/"] = {comment = "〔全小寫〕", func = english_s},
    [";'"] = {comment = "〔間隔後大寫〕", func = english_s2u},
    [";"] = {comment = "〔開頭大寫〕", func = english_u1},
    [""] = {comment = "〔補空〕", func = english_s},
   }
end

-- function M.fini(env)
-- end

-- local function convert_english_filter(inp, env)
local function filter(inp, env)
-- function M.func(inp,env)
  local engine = env.engine
  local context = engine.context
  local c_input = context.input  -- 原始未轉換輸入碼
  local start = context:get_preedit().sel_start
  -- local _end = context:get_preedit().sel_end + 1  --一般末尾「;」會多一。
  local caret_pos = context.caret_pos

  for cand in inp:iter() do
    yield(cand)
  end
  
  if (caret_pos == #c_input) then
    local mstr, cp, sp = string.match(c_input, env.match_pattern)  -- 取代 s1~ s5
    local cp_tab = env.english_pattern[cp]
    if cp_tab then
      local e_cand = Candidate("simp_en", start, caret_pos, cp_tab.func(mstr), cp_tab.comment)
      -- yield( change_preedit(e_cand, env.tips_en .. mstr .. cp .. sp) )
      -- yield( env.enable_tips and change_preedit(e_cand, env.tips_en .. mstr .. cp .. sp) or e_cand )
      yield( env.p_prefix ~= "" and change_preedit(e_cand, env.tips_en .. mstr .. cp .. sp) or e_cand )

      -- local kkk=env.engine.schema.config:get_list("easy_en/extra_tags")  -- 以下測試用
      -- log.info(kkk.type)
      -- log.info('測試測試測試')

    end
  end
end

-- return convert_english_filter
return { init = init, func = filter }
-- return M
----------------------------------------------------------------------------------------


--- 以下新的寫法：分開寫法


--- 以下舊的寫法：分開寫法