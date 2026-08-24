----------------------------------------------------------------------------------------
--- 日期時間各種格式轉寫

local f_d_s = require("f_components/f_date_style")
local ch_h_date = f_d_s.ch_h_date
local ch_minsec_date = f_d_s.ch_minsec_date
local chb_h_date = f_d_s.chb_h_date
local chb_minsec_date = f_d_s.chb_minsec_date

local f_t_s = require("f_components/f_time_style")
local time_out1 = f_t_s.time_out1
local time_out2 = f_t_s.time_out2
----------------------------------------------------------------------------------------
--- 農曆相關轉換
local lc_1 = require("lunar_calendar/lunar_calendar_1")
local lunarJzl = lc_1.lunarJzl

local lc_2 = require("lunar_calendar/lunar_calendar_2")
local time_description_chinese = lc_2.time_description_chinese

local GetLunarSichen = require("lunar_calendar/lunar_time")

----------------------------------------------------------------------------------------
--- 數字字母各種格式轉寫

local f_n_s = require("f_components/f_number_style")
local fullshape_number = f_n_s.fullshape_number

----------------------------------------------------------------------------------------
--- 即時時間 t*（時:分:秒）與 n*（時:分）各分支（原 mf_datetime.lua now() 內容純搬移）

local function now(input, seg, env, ctx)
  local yield_c = ctx.yield_c
    -- Candidate(type, start, end, text, comment)
    if (input == env.prefix .. "t") then
      -- yield_c( os.date("%H:%M"), "〔時:分〕 ~m")
      -- yield_c( os.date("%H:%M:%S"), "〔時:分:秒〕 ~d")
      yield_c( string.gsub(os.date("%H:%M:%S"), "^0", ""), "〔時:分:秒〕 ~d")
      -- local a, b, c, d, aptime5, aptime6, aptime7, aptime8 = time_out1()
      yield_c( time_out1()[6] , "〔時:分:秒〕 ~m")
      yield_c( string.gsub(os.date("%H時%M分%S秒"), "0([%d])", "%1"), "〔時:分:秒〕 ~c")
      -- local a, b, aptime_c3, aptime_c4, ap_5 = time_out2()
      yield_c( string.gsub(time_out2()[7], " 0([%d])", " %1"), "〔時:分:秒〕 ~s")
      yield_c( string.gsub(time_out2()[3], "0([%d])", "%1"), "〔時:分:秒〕 ~w")
      yield_c( ch_h_date(os.date("%H")).."時"..ch_minsec_date(os.date("%M")).."分"..ch_minsec_date(os.date("%S")).."秒", "〔時:分:秒〕 ~z")
      yield_c( time_out2()[5].." "..ch_h_date(os.date("%I")).."時"..ch_minsec_date(os.date("%M")).."分"..ch_minsec_date(os.date("%S")).."秒", "〔時:分:秒〕 ~u")
      return true
    end

    if (input == env.prefix .. "ts") then
      -- local a, b, aptime_c3, aptime_c4 = time_out2()
      yield_c( string.gsub(time_out2()[7], " 0([%d])", " %1"), "〔時:分:秒〕")
      yield_c( time_out2()[5].." "..fullshape_number(string.gsub(os.date("%I"), "^0", "")).."："..fullshape_number(os.date("%M")).."："..fullshape_number(os.date("%S")), "〔時:分:秒〕")
      yield_c( time_out2()[7], "〔時:分:秒〕")
      yield_c( time_out2()[5].." "..fullshape_number(os.date("%I")).."："..fullshape_number(os.date("%M")).."："..fullshape_number(os.date("%S")), "〔時:分:秒〕")
      return true
    end

    if (input == env.prefix .. "tw") then
      -- local a, b, aptime_c3, aptime_c4 = time_out2()
      yield_c( string.gsub(time_out2()[3], "0([%d])", "%1"), "〔時:分:秒〕")
      yield_c( string.gsub(time_out2()[4], "0([%d])", "%1"), "〔時:分:秒〕")
      yield_c( fullshape_number(string.gsub(time_out2()[3], "0([%d])", "%1")), "〔時:分:秒〕")
      yield_c( fullshape_number(string.gsub(time_out2()[4], "0([%d])", "%1")), "〔時:分:秒〕")
      yield_c( time_out2()[3], "〔時:分:秒〕")
      yield_c( time_out2()[4], "〔時:分:秒〕")
      yield_c( fullshape_number(time_out2()[3]), "〔時:分:秒〕")
      yield_c( fullshape_number(time_out2()[4]), "〔時:分:秒〕")
      return true
    end

    if (input == env.prefix .. "tu") then
      -- local a, b, aptime_c3, aptime_c4, ap_5 = time_out2()
      yield_c( time_out2()[5].." "..ch_h_date(os.date("%I")).."時"..ch_minsec_date(os.date("%M")).."分"..ch_minsec_date(os.date("%S")).."秒", "〔時:分:秒〕")
      yield_c( time_out2()[5].." "..ch_h_date(os.date("%I")).."點"..ch_minsec_date(os.date("%M")).."分"..ch_minsec_date(os.date("%S")).."秒", "〔時:分:秒〕")
      yield_c( time_out2()[5].." "..chb_h_date(os.date("%I")).."時"..chb_minsec_date(os.date("%M")).."分"..chb_minsec_date(os.date("%S")).."秒", "〔時:分:秒〕")
      yield_c( time_out2()[5].." "..chb_h_date(os.date("%I")).."點"..chb_minsec_date(os.date("%M")).."分"..chb_minsec_date(os.date("%S")).."秒", "〔時:分:秒〕")
      return true
    end

    if (input == env.prefix .. "td") then
      yield_c( string.gsub(os.date("%H:%M:%S"), "^0", ""), "〔時:分:秒〕")
      yield_c( fullshape_number(string.gsub(os.date("%H"), "^0", "")).."："..fullshape_number(os.date("%M")).."："..fullshape_number(os.date("%S")), "〔時:分:秒〕")
      yield_c( os.date("%H:%M:%S"), "〔時:分:秒〕")
      yield_c( fullshape_number(os.date("%H")).."："..fullshape_number(os.date("%M")).."："..fullshape_number(os.date("%S")), "〔時:分:秒〕")
      return true
    end

    if (input == env.prefix .. "tm") then
      -- local a, b, c, d, aptime5, aptime6, aptime7, aptime8, e, f, g, h, aptime00_1, aptime00_2,  aptime00_3, aptime00_4 = time_out1()
      yield_c( time_out1()[6], "〔時:分:秒〕")
      yield_c( time_out1()[8], "〔時:分:秒〕")
      yield_c( time_out1()[7], "〔時:分:秒〕")
      yield_c( time_out1()[5], "〔時:分:秒〕")
      yield_c( time_out1()[14], "〔時:分:秒〕")
      yield_c( time_out1()[16], "〔時:分:秒〕")
      yield_c( time_out1()[15], "〔時:分:秒〕")
      yield_c( time_out1()[13], "〔時:分:秒〕")
      return true
    end

    if (input == env.prefix .. "tc") then
      yield_c( string.gsub(os.date("%H時%M分%S秒"), "0([%d])", "%1"), "〔時:分:秒〕")
      yield_c( string.gsub(os.date("%H點%M分%S秒"), "0([%d])", "%1"), "〔時:分:秒〕")
      yield_c( fullshape_number(string.gsub(os.date("%H時%M分%S秒"), "0([%d])", "%1")), "〔時:分:秒〕")
      yield_c( fullshape_number(string.gsub(os.date("%H點%M分%S秒"), "0([%d])", "%1")), "〔時:分:秒〕")
      yield_c( os.date("%H時%M分%S秒"), "〔時:分:秒〕")
      yield_c( os.date("%H點%M分%S秒"), "〔時:分:秒〕")
      yield_c( fullshape_number(os.date("%H時%M分%S秒")), "〔時:分:秒〕")
      yield_c( fullshape_number(os.date("%H點%M分%S秒")), "〔時:分:秒〕")
      return true
    end

    if (input == env.prefix .. "tz") then
      yield_c( ch_h_date(os.date("%H")).."時"..ch_minsec_date(os.date("%M")).."分"..ch_minsec_date(os.date("%S")).."秒", "〔時:分:秒〕")
      yield_c( ch_h_date(os.date("%H")).."點"..ch_minsec_date(os.date("%M")).."分"..ch_minsec_date(os.date("%S")).."秒", "〔時:分:秒〕")
      yield_c( chb_h_date(os.date("%H")).."時"..chb_minsec_date(os.date("%M")).."分"..chb_minsec_date(os.date("%S")).."秒", "〔時:分:秒〕")
      yield_c( chb_h_date(os.date("%H")).."點"..chb_minsec_date(os.date("%M")).."分"..chb_minsec_date(os.date("%S")).."秒", "〔時:分:秒〕")
      return true
    end

    -- if (input == env.prefix .. "tm") then
    --   yield_c( os.date("%H:%M"), "〔時:分〕")
    --   return
    -- end

    if (input == env.prefix .. "n") then
      -- yield_c( os.date("%H:%M:%S"), "〔時:分:秒〕 ~s")
      -- yield_c( os.date("%H:%M"), "〔時:分〕 ~d")
      yield_c( string.gsub(os.date("%H:%M"), "^0", ""), "〔時:分〕 ~d")
      -- local aptime1, aptime2, aptime3, aptime4 = time_out1()
      yield_c( time_out1()[2], "〔時:分〕 ~m")
      yield_c( string.gsub(os.date("%H時%M分"), "0([%d])", "%1"), "〔時:分〕 ~c")
      -- local aptime_c1, aptime_c2, a, b, ap_5 = time_out2()
      yield_c( string.gsub(time_out2()[6], " 0([%d])", " %1"), "〔時:分〕 ~s")
      yield_c( string.gsub(time_out2()[1], "0([%d])", "%1"), "〔時:分〕 ~w")
      yield_c( ch_h_date(os.date("%H")).."時"..ch_minsec_date(os.date("%M")).."分", "〔時:分〕 ~z")
      yield_c( time_out2()[5].." "..ch_h_date(os.date("%I")).."時"..ch_minsec_date(os.date("%M")).."分", "〔時:分〕 ~u")
      -- local chinese_time = time_description_chinese(os.time())
      yield_c( time_description_chinese(os.time()), "〔農曆〕 ~l")
      return true
    end

    if (input == env.prefix .. "ns") then
      -- local aptime_c1, aptime_c2 = time_out2()
      yield_c( string.gsub(time_out2()[6], " 0([%d])", " %1"), "〔時:分〕")
      yield_c( time_out2()[5].." "..fullshape_number(string.gsub(os.date("%I"), "^0", "")).."："..fullshape_number(os.date("%M")), "〔時:分〕")
      yield_c( time_out2()[6], "〔時:分〕")
      yield_c( time_out2()[5].." "..fullshape_number(os.date("%I")).."："..fullshape_number(os.date("%M")), "〔時:分〕")
      return true
    end

    if (input == env.prefix .. "nw") then
      -- local aptime_c1, aptime_c2 = time_out2()
      yield_c( string.gsub(time_out2()[1], "0([%d])", "%1"), "〔時:分〕")
      yield_c( string.gsub(time_out2()[2], "0([%d])", "%1"), "〔時:分〕")
      yield_c( fullshape_number(string.gsub(time_out2()[1], "0([%d])", "%1")), "〔時:分〕")
      yield_c( fullshape_number(string.gsub(time_out2()[2], "0([%d])", "%1")), "〔時:分〕")
      yield_c( time_out2()[1], "〔時:分〕")
      yield_c( time_out2()[2], "〔時:分〕")
      yield_c( fullshape_number(time_out2()[1]), "〔時:分〕")
      yield_c( fullshape_number(time_out2()[2]), "〔時:分〕")
      return true
    end

    if (input == env.prefix .. "nu") then
      -- local a, b, c, d, ap_5 = time_out2()
      yield_c( time_out2()[5].." "..ch_h_date(os.date("%I")).."時"..ch_minsec_date(os.date("%M")).."分", "〔時:分〕")
      yield_c( time_out2()[5].." "..ch_h_date(os.date("%I")).."點"..ch_minsec_date(os.date("%M")).."分", "〔時:分〕")
      yield_c( time_out2()[5].." "..chb_h_date(os.date("%I")).."時"..chb_minsec_date(os.date("%M")).."分", "〔時:分〕")
      yield_c( time_out2()[5].." "..chb_h_date(os.date("%I")).."點"..chb_minsec_date(os.date("%M")).."分", "〔時:分〕")
      return true
    end

    if (input == env.prefix .. "nd") then
      yield_c( string.gsub(os.date("%H:%M"), "^0", ""), "〔時:分〕")
      yield_c( fullshape_number(string.gsub(os.date("%H"), "^0", "")).."："..fullshape_number(os.date("%M")), "〔時:分〕")
      yield_c( os.date("%H:%M"), "〔時:分〕")
      yield_c( fullshape_number(os.date("%H")).."："..fullshape_number(os.date("%M")), "〔時:分〕")
      return true
    end

    if (input == env.prefix .. "nm") then
      -- local aptime1, aptime2, aptime3, aptime4 , a, b, c, d, aptime0_1, aptime0_2,  aptime0_3, aptime0_4 = time_out1()
      yield_c( time_out1()[2], "〔時:分〕")
      yield_c( time_out1()[4], "〔時:分〕")
      yield_c( time_out1()[3], "〔時:分〕")
      yield_c( time_out1()[1], "〔時:分〕")
      yield_c( time_out1()[10], "〔時:分〕")
      yield_c( time_out1()[12], "〔時:分〕")
      yield_c( time_out1()[11], "〔時:分〕")
      yield_c( time_out1()[9], "〔時:分〕")
      return true
    end

    if (input == env.prefix .. "nc") then
      yield_c( string.gsub(os.date("%H時%M分"), "0([%d])", "%1"), "〔時:分〕")
      yield_c( string.gsub(os.date("%H點%M分"), "0([%d])", "%1"), "〔時:分〕")
      yield_c( fullshape_number(string.gsub(os.date("%H時%M分"), "0([%d])", "%1")), "〔時:分〕")
      yield_c( fullshape_number(string.gsub(os.date("%H點%M分"), "0([%d])", "%1")), "〔時:分〕")
      yield_c( os.date("%H時%M分"), "〔時:分〕")
      yield_c( os.date("%H點%M分"), "〔時:分〕")
      yield_c( fullshape_number(os.date("%H時%M分")), "〔時:分〕")
      yield_c( fullshape_number(os.date("%H點%M分")), "〔時:分〕")
      return true
    end

    if (input == env.prefix .. "nz") then
      yield_c( ch_h_date(os.date("%H")).."時"..ch_minsec_date(os.date("%M")).."分", "〔時:分〕")
      yield_c( ch_h_date(os.date("%H")).."點"..ch_minsec_date(os.date("%M")).."分", "〔時:分〕")
      yield_c( chb_h_date(os.date("%H")).."時"..chb_minsec_date(os.date("%M")).."分", "〔時:分〕")
      yield_c( chb_h_date(os.date("%H")).."點"..chb_minsec_date(os.date("%M")).."分", "〔時:分〕")
      return true
    end

    if (input == env.prefix .. "nl") then
      -- local chinese_time = time_description_chinese(os.time())
      yield_c( time_description_chinese(os.time()), "〔農曆〕")
      local All_g, Y_g, M_g, D_g, H_g = lunarJzl(os.date("%Y%m%d%H"))
      yield_c( H_g.."時", "〔農曆干支〕")
      yield_c( GetLunarSichen(os.date("%H")), "〔農曆時辰〕")
      return true
    end

    -- if (input == env.prefix .. "ns") then
    --   yield_c( os.date("%H:%M:%S"), "〔時:分:秒〕")
    --   return
    -- end

  return false
end

return { now = now }
