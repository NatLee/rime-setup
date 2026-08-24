----------------------------------------------------------------------------------------
--- 農曆相關轉換（數字分支用到二進位轉換）
local lc_1 = require("lunar_calendar/lunar_calendar_1")
local Dec2bin = lc_1.Dec2bin

----------------------------------------------------------------------------------------
--- 數字字母各種格式轉寫

local f_n_s = require("f_components/f_number_style")
local formatnumberthousands = f_n_s.formatnumberthousands
local fullshape_number = f_n_s.fullshape_number
local math1_number = f_n_s.math1_number
local math2_number = f_n_s.math2_number
local circled1_number = f_n_s.circled1_number
local circled2_number = f_n_s.circled2_number
local circled3_number = f_n_s.circled3_number
local circled4_number = f_n_s.circled4_number
local circled5_number = f_n_s.circled5_number
local purech_number = f_n_s.purech_number
local purebigch_number = f_n_s.purebigch_number
local military_number = f_n_s.military_number
local little1_number = f_n_s.little1_number
local little2_number = f_n_s.little2_number
local braille_c_number = f_n_s.braille_c_number
local braille_u_number = f_n_s.braille_u_number
local keycap_number = f_n_s.keycap_number

local f_c_n = require("f_components/f_chinese_number")
local read_number = f_c_n.read_number
local read_number_bank = f_c_n.read_number_bank
local confs = f_c_n.confs

----------------------------------------------------------------------------------------
--- 計算機

local simple_calculator = require("f_components/f_simple_calculator")

----------------------------------------------------------------------------------------
--- 數字與計算機分支（原 translate() 內容純搬移）

