
local f_e_s = require("f_components/f_english_style")
local english_1 = f_e_s.english_1
local english_2 = f_e_s.english_2
local english_3 = f_e_s.english_3
local english_4 = f_e_s.english_4
local english_5 = f_e_s.english_5
local english_6 = f_e_s.english_6
local english_7 = f_e_s.english_7
local english_8 = f_e_s.english_8
local english_9 = f_e_s.english_9
local english_f_u = f_e_s.english_f_u
local english_f_l = f_e_s.english_f_l
local english_s_u = f_e_s.english_s_u
local english_1_2 = f_e_s.english_1_2
local english_3_4 = f_e_s.english_3_4
local english_5_6 = f_e_s.english_5_6
local english_f_ul = f_e_s.english_f_ul
local english_s = f_e_s.english_s
local english_s2u = f_e_s.english_s2u
local english_braille_c_u = f_e_s.english_braille_c_u
local english_braille_c_l = f_e_s.english_braille_c_l
local english_braille_c_ul = f_e_s.english_braille_c_ul
local english_braille_u_u = f_e_s.english_braille_u_u
local english_braille_u_l = f_e_s.english_braille_u_l
local english_braille_u_ul = f_e_s.english_braille_u_ul

----------------------------------------------------------------------------------------
--- 字母轉換前導提示（原 translate() 內容純搬移）

local function tips(input, seg, env, ctx)
  local yield_c = ctx.yield_c
    if (input == env.prefix .. "/") then
      local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "  ~ [a-z]+〔小寫字母〕")
      cand2.preedit = input .. "\t【小寫字母】▶"
      yield(cand2)
      return true
    end

    if (input == env.prefix .. ";") then
      local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "  ~ [a-z]+〔大寫字母〕")
      cand2.preedit = input .. "\t【大寫字母】▶"
      yield(cand2)
      return true
    end

    if (input == env.prefix .. "\'") then
      local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "  ~ [a-z]+〔開頭大寫字母〕")
      cand2.preedit = input .. "\t【開頭大寫字母】▶"
      yield(cand2)
      return true
    end
  return false
end

-------------------------------------------------------------------------------------------------------------
--- 字母大小寫各種轉換分支（原 translate() 內容純搬移）

local function convert(input, seg, env, ctx)
  local yield_c = ctx.yield_c
    local englishout1 = string.match(input, env.prefix .. "/([%l.,/'-]+)$")
    if englishout1 then
      yield_c( english_s(englishout1), "〔一般字母小寫〕")
      yield_c( english_f_l(englishout1), "〔全形字母小寫〕")
      -- yield_c( english_1(englishout1), "〔數學字母大寫〕")
      yield_c( english_2(englishout1), "〔數學字母小寫〕")
      -- yield_c( english_3(englishout1), "〔帶圈字母大寫〕")
      yield_c( english_4(englishout1), "〔帶圈字母小寫〕")
      -- yield_c( english_5(englishout1), "〔括號字母大寫〕")
      yield_c( english_6(englishout1), "〔括號字母小寫〕")
      -- yield_c( english_7(englishout1), "〔方框字母〕")
      -- yield_c( english_8(englishout1), "〔黑圈字母〕")
      -- yield_c( english_9(englishout1), "〔黑框字母〕")
      if english_braille_c_l(englishout1) ~= english_braille_u_l(englishout1) then
        yield_c( english_braille_c_l(englishout1), "〔點字(computer)〕")
        yield_c( english_braille_u_l(englishout1), "〔點字(unified)〕")
      else
        yield_c( english_braille_c_l(englishout1), "〔點字(computer/unified)〕")
      end
      return true
    end

    local englishout2 = string.match(input, env.prefix .. "\'([%l.,/'-]+)$")
    if englishout2 then
      -- yield_c( string.upper(string.sub(englishout2,1,1)) .. string.sub(englishout2,2,-1) , "〔一般字母開頭大寫〕")
      yield_c( english_s2u(englishout2), "〔一般字母開頭大寫〕")
      yield_c( english_f_ul(englishout2), "〔全形字母開頭大寫〕")
      yield_c( english_1_2(englishout2), "〔數學字母開頭大寫〕")
      yield_c( english_3_4(englishout2), "〔帶圈字母開頭大寫〕")
      yield_c( english_5_6(englishout2), "〔括號字母開頭大寫〕")
      if english_braille_c_ul(englishout2) ~= english_braille_u_ul(englishout2) then
        yield_c( english_braille_c_ul(englishout2), "〔點字(computer)〕")
        yield_c( english_braille_u_ul(englishout2), "〔點字(unified)〕")
      else
        yield_c( english_braille_c_ul(englishout2), "〔點字(computer/unified)〕")
      end
      return true
    end

    local englishout3 = string.match(input, env.prefix .. ";([%l.,/'-]+)$")
    if englishout3 then
      local englishout3 = string.upper(englishout3)
      yield_c( english_s(englishout3), "〔一般字母大寫〕")
      yield_c( english_f_u(englishout3), "〔全形字母大寫〕")
      yield_c( english_1(englishout3), "〔數學字母大寫〕")
      yield_c( english_3(englishout3), "〔帶圈字母大寫〕")
      yield_c( english_5(englishout3), "〔括號字母大寫〕")
      yield_c( english_7(englishout3), "〔方框字母〕")
      yield_c( english_8(englishout3), "〔黑圈字母〕")
      yield_c( english_9(englishout3), "〔黑框字母〕")
      yield_c( english_s_u(englishout3), "〔小型字母大寫〕")
      if english_braille_c_u(englishout3) ~= english_braille_u_u(englishout3) then
        yield_c( english_braille_c_u(englishout3), "〔點字(computer)〕")
        yield_c( english_braille_u_u(englishout3), "〔點字(unified)〕")
      else
        yield_c( english_braille_c_u(englishout3), "〔點字(computer/unified)〕")
      end
      return true
    end
  return false
end

return { tips = tips, convert = convert }
