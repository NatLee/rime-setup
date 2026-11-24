--- @@ convert_japan_filter
--[[
日文出羅馬字、全形羅馬字、半形片假名、全片假名、全平假名。
用 filter 方式呈現。
--]]

--[[
從 convert_kana 資料夾匯入假名相關轉換函數。
--]]
local c_k = require("convert_kana/convert_kana")
local revise_t = c_k.revise_t
local fullshape_t = c_k.fullshape_t
local halfwidth_kata_t = c_k.halfwidth_kata_t
local kata_t = c_k.kata_t
local hira_t = c_k.hira_t


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
  local check_plus = config:get_string("translator/dictionary") or ""  -- 檢查為獨立方案或掛接方案
  env.p_prefix = check_plus ~= "jpnin1.extended" and config:get_string("japan/prefix") or ""
  env.match_pattern = env.p_prefix .. "([-/a-z.,;]+)(%., ?)$"  -- "[,46]([-/a-z][-/a-z.,;]*)(%., ?)$"：會有Bug
  env.tips_jp = "《日-固列》"
  -- env.tips_jp = env.p_prefix ~= "" and "《日-固列》" or ""
  -- env.prompt_jp = "（日-固列）"
end

-- function M.fini(env)
-- end

-- local function convert_japan_filter(inp, env)
local function filter(inp, env)
-- function M.func(inp,env)
  local engine = env.engine
  local context = engine.context
  local c_input = context.input  -- 原始未轉換輸入碼
  local start = context:get_preedit().sel_start
  local _end = context:get_preedit().sel_end
  local caret_pos = context.caret_pos
  local c, s = string.match(c_input, env.match_pattern)

  if caret_pos == #c_input and c then
    local es = _end - start - 2  --減二為扣掉「.,」兩個尾綴（c不包含，故前移兩位）
    local c = string.sub(c, -es)
    -- local c = string.sub(c, start ,_end)
    local jp_p = env.tips_jp .. string.upper(c) .. s
    -- local jp_p = env.p_prefix ~= "" and "《純日語》" .. string.upper(c) .. s .. "\t" .. env.prompt_jp or string.upper(c) .. s .. "\t" .. env.prompt_jp
    local roma = Candidate("simp_jp", start, caret_pos, revise_t(c) , "〔羅馬字〕")
    local roma_f = Candidate("simp_jp", start, caret_pos, fullshape_t(c), "〔全形羅馬字〕")
    yield( change_preedit(roma, jp_p) )
    yield( change_preedit(roma_f, jp_p) )

    local hw = halfwidth_kata_t(c)
    if not string.match(hw, "%l") then
      local hwkata = Candidate("simp_jp", start, caret_pos, hw, "〔半形片假名〕")
      local kata = Candidate("simp_jp", start, caret_pos, kata_t(hw), "〔片假名〕")
      local hira = Candidate("simp_jp", start, caret_pos, hira_t(hw), "〔平假名〕")
      yield( change_preedit(hwkata, jp_p) )
      yield( change_preedit(kata, jp_p) )
      yield( change_preedit(hira, jp_p) )
    else
      local no_kana = Candidate("simp_jp", start, caret_pos, "", "〔該拼寫無假名〕")
      yield( change_preedit(no_kana, jp_p) )
    end

  else
    for cand in inp:iter() do
      yield(cand)
    end
  end

end

-- return convert_japan_filter
return { init = init, func = filter }
-- return M
----------------------------------------------------------------------------------------


--- 以下舊的寫法：分開寫法