local function calc(input, seg, env, ctx)
  local yield_c = ctx.yield_c
    --- 補以下開頭括號缺漏（另改成如同啟始符）
    local paren_left_q = string.match(input, env.prefix .. "[q(][q(]?$")
    if paren_left_q then
      local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "  ~ [-.0-9]+[ + - * / ^ ( ) ]...〔數字和計算機〕")
      cand2.preedit = input .. "\t【數字和計算機】▶"
      yield(cand2)
      -- yield_c( "", "  ~ [-.0-9]+〔數字〕")
      -- yield_c( "", "  ~ [-.0-9]+[ + - * / ^ ( ) ]...〔計算機〕")
      -- yield_c( "(", "〔括號〕")
      return true
    end

    --- 補以下開頭負號缺漏
    local neg_nf = string.match(input, env.prefix .. "[q(]?[q(]?[-r]$")
    if neg_nf then
      yield_c( "-", "〔一般負號〕")
      yield_c( "−", "〔數學負號〕")
      yield_c( "－", "〔全形負號〕")
      yield_c( "⁻", "〔上標負號〕")
      yield_c( "₋", "〔下標負號〕")
      yield_c( "負", "〔中文負號〕")
      yield_c( "槓", "〔軍中負號〕")
      yield_c( "−⃝", "〔帶圈負號〕")  -- ㊀ -⃝ −︎⃝ ⊝ ⊖
      yield_c( "⛔︎", "〔反白帶圈負號〕")
      yield_c( "負⃝", "〔帶圈中文負號〕")  -- 負︎⃝
      yield_c( "⛔", "〔鍵帽負號〕")  -- ➖ -⃣ −⃣
      yield_c( "➖", "〔加粗的減號〕")
      yield_c( "⠤", "〔點字(computer/unified)〕")
      return true
    end

    --- 補以下開頭小數點缺漏
    local dot = string.match(input, env.prefix .. "[q(]?[q(]?%.$")
    if dot then
      yield_c( ".", "〔一般小數點〕")
      yield_c( "．", "〔全形點〕")
      yield_c( "⋅", "〔上標小數點〕")
      yield_c( "點", "〔中文小數點〕")
      -- yield_c( "點", "〔軍中小數點〕")
      yield_c( "⠨", "〔點字(computer)〕")
      yield_c( "⠲", "〔點字(unified)〕")
      return true
    end

    --- 補以下開頭負號+小數點缺漏
    local neg_nf_dot = string.match(input, env.prefix .. "[q(]?[q(]?[-r]%.$")
    if neg_nf_dot then
      yield_c( "-0.", "〔一般數字〕")
      yield_c( ",", "〔千分位〕")
      yield_c( "-0.000000E+00", "〔科學計數〕")
      yield_c( "-0.000000e+00", "〔科學計數〕")
      yield_c( "−𝟎.", "〔數學粗體數字〕")
      yield_c( "−𝟘.", "〔數學空心數字〕")
      yield_c( "－０.", "〔全形數字〕")
      yield_c( "⁻⁰⋅", "〔上標數字〕")
      yield_c( "₋₀.", "〔下標數字〕")
      yield_c( "負〇點", "〔小寫中文數字〕")
      yield_c( "負零點", "〔大寫中文數字〕")
      yield_c( "負點", "〔純中文數字〕")
      yield_c( "槓點", "〔軍中數字〕")
      yield_c( "⠤⠨", "〔點字(computer)〕")
      yield_c( "⠤⠲", "〔點字(unified)〕")
      return true
    end

    -- local numberout = string.match(input, env.prefix .. "/?(%d+)$")
    local neg_n, dot0 ,numberout, dot1, afterdot = string.match(input, env.prefix .. "([q(]?[q(]?[-r]?)(%.?)(%d+)(%.?)(%d*)$")
    if (tonumber(numberout)~=nil) then
      local neg_n = string.gsub(neg_n, "r", "-")  --配合計算機算符
      local neg_n = string.gsub(neg_n, "[q(]", "")  --配合計算機算符

      if dot0~="" and dot1~="" then
        yield_c( "" , "〔不能兩個小數點〕")  --字符過濾可能會過濾掉""整個選項。
        return true
      elseif (dot0~="") then
        afterdot = numberout
        dot1 = dot0
        numberout = "0"
      end

      local neg_n_m = string.gsub(neg_n, "-", "−")
      local neg_n_f = string.gsub(neg_n, "-", "－")
      local neg_n_h = string.gsub(neg_n, "-", "⁻")
      local neg_n_l = string.gsub(neg_n, "-", "₋")
      local neg_n_c = string.gsub(neg_n, "-", "負")
      local neg_n_s = string.gsub(neg_n, "-", "槓")
      local neg_n_q = string.gsub(neg_n, "-", "−⃝")  -- ㊀ -⃝ −︎⃝ ⊝ ⊖
      local neg_n_a = string.gsub(neg_n, "-", "⛔︎")
      local neg_n_z = string.gsub(neg_n, "-", "負⃝")  -- 負︎⃝
      local neg_n_k = string.gsub(neg_n, "-", "⛔")  -- ➖ -⃣ −⃣
      local neg_n_b = string.gsub(neg_n, "-", "⠤")

    -- if numberout~=nil and tonumber(nn)~=nil then
      -- local nn = string.sub(numberout, 1)
      --[[ 用 yield 產生一個候選項
      候選項的構造函數是 Candidate，它有五個參數：
      - type: 字符串，表示候選項的類型（可隨意取）
      - start: 候選項對應的輸入串的起始位置
      - _end:  候選項對應的輸入串的結束位置
      - text:  候選項的文本
      - comment: 候選項的注釋
      --]]
      yield_c( neg_n .. numberout .. dot1 .. afterdot , "〔一般數字〕")

      -- if string.len(numberout) < 4 or neg_n~="" then
      if string.len(numberout) < 4 then
        yield_c( "," , "〔千分位〕")
      else
        -- local k = string.sub(numberout, 1, -1) -- 取參數
        local result = formatnumberthousands(numberout) --- 調用算法
        yield_c( neg_n .. result .. dot1 .. afterdot , "〔千分位〕")
      end

      yield_c( string.format("%E", neg_n .. numberout .. dot1 .. afterdot ), "〔科學計數〕")
      yield_c( string.format("%e", neg_n .. numberout .. dot1 .. afterdot ), "〔科學計數〕")
      -- if neg_n == "" then
      --   yield_c( math1_number(numberout) .. dot1 .. math1_number(afterdot), "〔數學粗體數字〕")
      --   yield_c( math2_number(numberout) .. dot1 .. math2_number(afterdot), "〔數學空心數字〕")
      -- elseif neg_n ~="" then
      --   yield_c( neg_n .. " " .. math1_number(numberout) .. dot1 .. math1_number(afterdot), "〔數學粗體數字〕")
      --   yield_c( neg_n .. " " .. math2_number(numberout) .. dot1 .. math2_number(afterdot), "〔數學空心數字〕")
      -- end
      yield_c( neg_n_m .. math1_number(numberout) .. dot1 .. math1_number(afterdot), "〔數學粗體數字〕")
      yield_c( neg_n_m .. math2_number(numberout) .. dot1 .. math2_number(afterdot), "〔數學空心數字〕")
      yield_c( neg_n_f .. fullshape_number(numberout) .. dot1 .. fullshape_number(afterdot), "〔全形數字〕")
      yield_c( neg_n_h .. little1_number(numberout..dot1..afterdot), "〔上標數字〕")
      yield_c( neg_n_l .. little2_number(numberout..dot1..afterdot), "〔下標數字〕")
      --- 超過「1000垓」則不顯示中文數字
      if (string.len(numberout) < 25) then
        yield_c( neg_n_c .. read_number(confs[1], numberout) .. purech_number(dot1..afterdot), confs[1].comment)
        yield_c( neg_n_c .. read_number_bank(confs[2], numberout) .. purebigch_number(dot1..afterdot), confs[2].comment)
      else
        yield_c( "〇" , "（超過 1000垓/24位 計算限制）" .. confs[1].comment)
        yield_c( "零" , "（超過 1000垓/24位 計算限制）" .. confs[2].comment)
      end

      if (dot1=="") then

        -- --- 超過「1000垓」則不顯示中文數字
        -- if (string.len(numberout) < 25) then
        --   -- for _, conf in ipairs(confs) do
        --   --   local r = read_number(conf, nn)
        --   --   yield_c( r, conf.comment)
        --   -- end
        --   yield_c( neg_n_c .. read_number(confs[1], nn), confs[1].comment)
        --   yield_c( neg_n_c .. read_number_bank(confs[2], nn), confs[2].comment)
        -- -- else
        -- --   yield_c( "超過位數", confs[1].comment)
        -- --   yield_c( "超過位數", confs[2].comment)
        -- end

        if (string.len(numberout) < 2) then
          yield_c( "元整", "〔純中文數字〕")
        else
          yield_c( neg_n_c .. purech_number(numberout), "〔純中文數字〕")
        end

        yield_c( neg_n_s .. military_number(numberout), "〔軍中數字〕")

        yield_c( neg_n_q .. circled1_number(numberout), "〔帶圈數字〕")
        yield_c( neg_n_q .. circled2_number(numberout), "〔帶圈無襯線數字〕")
        yield_c( neg_n_a .. circled3_number(numberout), "〔反白帶圈數字〕")
        yield_c( neg_n_a .. circled4_number(numberout), "〔反白帶圈無襯線數字〕")
        yield_c( neg_n_z .. circled5_number(numberout), "〔帶圈中文數字〕")

        yield_c( neg_n_k .. keycap_number(numberout), "〔鍵帽數字〕")
        yield_c( neg_n_b .. braille_c_number(numberout), "〔點字(computer)〕")
        -- yield_c( neg_n_b .. "⠼" .. braille_c_number(numberout), "〔點字(一般)〕")
        yield_c( neg_n_b .. "⠼" .. braille_u_number(numberout), "〔點字(unified)〕")

        if (neg_n=="") then
          if tonumber(numberout)==1 or tonumber(numberout)==0 then
            yield_c( string.sub(numberout, -1), "〔二進位〕")
          --- 浮點精度關係，二進制轉換運算中：
          --- math.floor 極限是小數點後15位(小於16位，1.9999999999999999)
          --- math.fmod 極限是小數點後13位(小於14位，1.99999999999999，14位開頭為偶數時除2是正確的，奇數則不正確)
          elseif (string.len(numberout) < 14) then
          --- （以下還是有錯誤！）等於大於9999999999999999（16位-1），lua中幾個轉換函數都會出錯，運算會不正確
          -- elseif (tonumber(numberout) < 9999999999999999) then
          -- elseif (string.len(numberout) < 16) then
            yield_c( Dec2bin(numberout), "〔二進位〕")
          else
            yield_c( "bin", "（超過 14位 會有誤）〔二進位〕")
            -- yield_c( "%b", "（數值超過 14位 可能會不正確）〔二進位〕")
            -- yield_c( "", "（數值超過 16位-1 會不正確）〔二進位〕")
          end

          --- 整數庫限制：最大的64位元整數超過64位等同十進制2^63，超過則報錯，極限2^63-1，超過設定不顯示
          if (tonumber(numberout) < 9223372036854775808) then
          -- if (string.len(numberout) < 19) then
            yield_c( string.format("%X",numberout), "〔十六進位〕")
            yield_c( string.format("%x",numberout), "〔十六進位〕")
            yield_c( string.format("%o",numberout), "〔八進位〕")
          else
            yield_c( "Hex", "（超過 2⁶³-1 報錯）〔十六進位〕")
            yield_c( "hex", "（超過 2⁶³-1 報錯）〔十六進位〕")
            yield_c( "oct", "（超過 2⁶³-1 報錯）〔八進位〕")
          end
        end

      elseif (dot0~="") then
        yield_c( neg_n_c .. purech_number(dot1..afterdot), "〔純中文數字〕")
        yield_c( neg_n_s .. military_number(dot1..afterdot), "〔軍中數字〕")
        yield_c( neg_n_b .. braille_c_number(dot1..afterdot), "〔點字(computer)〕")
        -- yield_c( neg_n_b .. "⠼" .. braille_c_number(dot1..afterdot), "〔點字(一般)〕")
        yield_c( neg_n_b .. "⠼" .. braille_u_number(dot1..afterdot), "〔點字(unified)〕")
        return true
      elseif dot0=="" and dot1~="" then
        if (string.len(numberout) < 2) then
          yield_c( "元整", "〔純中文數字〕")
        else
          yield_c( neg_n_c .. purech_number(numberout..dot1..afterdot), "〔純中文數字〕")
        end
        yield_c( neg_n_s .. military_number(numberout..dot1..afterdot), "〔軍中數字〕")
        yield_c( neg_n_b .. braille_c_number(numberout..dot1..afterdot), "〔點字(computer)〕")
        -- yield_c( neg_n_b .. "⠼" .. braille_c_number(numberout..dot1..afterdot), "〔點字(一般)〕")
        yield_c( neg_n_b .. "⠼" .. braille_u_number(numberout..dot1..afterdot), "〔點字(unified)〕")
        return true
      end

      return true
    end


    --- 計算機
    local c_input = string.match(input, env.prefix .. "([q(]?[q(]?[-r]?[%d.]+[-+*/^asrvxqw()][-+*/^asrvxqw().%d]*)$")
    if c_input then
      local c_input = string.gsub(c_input, "a", "+")
      local c_input = string.gsub(c_input, "s", "^")
      local c_input = string.gsub(c_input, "r", "-")
      local c_input = string.gsub(c_input, "v", "/")
      local c_input = string.gsub(c_input, "x", "*")
      local c_input = string.gsub(c_input, "q", "(")
      local c_input = string.gsub(c_input, "w", ")")
      local input_exp = string.gsub(c_input, "^0+(%d)", "%1")
      local input_exp = string.gsub(input_exp, "([-+*/^()])0+(%d)", "%1%2")
      --會出 Bug -- local input_exp = string.gsub(input_exp, "(%d*%.%d*0)$", function(n) return string.format("%g",n) end)
      --會出 Bug -- local input_exp = string.gsub(input_exp, "(%d*%.%d*0)([-+*/^()])", function(n, opr) return string.format("%g",n) .. opr end)
      local input_exp = string.gsub(input_exp, "(%d*%.%d*0)$", function(n) return string.gsub(n,"0+$", "") end)  --去除小數點後末尾0
      local input_exp = string.gsub(input_exp, "(%d*%.%d*0)([-+*/^()])", function(n, opr) return string.gsub(n,"0+$", "") .. opr end)  --去除小數點後末尾0
      local input_exp = string.gsub(input_exp, "^%.", "0.")
      local input_exp = string.gsub(input_exp, "%.$", "")  -- 修正筆誤 %.%$（原寫法找的是字面 ".$"，永不命中）
      local input_exp = string.gsub(input_exp, "%.([-+*/^()])", "%1")
      local input_exp = string.gsub(input_exp, "([-+*/^()])%.", "%10.")
      local c_preedit = string.gsub(c_input, "([-+*/^()])", " %1 ")

      local cal_r = simple_calculator(input_exp)  -- 只算一次（原本每鍵重算三次）
      local c_output = cal_r[1]
      local output_exp = cal_r[2]
      local s_output = cal_r[3]

      local cc_out = Candidate("simp_mf_cal", seg.start, seg._end, c_output, "〔結果〕")
      local cc_out_error = Candidate("simp_mf_cal", seg.start, seg._end, "", c_output.."〔結果〕")
      -- local cc_exp = Candidate("simp_mf_cal", seg.start, seg._end, input_exp .. "=" .. c_output, "〔規格化算式〕")
      local cc_exp = Candidate("simp_mf_cal", seg.start, seg._end, output_exp .. "=" .. c_output, "〔規格化算式〕")
      local cc_exp_error = Candidate("simp_mf_cal", seg.start, seg._end, output_exp .. "=" .. s_output, "〔 Waring 規格化算式〕")
      local cc_out_shadow = Candidate("simp_mf_cal", seg.start, seg._end, s_output, "〔 Waring 結果〕")
      local cc_statement = Candidate("simp_mf_cal", seg.start, seg._end, "", "※  會有浮點數誤差和錯誤；括號限兩層三堆；14位數限制")
      cc_out.preedit = env.prefix .. " " .. c_preedit .. " \t【計算機】"
      cc_out_error.preedit = env.prefix .. " " .. c_preedit .. " \t【計算機】"
      cc_exp.preedit = env.prefix .. " " .. c_preedit .. " \t【計算機】"
      cc_exp_error.preedit = env.prefix .. " " .. c_preedit .. " \t【計算機】"
      cc_out_shadow.preedit = env.prefix .. " " .. c_preedit .. " \t【計算機】"
      cc_statement.preedit = env.prefix .. " " .. c_preedit .. " \t【計算機】"
      if (c_output:sub(1,1)=="E" or c_output:sub(1,1)=="W") then
        yield(cc_out_error)
        yield(cc_out_shadow)
        yield(cc_exp_error)
      else
        yield(cc_out)
        -- if s_output~="" then
        --   yield(cc_out_shadow)
        -- end
        yield(cc_exp)
      end
      -- if s_output~="" then
      --   yield(cc_out_shadow)
      -- end
      yield(cc_statement)
      -- yield_c( "", "※  會有浮點數誤差和錯誤；括號限兩層；14位數限制")
      return true
    end


    -- -- 測試空白不上屏在 translator 中直接處理！
    -- -- local engine = env.engine
    -- -- local context = engine.context
    -- -- local kkk = string.match(o_input, env.prefix .. "")
    -- -- local engine = env.engine
    -- -- local context = engine.context
    -- -- local o_input = context.input
    -- local kkk = string.match(input, "( )$")
    -- -- local page_size = engine.schema.page_size
    -- if (kkk~=nil) then --and context:is_composing()
    --   -- local s_orig = context:get_commit_text()
    --   -- local o_input = context.input
    --   -- engine:commit_text(s_orig .. "a")
    --   -- context:clear()
    --   -- yield_c( "nnnnnm", "〔千分位數字〕")
    --   return 1 -- kAccepted
    -- end
  return false
end

return { calc = calc }
