----------------------------------------------------------------------------------------
--- 日期時間各種格式轉寫

local timezone_out = require("f_components/f_timezone_out")

local f_y_s = require("f_components/f_year_style")
local min_guo = f_y_s.min_guo
local jp_ymd = f_y_s.jp_ymd

local f_d_s = require("f_components/f_date_style")
local ch_h_date = f_d_s.ch_h_date
local ch_minsec_date = f_d_s.ch_minsec_date
local chb_h_date = f_d_s.chb_h_date
local chb_minsec_date = f_d_s.chb_minsec_date
local jp_m_date = f_d_s.jp_m_date
local jp_d_date = f_d_s.jp_d_date
local eng1_m_date = f_d_s.eng1_m_date
local eng2_m_date = f_d_s.eng2_m_date
local eng3_m_date = f_d_s.eng3_m_date
local eng1_d_date = f_d_s.eng1_d_date
local eng2_d_date = f_d_s.eng2_d_date
local eng3_d_date = f_d_s.eng3_d_date
local eng4_d_date = f_d_s.eng4_d_date

local f_c_d_s = require("f_components/f_chinese_date_style")
local rqzdx1 = f_c_d_s.rqzdx1
local rqzdx2 = f_c_d_s.rqzdx2

local weekstyle = require("f_components/f_week_style")
----------------------------------------------------------------------------------------
--- 農曆相關轉換
local lc_1 = require("lunar_calendar/lunar_calendar_1")
local Date2LunarDate = lc_1.Date2LunarDate
local lunarJzl = lc_1.lunarJzl

local lc_2 = require("lunar_calendar/lunar_calendar_2")
local time_description_chinese = lc_2.time_description_chinese

----------------------------------------------------------------------------------------
--- 數字字母各種格式轉寫

local f_n_s = require("f_components/f_number_style")
local fullshape_number = f_n_s.fullshape_number
local purech_number = f_n_s.purech_number

local f_c_n = require("f_components/f_chinese_number")
local read_number = f_c_n.read_number
local confs = f_c_n.confs

----------------------------------------------------------------------------------------
--- 即時日期 f/y/m/d/w 及其組合（年月日/星期類）各分支（原 mf_datetime.lua now() 內容純搬移）

local function now(input, seg, env, ctx)
  local yield_c = ctx.yield_c
    if (input == env.prefix .. "f") then
      yield_c( os.date("%Y%m%d"), "〔年月日〕 ~d   ~o")
      yield_c( os.date("%Y.%m.%d"), "〔年月日〕 ~p   ~q")
      yield_c( os.date("%Y/%m/%d"), "〔年月日〕 ~s   ~y")
      yield_c( os.date("%Y-%m-%d"), "〔年月日〕 ~m   ~r")
      yield_c( os.date("%Y_%m_%d"), "〔年月日〕 ~u   ~v")
      yield_c( string.gsub(os.date("%Y年%m月%d日"), "([^%d])0", "%1"), "〔年月日〕 ~c")
      yield_c( rqzdx1(), "〔中數〕 ~z")
      yield_c( string.gsub("民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月"..os.date("%d").."日", "([^%d])0", "%1"), "〔民國〕 ~h")
      yield_c( "民國"..purech_number(min_guo(os.date("%Y"))).."年"..rqzdx1(23), "〔民國中數〕 ~g")
      -- yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")), "〔年月日〕 ~j")
      local jpymd, jp_y = jp_ymd(os.date("%Y"),os.date("%m"),os.date("%d"))
      yield_c( string.gsub(jpymd, "([^%d])0", "%1"), "〔日本元号〕 ~j")
      yield_c( eng1_m_date(os.date("%m")).." "..eng2_d_date(os.date("%d"))..", "..os.date("%Y"), "〔月日年〕 ~a")
      yield_c( eng2_d_date(os.date("%d")).." "..eng1_m_date(os.date("%m")).." "..os.date("%Y"), "〔日月年〕 ~e")
      -- local chinese_date = to_chinese_cal_local(os.time())
      local ll_1, ll_2 = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( ll_1, "〔農曆〕 ~l")
      return true
    end

    if (input == env.prefix .. "fj") then
      local jpymd, jp_y = jp_ymd(os.date("%Y"),os.date("%m"),os.date("%d"))
      yield_c( string.gsub(jpymd, "([^%d])0", "%1"), "〔日本元号〕")
      yield_c( fullshape_number(string.gsub(jpymd, "([^%d])0", "%1")), "〔日本元号〕")
      yield_c( jpymd, "〔日本元号〕")
      yield_c( fullshape_number(jpymd), "〔日本元号〕")
      return true
    end
    -- if (input == env.prefix .. "fj") then
    --   yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")), "〔年月日〕")
    --   return
    -- end

    if (input == env.prefix .. "fh") then
      yield_c( string.gsub("民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月"..os.date("%d").."日", "([^%d])0", "%1"), "〔民國〕")
      yield_c( string.gsub("民國 "..min_guo(os.date("%Y")).." 年 "..os.date("%m").." 月 "..os.date("%d").." 日", "([^%d])0", "%1"), "〔民國*〕")
      yield_c( "民國"..fullshape_number(min_guo(os.date("%Y"))).."年"..fullshape_number(string.gsub(os.date("%m月%d日"), "0([%d])", "%1")), "〔民國〕")
      yield_c( "民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月"..os.date("%d").."日", "〔民國〕")
      yield_c( "民國 "..min_guo(os.date("%Y")).." 年 "..os.date("%m").." 月 "..os.date("%d").." 日", "〔民國*〕")
      yield_c( "民國"..fullshape_number(min_guo(os.date("%Y"))).."年"..fullshape_number(os.date("%m")).."月"..fullshape_number(os.date("%d")).."日", "〔民國〕")
      return true
    end

    if (input == env.prefix .. "fg") then
      yield_c( "民國"..purech_number(min_guo(os.date("%Y"))).."年"..rqzdx1(23), "〔民國中數〕")
      yield_c( "民國"..read_number(confs[1], min_guo(os.date("%Y"))).."年"..rqzdx1(23), "〔民國中數〕")
      yield_c( "民國"..read_number(confs[2], min_guo(os.date("%Y"))).."年"..rqzdx2(23), "〔民國中數〕")
      return true
    end

    if (input == env.prefix .. "fl") then
      -- local chinese_date = to_chinese_cal_local(os.time())
      local ll_1, ll_2 = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( ll_1, "〔農曆〕")
      yield_c( ll_2, "〔農曆〕")
      local All_g, Y_g, M_g, D_g = lunarJzl(os.date("%Y%m%d%H"))
      yield_c( Y_g.."年"..M_g.."月"..D_g.."日", "〔農曆干支〕")
      return true
    end

    if (input == env.prefix .. "fa") then
      yield_c( eng1_m_date(os.date("%m")).." "..eng2_d_date(os.date("%d"))..", "..os.date("%Y"), "〔月日年〕")
      yield_c( eng1_m_date(os.date("%m")).." "..eng3_d_date(os.date("%d"))..", "..os.date("%Y"), "〔月日年〕")
      yield_c( eng2_m_date(os.date("%m")).." "..eng3_d_date(os.date("%d"))..", "..os.date("%Y"), "〔月日年〕")
      yield_c( eng3_m_date(os.date("%m")).." "..eng4_d_date(os.date("%d")).." "..os.date("%Y"), "〔月日年〕")
      yield_c( eng1_m_date(os.date("%m")).." the "..eng1_d_date(os.date("%d"))..", "..os.date("%Y"), "〔月日年〕")
      return true
    end

    if (input == env.prefix .. "fe") then
      yield_c( eng2_d_date(os.date("%d")).." "..eng1_m_date(os.date("%m")).." "..os.date("%Y"), "〔日月年〕")
      yield_c( eng3_d_date(os.date("%d")).." "..eng1_m_date(os.date("%m")).." "..os.date("%Y"), "〔日月年〕")
      yield_c( eng2_d_date(os.date("%d")).." "..eng2_m_date(os.date("%m")).." "..os.date("%Y"), "〔日月年〕")
      yield_c( "the "..eng1_d_date(os.date("%d")).." of "..eng1_m_date(os.date("%m"))..", "..os.date("%Y"), "〔日月年〕")
      yield_c( "The "..eng1_d_date(os.date("%d")).." of "..eng1_m_date(os.date("%m"))..", "..os.date("%Y"), "〔日月年〕")
      return true
    end

    if (input == env.prefix .. "fc") then
      yield_c( string.gsub(os.date("%Y年%m月%d日"), "([^%d])0", "%1"), "〔年月日〕")
      yield_c( string.gsub(os.date(" %Y 年 %m 月 %d 日 "), "([^%d])0", "%1"), "〔*年月日*〕")
      yield_c( fullshape_number(string.gsub(os.date("%Y年%m月%d日"), "([^%d])0", "%1")), "〔年月日〕")
      yield_c( os.date("%Y年%m月%d日"), "〔年月日〕")
      yield_c( os.date(" %Y 年 %m 月 %d 日 "), "〔*年月日*〕")
      yield_c( fullshape_number(os.date("%Y")).."年"..fullshape_number(os.date("%m")).."月"..fullshape_number(os.date("%d")).."日", "〔年月日〕")
      return true
    end

    if (input == env.prefix .. "fd") or (input == env.prefix .. "fo") then
      yield_c( os.date("%Y%m%d"), "〔年月日〕")
      yield_c( fullshape_number(os.date("%Y"))..fullshape_number(os.date("%m"))..fullshape_number(os.date("%d")), "〔年月日〕")
      yield_c( os.date("%d%m%Y"), "〔日月年〕")
      yield_c( os.date("%m%d%Y"), "〔月日年〕")
      return true
    end

    if (input == env.prefix .. "fm") or (input == env.prefix .. "fr") then
      yield_c( os.date("%Y-%m-%d"), "〔年月日〕")
      yield_c( fullshape_number(os.date("%Y")).."－"..fullshape_number(os.date("%m")).."－"..fullshape_number(os.date("%d")), "〔年月日〕")
      yield_c( os.date("%d-%m-%Y"), "〔日月年〕")
      yield_c( os.date("%m-%d-%Y"), "〔月日年〕")
      return true
    end

    if (input == env.prefix .. "fs")  or (input == env.prefix .. "fy") then
      yield_c( os.date("%Y/%m/%d"), "〔年月日〕")
      -- yield_c( fullshape_number(os.date("%Y")).."/"..fullshape_number(os.date("%m")).."/"..fullshape_number(os.date("%d")), "〔年月日〕")
      yield_c( fullshape_number(os.date("%Y")).."／"..fullshape_number(os.date("%m")).."／"..fullshape_number(os.date("%d")), "〔年月日〕")
      yield_c( os.date("%d/%m/%Y"), "〔日月年〕")
      yield_c( os.date("%m/%d/%Y"), "〔月日年〕")
      return true
    end

    if (input == env.prefix .. "fu") or (input == env.prefix .. "fv") then
      yield_c( os.date("%Y_%m_%d"), "〔年月日〕")
      -- yield_c( fullshape_number(os.date("%Y")).."_"..fullshape_number(os.date("%m")).."_"..fullshape_number(os.date("%d")), "〔年月日〕")
      yield_c( fullshape_number(os.date("%Y")).."＿"..fullshape_number(os.date("%m")).."＿"..fullshape_number(os.date("%d")), "〔年月日〕")
      yield_c( os.date("%d_%m_%Y"), "〔日月年〕")
      yield_c( os.date("%m_%d_%Y"), "〔月日年〕")
      return true
    end

    if (input == env.prefix .. "fp") or (input == env.prefix .. "fq") then
      yield_c( os.date("%Y.%m.%d"), "〔年月日〕")
      -- yield_c( fullshape_number(os.date("%Y")).."."..fullshape_number(os.date("%m")).."."..fullshape_number(os.date("%d")), "〔年月日〕")
      yield_c( fullshape_number(os.date("%Y")).."．"..fullshape_number(os.date("%m")).."．"..fullshape_number(os.date("%d")), "〔年月日〕")
      yield_c( os.date("%d.%m.%Y"), "〔日月年〕")
      yield_c( os.date("%m.%d.%Y"), "〔月日年〕")
      return true
    end

    if (input == env.prefix .. "fz") then
      yield_c( rqzdx1(), "〔中數〕")
      yield_c( rqzdx2(), "〔中數〕")
      return true
    end

    if (input == env.prefix .. "fn") then
      yield_c( os.date("%Y%m%d %H:%M"), "〔年月日 時:分〕 ~d   ~o")
      yield_c( os.date("%Y.%m.%d %H:%M"), "〔年月日 時:分〕 ~p   ~q")
      yield_c( os.date("%Y/%m/%d %H:%M"), "〔年月日 時:分〕 ~s   ~y")
      yield_c( os.date("%Y-%m-%d %H:%M"), "〔年月日 時:分〕 ~m   ~r")
      yield_c( os.date("%Y_%m_%d %H:%M"), "〔年月日 時:分〕 ~u   ~v")
      yield_c( os.date("%Y-%m-%d-%H-%M ") .. timezone_out()[1], "〔本地時  時區〕 ~i")
      yield_c( os.date("%Y-%m-%dT%H:%M") .. timezone_out()[3], "〔本地時  RFC 3339/ISO 8601〕 ~f")
      yield_c( string.gsub(os.date("%Y年%m月%d日 %H點%M分"), "([^%d])0", "%1"), "〔年月日 時:分〕 ~c")
      yield_c( rqzdx1().." "..ch_h_date(os.date("%H")).."點"..ch_minsec_date(os.date("%M")).."分", "〔中數〕 ~z")
      yield_c( string.gsub("民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月"..os.date("%d").."日 "..os.date("%H點%M分"), "([^%d])0", "%1"), "〔民國〕 ~h")
      yield_c( "民國"..purech_number(min_guo(os.date("%Y"))).."年"..rqzdx1(23).." "..ch_h_date(os.date("%H")).."點"..ch_minsec_date(os.date("%M")).."分", "〔民國中數〕 ~g")
      -- yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." "..os.date("%H")..":"..os.date("%M"), "〔年月日 時:分〕 ~j")
      local jpymd, jp_y = jp_ymd(os.date("%Y"),os.date("%m"),os.date("%d"))
      yield_c( string.gsub(jpymd, "([^%d])0", "%1").." "..os.date("%H:%M"), "〔日本元号〕 ~j")
      -- local chinese_date = to_chinese_cal_local(os.time())
      -- local chinese_time = time_description_chinese(os.time())
      local ll_1, ll_2 = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( ll_1 .." ".. time_description_chinese(os.time()), "〔農曆〕 ~l")
      return true
    end

    if (input == env.prefix .. "fni") then
      yield_c( os.date("%Y-%m-%d-%H-%M ") .. timezone_out()[1], "〔本地時  時區〕")
      yield_c( os.date("%Y-%m-%d-%H-%M ") .. timezone_out()[5], "〔本地時  時區〕")
      yield_c( os.date("%Y-%m-%d-%H-%M ") .. timezone_out()[2], "〔本地時  時區〕")
      yield_c( os.date("!%Y-%m-%d-%H-%M UTC"), "〔世界時  時區〕")
      yield_c( os.date("!%Y-%m-%d-%H-%M GMT"), "〔世界時  時區〕")
      return true
    end

    if (input == env.prefix .. "fnf") then
      yield_c( os.date("%Y-%m-%dT%H:%M") .. timezone_out()[3], "〔本地時  RFC 3339/ISO 8601〕")
      yield_c( os.date("%Y%m%dT%H%M") .. timezone_out()[4], "〔本地時  RFC 3339/ISO 8601〕")
      yield_c( os.date("!%Y-%m-%dT%H:%MZ"), "〔世界時  RFC 3339/ISO 8601〕")
      yield_c( os.date("!%Y%m%dT%H%MZ"), "〔世界時  RFC 3339/ISO 8601〕")
      return true
    end

    if (input == env.prefix .. "fnj") then
      local jpymd, jp_y = jp_ymd(os.date("%Y"),os.date("%m"),os.date("%d"))
      yield_c( string.gsub(jpymd, "([^%d])0", "%1").." "..os.date("%H:%M"), "〔日本元号〕")
      yield_c( fullshape_number(string.gsub(jpymd, "([^%d])0", "%1")).." "..os.date("%H:%M"), "〔日本元号〕")
      yield_c( jpymd.." "..os.date("%H:%M"), "〔日本元号〕")
      yield_c( fullshape_number(jpymd.." "..os.date("%H:%M")), "〔日本元号〕")
      return true
    end
    -- if (input == env.prefix .. "fnj") then
    --   yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." "..os.date("%H")..":"..os.date("%M"), "〔年月日 時:分〕")
    --   return
    -- end

    if (input == env.prefix .. "fnh") then
      yield_c( string.gsub("民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月"..os.date("%d").."日 "..os.date("%H點%M分"), "([^%d])0", "%1"), "〔民國〕")
      yield_c( string.gsub("民國 "..min_guo(os.date("%Y")).." 年 "..os.date("%m").." 月 "..os.date("%d").." 日 "..os.date("%H 點 %M 分"), "([^%d])0", "%1"), "〔民國*〕")
      yield_c( "民國"..fullshape_number(min_guo(os.date("%Y"))).."年"..fullshape_number(string.gsub(os.date("%m月%d日%H點%M分"), "0([%d])", "%1")), "〔民國〕")
      yield_c( "民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月"..os.date("%d").."日"..os.date("%H點%M分"), "〔民國〕")
      yield_c( "民國 "..min_guo(os.date("%Y")).." 年 "..os.date("%m").." 月 "..os.date("%d").." 日 "..os.date("%H 點 %M 分"), "〔民國*〕")
      yield_c( "民國"..fullshape_number(min_guo(os.date("%Y"))).."年"..fullshape_number(os.date("%m")).."月"..fullshape_number(os.date("%d")).."日"..fullshape_number(os.date("%H點%M分")), "〔民國〕")
      return true
    end

    if (input == env.prefix .. "fng") then
      yield_c( "民國"..purech_number(min_guo(os.date("%Y"))).."年"..rqzdx1(23).." "..ch_h_date(os.date("%H")).."點"..ch_minsec_date(os.date("%M")).."分", "〔民國中數〕")
      yield_c( "民國"..read_number(confs[1], min_guo(os.date("%Y"))).."年"..rqzdx1(23).." "..ch_h_date(os.date("%H")).."點"..ch_minsec_date(os.date("%M")).."分", "〔民國中數〕")
      yield_c( "民國"..read_number(confs[2], min_guo(os.date("%Y"))).."年"..rqzdx2(23).." "..chb_h_date(os.date("%H")).."點"..chb_minsec_date(os.date("%M")).."分", "〔民國中數〕")
      return true
    end

    if (input == env.prefix .. "fnl") then
      -- local chinese_date = to_chinese_cal_local(os.time())
      -- local chinese_time = time_description_chinese(os.time())
      local ll_1, ll_2 = Date2LunarDate(os.date("%Y%m%d"))
      local All_g = lunarJzl(os.date("%Y%m%d%H"))
      yield_c( ll_1 .." ".. time_description_chinese(os.time()), "〔農曆〕")
      yield_c( ll_2 .." ".. time_description_chinese(os.time()), "〔農曆〕")
      yield_c( All_g, "〔農曆干支〕")
      return true
    end

    if (input == env.prefix .. "fnc") then
      yield_c( string.gsub(os.date("%Y年%m月%d日 %H點%M分"), "([^%d])0", "%1"), "〔年月日 時:分〕")
      yield_c( string.gsub(os.date(" %Y 年 %m 月 %d 日 %H 點 %M 分 "), "([^%d])0", "%1"), "〔*年月日 時:分*〕")
      yield_c( fullshape_number(string.gsub(os.date("%Y年%m月%d日　%H點%M分"), "([^%d])0", "%1")), "〔年月日 時:分〕")
      yield_c( os.date("%Y年%m月%d日 %H點%M分"), "〔年月日 時:分〕")
      yield_c( os.date(" %Y 年 %m 月 %d 日 %H 點 %M 分 "), "〔*年月日 時:分*〕")
      yield_c( fullshape_number(os.date("%Y")).."年"..fullshape_number(os.date("%m")).."月"..fullshape_number(os.date("%d")).."日　"..fullshape_number(os.date("%H")).."點"..fullshape_number(os.date("%M")).."分", "〔年月日 時:分〕")
      return true
    end

    if (input == env.prefix .. "fnd") or (input == env.prefix .. "fno") then
      yield_c( os.date("%Y%m%d %H:%M"), "〔年月日 時:分〕")
      yield_c( fullshape_number(os.date("%Y"))..fullshape_number(os.date("%m"))..fullshape_number(os.date("%d")).."　"..fullshape_number(os.date("%H")).."："..fullshape_number(os.date("%M")), "〔年月日 時:分〕")
      yield_c( os.date("%d%m%Y %H:%M"), "〔日月年 時:分〕")
      yield_c( os.date("%m%d%Y %H:%M"), "〔月日年 時:分〕")
      return true
    end

    if (input == env.prefix .. "fns") or (input == env.prefix .. "fny") then
      yield_c( os.date("%Y/%m/%d %H:%M"), "〔年月日 時:分〕")
      -- yield_c( fullshape_number(os.date("%Y")).."/"..fullshape_number(os.date("%m")).."/"..fullshape_number(os.date("%d")).." "..fullshape_number(os.date("%H"))..":"..fullshape_number(os.date("%M")), "〔年月日 時:分〕")
      yield_c( fullshape_number(os.date("%Y")).."／"..fullshape_number(os.date("%m")).."／"..fullshape_number(os.date("%d")).."　"..fullshape_number(os.date("%H")).."："..fullshape_number(os.date("%M")), "〔年月日 時:分〕")
      yield_c( os.date("%d/%m/%Y %H:%M"), "〔日月年 時:分〕")
      yield_c( os.date("%m/%d/%Y %H:%M"), "〔月日年 時:分〕")
      return true
    end

    if (input == env.prefix .. "fnm") or (input == env.prefix .. "fnr") then
      yield_c( os.date("%Y-%m-%d %H:%M"), "〔年月日 時:分〕")
      yield_c( fullshape_number(os.date("%Y")).."－"..fullshape_number(os.date("%m")).."－"..fullshape_number(os.date("%d")).."　"..fullshape_number(os.date("%H")).."："..fullshape_number(os.date("%M")), "〔年月日 時:分〕")
      yield_c( os.date("%d-%m-%Y %H:%M"), "〔日月年 時:分〕")
      yield_c( os.date("%m-%d-%Y %H:%M"), "〔月日年 時:分〕")
      return true
    end

    if (input == env.prefix .. "fnu") or (input == env.prefix .. "fnv") then
      yield_c( os.date("%Y_%m_%d %H:%M"), "〔年月日 時:分〕")
      -- yield_c( fullshape_number(os.date("%Y")).."_"..fullshape_number(os.date("%m")).."_"..fullshape_number(os.date("%d")).." "..fullshape_number(os.date("%H"))..":"..fullshape_number(os.date("%M")), "〔年月日 時:分〕")
      yield_c( fullshape_number(os.date("%Y")).."＿"..fullshape_number(os.date("%m")).."＿"..fullshape_number(os.date("%d")).."　"..fullshape_number(os.date("%H")).."："..fullshape_number(os.date("%M")), "〔年月日 時:分〕")
      yield_c( os.date("%d_%m_%Y %H:%M"), "〔日月年 時:分〕")
      yield_c( os.date("%m_%d_%Y %H:%M"), "〔月日年 時:分〕")
      return true
    end

    if (input == env.prefix .. "fnp") or (input == env.prefix .. "fnq") then
      yield_c( os.date("%Y.%m.%d %H:%M"), "〔年月日 時:分〕")
      -- yield_c( fullshape_number(os.date("%Y")).."."..fullshape_number(os.date("%m")).."."..fullshape_number(os.date("%d")).." "..fullshape_number(os.date("%H"))..":"..fullshape_number(os.date("%M")), "〔年月日 時:分〕")
      yield_c( fullshape_number(os.date("%Y")).."．"..fullshape_number(os.date("%m")).."．"..fullshape_number(os.date("%d")).."　"..fullshape_number(os.date("%H")).."："..fullshape_number(os.date("%M")), "〔年月日 時:分〕")
      yield_c( os.date("%d.%m.%Y %H:%M"), "〔日月年 時:分〕")
      yield_c( os.date("%m.%d.%Y %H:%M"), "〔月日年 時:分〕")
      return true
    end

    if (input == env.prefix .. "fnz") then
      yield_c( rqzdx1().." "..ch_h_date(os.date("%H")).."點"..ch_minsec_date(os.date("%M")).."分", "〔中數〕")
      yield_c( rqzdx2().." "..chb_h_date(os.date("%H")).."點"..chb_minsec_date(os.date("%M")).."分", "〔中數〕")
      return true
    end

    if (input == env.prefix .. "ft") then
      yield_c( os.date("%Y%m%d %H:%M:%S"), "〔年月日 時:分:秒〕 ~d   ~o")
      yield_c( os.date("%Y.%m.%d %H:%M:%S"), "〔年月日 時:分:秒〕 ~p   ~q")
      yield_c( os.date("%Y/%m/%d %H:%M:%S"), "〔年月日 時:分:秒〕 ~s   ~y")
      yield_c( os.date("%Y-%m-%d %H:%M:%S"), "〔年月日 時:分:秒〕 ~m   ~r")
      yield_c( os.date("%Y_%m_%d %H:%M:%S"), "〔年月日 時:分:秒〕 ~u   ~v")
      yield_c( os.date("%Y-%m-%d-%H-%M-%S ") .. timezone_out()[1], "〔本地時  時區〕 ~i")
      yield_c( os.date("%Y-%m-%dT%H:%M:%S") .. timezone_out()[3], "〔本地時  RFC 3339/ISO 8601〕 ~f")
      yield_c( string.gsub(os.date("%Y年%m月%d日 %H點%M分%S秒"), "([^%d])0", "%1"), "〔年月日 時:分:秒〕 ~c")
      yield_c( rqzdx1().." "..ch_h_date(os.date("%H")).."點"..ch_minsec_date(os.date("%M")).."分"..ch_minsec_date(os.date("%S")).."秒", "〔中數〕 ~z")
      yield_c( string.gsub("民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月"..os.date("%d").."日 "..os.date("%H點%M分%S秒"), "([^%d])0", "%1"), "〔民國〕 ~h")
      yield_c( "民國"..purech_number(min_guo(os.date("%Y"))).."年"..rqzdx1(23).." "..ch_h_date(os.date("%H")).."點"..ch_minsec_date(os.date("%M")).."分"..ch_minsec_date(os.date("%S")).."秒", "〔民國中數〕 ~g")
      -- yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." "..os.date("%H")..":"..os.date("%M")..":"..os.date("%S"), "〔年月日 時:分:秒〕 ~j")
      local jpymd, jp_y = jp_ymd(os.date("%Y"),os.date("%m"),os.date("%d"))
      yield_c( string.gsub(jpymd, "([^%d])0", "%1").." "..os.date("%H:%M:%S"), "〔日本元号〕 ~j")
      return true
    end

    if (input == env.prefix .. "fti") then
      yield_c( os.date("%Y-%m-%d-%H-%M-%S ") .. timezone_out()[1], "〔本地時  時區〕")
      yield_c( os.date("%Y-%m-%d-%H-%M-%S ") .. timezone_out()[5], "〔本地時  時區〕")
      yield_c( os.date("%Y-%m-%d-%H-%M-%S ") .. timezone_out()[2], "〔本地時  時區〕")
      yield_c( os.date("!%Y-%m-%d-%H-%M-%S UTC"), "〔世界時  時區〕")
      yield_c( os.date("!%Y-%m-%d-%H-%M-%S GMT"), "〔世界時  時區〕")
      return true
    end

    if (input == env.prefix .. "ftf") then
      yield_c( os.date("%Y-%m-%dT%H:%M:%S") .. timezone_out()[3], "〔本地時  RFC 3339/ISO 8601〕")
      yield_c( os.date("%Y%m%dT%H%M%S") .. timezone_out()[4], "〔本地時  RFC 3339/ISO 8601〕")
      yield_c( os.date("!%Y-%m-%dT%H:%M:%SZ"), "〔世界時  RFC 3339/ISO 8601〕")
      yield_c( os.date("!%Y%m%dT%H%M%SZ"), "〔世界時  RFC 3339/ISO 8601〕")
      return true
    end

    if (input == env.prefix .. "ftj") then
      local jpymd, jp_y = jp_ymd(os.date("%Y"),os.date("%m"),os.date("%d"))
      yield_c( string.gsub(jpymd, "([^%d])0", "%1").." "..os.date("%H:%M:%S"), "〔日本元号〕")
      yield_c( fullshape_number(string.gsub(jpymd, "([^%d])0", "%1")).." "..os.date("%H:%M:%S"), "〔日本元号〕")
      yield_c( jpymd.." "..os.date("%H:%M:%S"), "〔日本元号〕")
      yield_c( fullshape_number(jpymd.." "..os.date("%H:%M:%S")), "〔日本元号〕")
      return true
    end
    -- if (input == env.prefix .. "ftj") then
    --   yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." "..os.date("%H")..":"..os.date("%M")..":"..os.date("%S"), "〔年月日 時:分:秒〕")
    --   return
    -- end

    if (input == env.prefix .. "fth") then
      yield_c( string.gsub("民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月"..os.date("%d").."日 "..os.date("%H點%M分%S秒"), "([^%d])0", "%1"), "〔民國〕")
      yield_c( string.gsub("民國 "..min_guo(os.date("%Y")).." 年 "..os.date("%m").." 月 "..os.date("%d").." 日 "..os.date("%H 點 %M 分 %S 秒"), "([^%d])0", "%1"), "〔民國*〕")
      yield_c( "民國"..fullshape_number(min_guo(os.date("%Y"))).."年"..fullshape_number(string.gsub(os.date("%m月%d日%H點%M分%S秒"), "0([%d])", "%1")), "〔民國〕")
      yield_c( "民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月"..os.date("%d").."日"..os.date("%H點%M分%S秒"), "〔民國〕")
      yield_c( "民國 "..min_guo(os.date("%Y")).." 年 "..os.date("%m").." 月 "..os.date("%d").." 日 "..os.date("%H 點 %M 分 %S 秒"), "〔民國*〕")
      yield_c( "民國"..fullshape_number(min_guo(os.date("%Y"))).."年"..fullshape_number(os.date("%m")).."月"..fullshape_number(os.date("%d")).."日"..fullshape_number(os.date("%H點%M分%S秒")), "〔民國〕")
      return true
    end

    if (input == env.prefix .. "ftg") then
      yield_c( "民國"..purech_number(min_guo(os.date("%Y"))).."年"..rqzdx1(23).." "..ch_h_date(os.date("%H")).."點"..ch_minsec_date(os.date("%M")).."分"..ch_minsec_date(os.date("%S")).."秒", "〔民國中數〕")
      yield_c( "民國"..read_number(confs[1], min_guo(os.date("%Y"))).."年"..rqzdx1(23).." "..ch_h_date(os.date("%H")).."點"..ch_minsec_date(os.date("%M")).."分"..ch_minsec_date(os.date("%S")).."秒", "〔民國中數〕")
      yield_c( "民國"..read_number(confs[2], min_guo(os.date("%Y"))).."年"..rqzdx2(23).." "..chb_h_date(os.date("%H")).."點"..chb_minsec_date(os.date("%M")).."分"..chb_minsec_date(os.date("%S")).."秒", "〔民國中數〕")
      return true
    end

    if (input == env.prefix .. "ftc") then
      yield_c( string.gsub(os.date("%Y年%m月%d日 %H點%M分%S秒"), "([^%d])0", "%1"), "〔年月日 時:分:秒〕")
      yield_c( string.gsub(os.date(" %Y 年 %m 月 %d 日 %H 點 %M 分 %S 秒 "), "([^%d])0", "%1"), "〔*年月日 時:分:秒*〕")
      yield_c( fullshape_number(string.gsub(os.date("%Y年%m月%d日　%H點%M分%S秒"), "([^%d])0", "%1")), "〔年月日 時:分:秒〕")
      yield_c( os.date("%Y年%m月%d日 %H點%M分%S秒"), "〔年月日 時:分:秒〕")
      yield_c( os.date(" %Y 年 %m 月 %d 日 %H 點 %M 分 %S 秒 "), "〔*年月日 時:分:秒*〕")
      yield_c( fullshape_number(os.date("%Y")).."年"..fullshape_number(os.date("%m")).."月"..fullshape_number(os.date("%d")).."日　"..fullshape_number(os.date("%H")).."點"..fullshape_number(os.date("%M")).."分"..fullshape_number(os.date("%S")).."秒", "〔年月日 時:分:秒〕")
      return true
    end

    if (input == env.prefix .. "ftd") or (input == env.prefix .. "fto") then
      yield_c( os.date("%Y%m%d %H:%M:%S"), "〔年月日 時:分:秒〕")
      yield_c( fullshape_number(os.date("%Y"))..fullshape_number(os.date("%m"))..fullshape_number(os.date("%d")).."　"..fullshape_number(os.date("%H")).."："..fullshape_number(os.date("%M")).."："..fullshape_number(os.date("%S")), "〔年月日 時:分:秒〕")
      yield_c( os.date("%d%m%Y %H:%M:%S"), "〔日月年 時:分:秒〕")
      yield_c( os.date("%m%d%Y %H:%M:%S"), "〔月日年 時:分:秒〕")
      return true
    end

    if (input == env.prefix .. "fts") or (input == env.prefix .. "fty") then
      yield_c( os.date("%Y/%m/%d %H:%M:%S"), "〔年月日 時:分:秒〕")
      -- yield_c( fullshape_number(os.date("%Y")).."/"..fullshape_number(os.date("%m")).."/"..fullshape_number(os.date("%d")).." "..fullshape_number(os.date("%H"))..":"..fullshape_number(os.date("%M"))..":"..fullshape_number(os.date("%S")), "〔年月日 時:分:秒〕")
      yield_c( fullshape_number(os.date("%Y")).."／"..fullshape_number(os.date("%m")).."／"..fullshape_number(os.date("%d")).."　"..fullshape_number(os.date("%H")).."："..fullshape_number(os.date("%M")).."："..fullshape_number(os.date("%S")), "〔年月日 時:分:秒〕")
      yield_c( os.date("%d/%m/%Y %H:%M:%S"), "〔日月年 時:分:秒〕")
      yield_c( os.date("%m/%d/%Y %H:%M:%S"), "〔月日年 時:分:秒〕")
      return true
    end

    if (input == env.prefix .. "ftm") or (input == env.prefix .. "ftr") then
      yield_c( os.date("%Y-%m-%d %H:%M:%S"), "〔年月日 時:分:秒〕")
      yield_c( fullshape_number(os.date("%Y")).."－"..fullshape_number(os.date("%m")).."－"..fullshape_number(os.date("%d")).."　"..fullshape_number(os.date("%H")).."："..fullshape_number(os.date("%M")).."："..fullshape_number(os.date("%S")), "〔年月日 時:分:秒〕")
      yield_c( os.date("%d-%m-%Y %H:%M:%S"), "〔日月年 時:分:秒〕")
      yield_c( os.date("%m-%d-%Y %H:%M:%S"), "〔月日年 時:分:秒〕")
      return true
    end

    if (input == env.prefix .. "ftu") or (input == env.prefix .. "ftv") then
      yield_c( os.date("%Y_%m_%d %H:%M:%S"), "〔年月日 時:分:秒〕")
      -- yield_c( fullshape_number(os.date("%Y")).."_"..fullshape_number(os.date("%m")).."_"..fullshape_number(os.date("%d")).." "..fullshape_number(os.date("%H"))..":"..fullshape_number(os.date("%M"))..":"..fullshape_number(os.date("%S")), "〔年月日 時:分:秒〕")
      yield_c( fullshape_number(os.date("%Y")).."＿"..fullshape_number(os.date("%m")).."＿"..fullshape_number(os.date("%d")).."　"..fullshape_number(os.date("%H")).."："..fullshape_number(os.date("%M")).."："..fullshape_number(os.date("%S")), "〔年月日 時:分:秒〕")
      yield_c( os.date("%d_%m_%Y %H:%M:%S"), "〔日月年 時:分:秒〕")
      yield_c( os.date("%m_%d_%Y %H:%M:%S"), "〔月日年 時:分:秒〕")
      return true
    end

    if (input == env.prefix .. "ftp") or (input == env.prefix .. "ftq") then
      yield_c( os.date("%Y.%m.%d %H:%M:%S"), "〔年月日 時:分:秒〕")
      -- yield_c( fullshape_number(os.date("%Y")).."."..fullshape_number(os.date("%m")).."."..fullshape_number(os.date("%d")).." "..fullshape_number(os.date("%H"))..":"..fullshape_number(os.date("%M"))..":"..fullshape_number(os.date("%S")), "〔年月日 時:分:秒〕")
      yield_c( fullshape_number(os.date("%Y")).."．"..fullshape_number(os.date("%m")).."．"..fullshape_number(os.date("%d")).."　"..fullshape_number(os.date("%H")).."："..fullshape_number(os.date("%M")).."："..fullshape_number(os.date("%S")), "〔年月日 時:分:秒〕")
      yield_c( os.date("%d.%m.%Y %H:%M:%S"), "〔日月年 時:分:秒〕")
      yield_c( os.date("%m.%d.%Y %H:%M:%S"), "〔月日年 時:分:秒〕")
      return true
    end

    if (input == env.prefix .. "ftz") then
      yield_c( rqzdx1().." "..ch_h_date(os.date("%H")).."點"..ch_minsec_date(os.date("%M")).."分"..ch_minsec_date(os.date("%S")).."秒", "〔中數〕")
      yield_c( rqzdx2().." "..chb_h_date(os.date("%H")).."點"..chb_minsec_date(os.date("%M")).."分"..chb_minsec_date(os.date("%S")).."秒", "〔中數〕")
      return true
    end

    if (input == env.prefix .. "y") then
      yield_c( os.date("%Y"), "〔年〕 ~d")
      yield_c( os.date("%Y年"), "〔年〕 ~c")
      yield_c( rqzdx1(1), "〔中數〕 ~z")
      -- yield_c( rqzdx2(1), "〔年〕")
      yield_c( "民國"..min_guo(os.date("%Y")).."年", "〔民國〕 ~h")
      yield_c( "民國"..purech_number(min_guo(os.date("%Y"))).."年", "〔民國中數〕 ~g")
      local jpymd, jp_y = jp_ymd(os.date("%Y"),os.date("%m"),os.date("%d"))
      yield_c( jp_y, "〔日本元号〕 ~j")
      -- local a, b, chinese_y = to_chinese_cal_local(os.time())
      local a, b, ly_1, ly_2, lm, ld = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( ly_1, "〔農曆〕 ~l")
      return true
    end

    if (input == env.prefix .. "yj") then
      local jpymd, jp_y = jp_ymd(os.date("%Y"),os.date("%m"),os.date("%d"))
      yield_c( jp_y, "〔日本元号〕")
      yield_c( fullshape_number(jp_y), "〔日本元号〕")
      return true
    end

    if (input == env.prefix .. "yh") then
      yield_c( "民國"..min_guo(os.date("%Y")).."年", "〔民國〕")
      yield_c( "民國 "..min_guo(os.date("%Y")).." 年", "〔民國*〕")
      yield_c( "民國"..fullshape_number(min_guo(os.date("%Y"))).."年", "〔民國〕")
      return true
    end

    if (input == env.prefix .. "yg") then
      yield_c( "民國"..purech_number(min_guo(os.date("%Y"))).."年", "〔民國中數〕")
      yield_c( "民國"..read_number(confs[1], min_guo(os.date("%Y"))).."年", "〔民國中數〕")
      yield_c( "民國"..read_number(confs[2], min_guo(os.date("%Y"))).."年", "〔民國中數〕")
      return true
    end

    if (input == env.prefix .. "yl") then
      -- local a, b, chinese_y = to_chinese_cal_local(os.time())
      local a, b, ly_1, ly_2, lm, ld = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( ly_1, "〔農曆〕")
      yield_c( ly_2, "〔農曆〕")
      -- local a, Y_g = lunarJzl(os.date("%Y%m%d%H"))
      -- yield_c( Y_g.."年", "〔農曆干支〕")
      return true
    end

    if (input == env.prefix .. "yc") then
      yield_c( os.date("%Y年"), "〔年〕")
      yield_c( os.date(" %Y 年"), "〔*年〕")
      yield_c( fullshape_number(os.date("%Y")).."年", "〔年〕")
      return true
    end

    if (input == env.prefix .. "yd") then
      yield_c( os.date("%Y"), "〔年〕")
      yield_c( fullshape_number(os.date("%Y")), "〔年〕")
      return true
    end

    if (input == env.prefix .. "yz") then
      yield_c( rqzdx1(1), "〔中數〕")
      yield_c( rqzdx2(1), "〔中數〕")
      return true
    end

    if (input == env.prefix .. "m") then
      yield_c( os.date("%m"), "〔月〕 ~m")
      yield_c( string.gsub(os.date("%m月"), "^0", ""), "〔月〕 ~c")
      yield_c( rqzdx1(2), "〔中數〕 ~z")
      -- yield_c( rqzdx2(2), "〔月〕")
      yield_c( jp_m_date(os.date("%m")), "〔日本格式〕 ~j")
      yield_c( eng1_m_date(os.date("%m")), "〔月〕 ~a")
      yield_c( eng2_m_date(os.date("%m")), "〔月〕 ~e")
      -- local a, b, y, chinese_m = to_chinese_cal_local(os.time())
      local a, b, c, d, lm, ld = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( lm, "〔農曆〕 ~l")
      return true
    end

    if (input == env.prefix .. "ml") then
      -- local a, b, y, chinese_m = to_chinese_cal_local(os.time())
      local a, b, c, d, lm, ld = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( lm, "〔農曆〕")
      local All_g, Y_g, M_g = lunarJzl(os.date("%Y%m%d%H"))
      yield_c( M_g.."月", "〔農曆干支〕")
      return true
    end

    if (input == env.prefix .. "ma") then
      yield_c( eng1_m_date(os.date("%m")), "〔月〕")
      yield_c( " "..eng1_m_date(os.date("%m")).." ", "〔*月*〕")
      return true
    end

    if (input == env.prefix .. "me") then
      yield_c( eng2_m_date(os.date("%m")), "〔月〕")
      yield_c( " "..eng2_m_date(os.date("%m")).." ", "〔*月*〕")
      yield_c( eng3_m_date(os.date("%m")), "〔月〕")
      yield_c( " "..eng3_m_date(os.date("%m")).." ", "〔*月*〕")
      return true
    end

    if (input == env.prefix .. "mj") then
      yield_c( jp_m_date(os.date("%m")), "〔日本格式〕")
      return true
    end

    if (input == env.prefix .. "mc") then
      yield_c( string.gsub(os.date("%m月"), "^0", ""), "〔月〕")
      yield_c( string.gsub(os.date(" %m 月"), "([ ])0", "%1"), "〔*月〕")
      yield_c( fullshape_number(string.gsub(os.date("%m月"), "^0", "")), "〔月〕")
      yield_c( os.date("%m月"), "〔月〕")
      yield_c( os.date(" %m 月"), "〔*月〕")
      yield_c( fullshape_number(os.date("%m")).."月", "〔月〕")
      return true
    end

    if (input == env.prefix .. "mm") then
      yield_c( os.date("%m"), "〔月〕")
      yield_c( fullshape_number(os.date("%m")), "〔月〕")
      return true
    end

    if (input == env.prefix .. "mz") then
      yield_c( rqzdx1(2), "〔中數〕")
      yield_c( rqzdx2(2), "〔中數〕")
      return true
    end

    if (input == env.prefix .. "d") then
      yield_c( os.date("%d"), "〔日〕 ~d")
      yield_c( string.gsub(os.date("%d日"), "^0", ""), "〔日〕 ~c")
      yield_c( rqzdx1(3), "〔中數〕 ~z")
      -- yield_c( rqzdx2(3), "〔日〕")
      yield_c( jp_d_date(os.date("%d")), "〔日本格式〕 ~j")
      yield_c( "the "..eng1_d_date(os.date("%d")), "〔日〕 ~a")
      yield_c( eng2_d_date(os.date("%d")), "〔日〕 ~e")
      -- local a, b, y, m, chinese_d = to_chinese_cal_local(os.time())
      local a, b, c, d, e, ld = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( ld, "〔農曆〕 ~l")
      return true
    end

    if (input == env.prefix .. "dl") then
      -- local a, b, y, m, chinese_d = to_chinese_cal_local(os.time())
      local a, b, c, d, e, ld = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( ld, "〔農曆〕")
      local All_g, Y_g, M_g, D_g = lunarJzl(os.date("%Y%m%d%H"))
      yield_c( D_g.."日", "〔農曆干支〕")
      return true
    end

    if (input == env.prefix .. "da") then
      yield_c( "the "..eng1_d_date(os.date("%d")), "〔日〕")
      yield_c( " the "..eng1_d_date(os.date("%d")).." ", "〔*日*〕")
      yield_c( "The "..eng1_d_date(os.date("%d")), "〔日〕")
      yield_c( " The "..eng1_d_date(os.date("%d")).." ", "〔*日*〕")
      return true
    end

    if (input == env.prefix .. "de") then
      yield_c( eng2_d_date(os.date("%d")), "〔日〕")
      yield_c( " "..eng2_d_date(os.date("%d")).." ", "〔*日*〕")
      yield_c( eng4_d_date(os.date("%d")), "〔日〕")
      yield_c( " "..eng4_d_date(os.date("%d")).." ", "〔*日*〕")
      -- yield_c( " "..eng3_d_date(os.date("%d")).." ", "〔*日*〕")
      return true
    end

    if (input == env.prefix .. "dj") then
      yield_c( jp_d_date(os.date("%d")), "〔日本格式〕")
      return true
    end

    if (input == env.prefix .. "dc") then
      yield_c( string.gsub(os.date("%d日"), "^0", ""), "〔日〕")
      yield_c( string.gsub(os.date(" %d 日"), "([ ])0", "%1"), "〔*日〕")
      yield_c( fullshape_number(string.gsub(os.date("%d日"), "^0", "")), "〔日〕")
      yield_c( os.date("%d日"), "〔日〕")
      yield_c( os.date(" %d 日"), "〔*日〕")
      yield_c( fullshape_number(os.date("%d")).."日", "〔日〕")
      return true
    end

    if (input == env.prefix .. "dd") then
      yield_c( os.date("%d"), "〔日〕")
      yield_c( fullshape_number(os.date("%d")), "〔日〕")
      return true
    end

    if (input == env.prefix .. "dz") then
      yield_c( rqzdx1(3), "〔中數〕")
      yield_c( rqzdx2(3), "〔中數〕")
      return true
    end

    if (input == env.prefix .. "md") then
      yield_c( os.date("%m%d"), "〔月日〕 ~d   ~o")
      yield_c( os.date("%m.%d"), "〔月日〕 ~p   ~q")
      yield_c( os.date("%m/%d"), "〔月日〕 ~s   ~y")
      yield_c( os.date("%m-%d"), "〔月日〕 ~m   ~r")
      yield_c( os.date("%m_%d"), "〔月日〕 ~u   ~v")
      yield_c( string.gsub(os.date("%m月%d日"), "0([%d])", "%1"), "〔月日〕 ~c")
      yield_c( rqzdx1(23), "〔中數〕 ~z")
      yield_c( jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")), "〔日本格式〕 ~j")
      yield_c( eng1_m_date(os.date("%m")).." "..eng2_d_date(os.date("%d")), "〔月日〕 ~a")
      yield_c( eng2_d_date(os.date("%d")).." "..eng1_m_date(os.date("%m")), "〔日月〕 ~e")
      -- local a, b, y, chinese_m, chinese_d = to_chinese_cal_local(os.time())
      local a, b, c, d, lm, ld = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( lm..ld, "〔農曆〕 ~l")
      return true
    end

    if (input == env.prefix .. "mdl") then
      -- local a, b, y, chinese_m, chinese_d = to_chinese_cal_local(os.time())
      local a, b, c, d, lm, ld = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( lm..ld, "〔農曆〕")
      local All_g, Y_g, M_g, D_g = lunarJzl(os.date("%Y%m%d%H"))
      yield_c( M_g.."月"..D_g.."日", "〔農曆干支〕")
      return true
    end

    if (input == env.prefix .. "mda") then
      yield_c( eng1_m_date(os.date("%m")).." "..eng2_d_date(os.date("%d")), "〔月日〕")
      yield_c( eng1_m_date(os.date("%m")).." "..eng3_d_date(os.date("%d")), "〔月日〕")
      yield_c( eng2_m_date(os.date("%m")).." "..eng3_d_date(os.date("%d")), "〔月日〕")
      yield_c( eng3_m_date(os.date("%m")).." "..eng4_d_date(os.date("%d")), "〔月日〕")
      yield_c( eng1_m_date(os.date("%m")).." the "..eng1_d_date(os.date("%d")), "〔月日〕")
      return true
    end

    if (input == env.prefix .. "mde") then
      yield_c( eng2_d_date(os.date("%d")).." "..eng1_m_date(os.date("%m")), "〔日月〕")
      yield_c( eng3_d_date(os.date("%d")).." "..eng1_m_date(os.date("%m")), "〔日月〕")
      yield_c( eng2_d_date(os.date("%d")).." "..eng2_m_date(os.date("%m")), "〔日月〕")
      yield_c( "the "..eng1_d_date(os.date("%d")).." of "..eng1_m_date(os.date("%m")), "〔日月〕")
      yield_c( "The "..eng1_d_date(os.date("%d")).." of "..eng1_m_date(os.date("%m")), "〔日月〕")
      return true
    end

    if (input == env.prefix .. "mdj") then
      yield_c( jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")), "〔日本格式〕")
      return true
    end

    if (input == env.prefix .. "mdc") then
      yield_c( string.gsub(os.date("%m月%d日"), "0([%d])", "%1"), "〔月日〕")
      yield_c( string.gsub(os.date(" %m 月 %d 日 "), "([ ])0", "%1"), "〔*月日*〕")
      yield_c( fullshape_number(string.gsub(os.date("%m月%d日"), "0([%d])", "%1")), "〔月日〕")
      yield_c( os.date("%m月%d日"), "〔月日〕")
      yield_c( os.date(" %m 月 %d 日 "), "〔*月日*〕")
      yield_c( fullshape_number(os.date("%m")).."月"..fullshape_number(os.date("%d")).."日", "〔月日〕")
      return true
    end

    if (input == env.prefix .. "mdd") or (input == env.prefix .. "mdo") then
      yield_c( os.date("%m%d"), "〔月日〕")
      yield_c( fullshape_number(os.date("%m"))..fullshape_number(os.date("%d")), "〔月日〕")
      yield_c( os.date("%d%m"), "〔日月〕")
      return true
    end

    if (input == env.prefix .. "mds") or (input == env.prefix .. "mdy") then
      yield_c( os.date("%m/%d"), "〔月日〕")
      -- yield_c( fullshape_number(os.date("%m")).."/"..fullshape_number(os.date("%d")), "〔月日〕")
      yield_c( fullshape_number(os.date("%m")).."／"..fullshape_number(os.date("%d")), "〔月日〕")
      yield_c( os.date("%d/%m"), "〔日月〕")
      return true
    end

    if (input == env.prefix .. "mdm") or (input == env.prefix .. "mdr") then
      yield_c( os.date("%m-%d"), "〔月日〕")
      yield_c( fullshape_number(os.date("%m")).."－"..fullshape_number(os.date("%d")), "〔月日〕")
      yield_c( os.date("%d-%m"), "〔日月〕")
      return true
    end

    if (input == env.prefix .. "mdu") or (input == env.prefix .. "mdv") then
      yield_c( os.date("%m_%d"), "〔月日〕")
      -- yield_c( fullshape_number(os.date("%m")).."_"..fullshape_number(os.date("%d")), "〔月日〕")
      yield_c( fullshape_number(os.date("%m")).."＿"..fullshape_number(os.date("%d")), "〔月日〕")
      yield_c( os.date("%d_%m"), "〔日月〕")
      return true
    end

    if (input == env.prefix .. "mdp") or (input == env.prefix .. "mdq") then
      yield_c( os.date("%m.%d"), "〔月日〕")
      -- yield_c( fullshape_number(os.date("%m")).."."..fullshape_number(os.date("%d")), "〔月日〕")
      yield_c( fullshape_number(os.date("%m")).."．"..fullshape_number(os.date("%d")), "〔月日〕")
      yield_c( os.date("%d.%m"), "〔日月〕")
      return true
    end

    if (input == env.prefix .. "mdz") then
      yield_c( rqzdx1(23), "〔中數〕")
      yield_c( rqzdx2(23), "〔中數〕")
      return true
    end

    if (input == env.prefix .. "mdw") then
      yield_c( string.gsub(os.date("%m月%d日"), "0([%d])", "%1").." ".."星期"..weekstyle()[1].." ", "〔月日週〕 ~c")
      -- yield_c( jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." ".."星期"..weekstyle()[1].." ", "〔月日週〕")
      yield_c( rqzdx1(23).." ".."星期"..weekstyle()[1].." ", "〔中數〕 ~z")
      -- yield_c( rqzdx2(23).." ".."星期"..weekstyle()[1].." ", "〔月日週〕")
      yield_c( jp_m_date(os.date("%m"))..jp_d_date(os.date("%d"))..weekstyle()[3], "〔日本格式〕 ~j")
      yield_c( weekstyle()[6]..", "..eng1_m_date(os.date("%m")).." "..eng2_d_date(os.date("%d")), "〔週月日〕 ~a")
      yield_c( weekstyle()[6]..", "..eng2_d_date(os.date("%d")).." "..eng1_m_date(os.date("%m")), "〔週日月〕 ~e")
      -- local a, b, y, chinese_m, chinese_d = to_chinese_cal_local(os.time())
      local a, b, c, d, lm, ld = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( lm..ld.." "..weekstyle()[5].." ", "〔農曆〕 ~l")
      return true
    end

    if (input == env.prefix .. "mdwl") then
      -- local a, b, y, chinese_m, chinese_d = to_chinese_cal_local(os.time())
      local a, b, c, d, lm, ld = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( lm..ld.." "..weekstyle()[5].." ", "〔農曆〕")
      local All_g, Y_g, M_g, D_g = lunarJzl(os.date("%Y%m%d%H"))
      yield_c( M_g.."月"..D_g.."日".." "..weekstyle()[5].." ", "〔農曆干支〕")
      return true
    end

    if (input == env.prefix .. "mdwa") then
      yield_c( weekstyle()[6]..", "..eng1_m_date(os.date("%m")).." "..eng2_d_date(os.date("%d")), "〔週月日〕")
      yield_c( weekstyle()[6]..", "..eng1_m_date(os.date("%m")).." "..eng3_d_date(os.date("%d")), "〔週月日〕")
      yield_c( weekstyle()[7]..", "..eng2_m_date(os.date("%m")).." "..eng3_d_date(os.date("%d")), "〔週月日〕")
      yield_c( weekstyle()[8].." "..eng3_m_date(os.date("%m")).." "..eng4_d_date(os.date("%d")), "〔週月日〕")
      yield_c( weekstyle()[6]..", "..eng1_m_date(os.date("%m")).." the "..eng1_d_date(os.date("%d")), "〔週月日〕")
      return true
    end

    if (input == env.prefix .. "mdwe") then
      yield_c( weekstyle()[6]..", "..eng2_d_date(os.date("%d")).." "..eng1_m_date(os.date("%m")), "〔週日月〕")
      yield_c( weekstyle()[6]..", "..eng3_d_date(os.date("%d")).." "..eng1_m_date(os.date("%m")), "〔週日月〕")
      yield_c( weekstyle()[7]..", "..eng2_d_date(os.date("%d")).." "..eng2_m_date(os.date("%m")), "〔週日月〕")
      yield_c( weekstyle()[6]..", ".."the "..eng1_d_date(os.date("%d")).." of "..eng1_m_date(os.date("%m")), "〔週日月〕")
      -- yield_c( weekstyle()[6]..", ".."The "..eng1_d_date(os.date("%d")).." of "..eng1_m_date(os.date("%m"))..", "..os.date("%Y"), "〔週日月〕")
      return true
    end

    if (input == env.prefix .. "mdwc") then
      yield_c( string.gsub(os.date("%m月%d日"), "0([%d])", "%1").." ".."星期"..weekstyle()[1].." ", "〔月日週〕")
      yield_c( string.gsub(os.date(" %m 月 %d 日"), "([ ])0", "%1").." ".."星期"..weekstyle()[1].." ", "〔*月日週*〕")
      yield_c( fullshape_number(string.gsub(os.date("%m月%d日"), "0([%d])", "%1")).." ".."星期"..weekstyle()[1].." ", "〔月日週〕")
      yield_c( os.date("%m月%d日").." ".."星期"..weekstyle()[1].." ", "〔月日週〕")
      yield_c( os.date(" %m 月 %d 日").." ".."星期"..weekstyle()[1].." ", "〔*月日週*〕")
      yield_c( fullshape_number(os.date("%m")).."月"..fullshape_number(os.date("%d")).."日".." ".."星期"..weekstyle()[1].." ", "〔月日週〕")
      return true
    end

    if (input == env.prefix .. "mdwj") then
      yield_c( jp_m_date(os.date("%m"))..jp_d_date(os.date("%d"))..weekstyle()[3], "〔日本格式〕")
      yield_c( string.gsub(os.date("%m月%d日"), "0([%d])", "%1")..weekstyle()[3], "〔日本格式〕")
      yield_c( string.gsub(os.date("%m月%d日"), "0([%d])", "%1").." "..weekstyle()[5].."曜日 ", "〔日本格式〕")
      yield_c( string.gsub(os.date("%m月%d日"), "0([%d])", "%1").."("..weekstyle()[5].."曜日)", "〔日本格式〕")
      yield_c( string.gsub(os.date("%m月%d日"), "0([%d])", "%1").."（"..weekstyle()[5].."曜日）", "〔日本格式〕")
      yield_c( fullshape_number(string.gsub(os.date("%m月%d日"), "0([%d])", "%1"))..weekstyle()[3], "〔日本格式〕")
      yield_c( fullshape_number(string.gsub(os.date("%m月%d日"), "0([%d])", "%1")).." "..weekstyle()[5].."曜日 ", "〔日本格式〕")
      yield_c( fullshape_number(string.gsub(os.date("%m月%d日"), "0([%d])", "%1")).."("..weekstyle()[5].."曜日)", "〔日本格式〕")
      yield_c( fullshape_number(string.gsub(os.date("%m月%d日"), "0([%d])", "%1")).."（"..weekstyle()[5].."曜日）", "〔日本格式〕")
      yield_c( os.date("%m月%d日")..weekstyle()[3], "〔日本格式〕")
      yield_c( os.date("%m月%d日").." "..weekstyle()[5].."曜日 ", "〔日本格式〕")
      yield_c( os.date("%m月%d日").."("..weekstyle()[5].."曜日)", "〔日本格式〕")
      yield_c( os.date("%m月%d日").."（"..weekstyle()[5].."曜日）", "〔日本格式〕")
      yield_c( fullshape_number(os.date("%m月%d日")..weekstyle()[3]), "〔日本格式〕")
      yield_c( fullshape_number(os.date("%m月%d日").." "..weekstyle()[5].."曜日 "), "〔日本格式〕")
      yield_c( fullshape_number(os.date("%m月%d日").."("..weekstyle()[5].."曜日)"), "〔日本格式〕")
      yield_c( fullshape_number(os.date("%m月%d日").."（"..weekstyle()[5].."曜日）"), "〔日本格式〕")
      return true
    end

    if (input == env.prefix .. "mdwz") then
      yield_c( rqzdx1(23).." ".."星期"..weekstyle()[1].." ", "〔中數〕")
      yield_c( rqzdx2(23).." ".."星期"..weekstyle()[2].." ", "〔中數〕")
      return true
    end

    if (input == env.prefix .. "ym") then
      yield_c( os.date("%Y%m"), "〔年月〕 ~d   ~o")
      yield_c( os.date("%Y.%m"), "〔年月〕 ~p   ~q")
      yield_c( os.date("%Y/%m"), "〔年月〕 ~s   ~y")
      yield_c( os.date("%Y-%m"), "〔年月〕 ~m   ~r")
      yield_c( os.date("%Y_%m"), "〔年月〕 ~u   ~v")
      yield_c( string.gsub(os.date("%Y年%m月"), "([^%d])0", "%1"), "〔年月〕 ~c")
      yield_c( rqzdx1(12), "〔中數〕 ~z")
      yield_c( string.gsub("民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月", "([^%d])0", "%1"), "〔民國〕 ~h")
      yield_c( "民國"..purech_number(min_guo(os.date("%Y"))).."年"..rqzdx1(2), "〔民國中數〕 ~g")
      -- yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m")), "〔年月〕 ~j")
      local jpymd, jp_y = jp_ymd(os.date("%Y"),os.date("%m"),os.date("%d"))
      yield_c( jp_y..string.gsub(os.date("%m").."月", "([^%d])0", "%1"), "〔日本元号〕 ~j")
      yield_c( eng1_m_date(os.date("%m"))..", "..os.date("%Y"), "〔月年〕 ~a")
      yield_c( eng1_m_date(os.date("%m")).." "..os.date("%Y"), "〔月年〕 ~e")
      -- local a, b, chinese_y, chinese_m = to_chinese_cal_local(os.time())
      local a, b, ly_1, ly_2, lm = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( ly_1..lm, "〔農曆〕 ~l")
      return true
    end

    if (input == env.prefix .. "ymj") then
      local jpymd, jp_y = jp_ymd(os.date("%Y"),os.date("%m"),os.date("%d"))
      yield_c( jp_y..string.gsub(os.date("%m").."月", "([^%d])0", "%1"), "〔日本元号〕")
      yield_c( fullshape_number(jp_y..string.gsub(os.date("%m").."月", "([^%d])0", "%1")), "〔日本元号〕")
      yield_c( jp_y..os.date("%m").."月", "〔日本元号〕")
      yield_c( fullshape_number(jp_y..os.date("%m").."月"), "〔日本元号〕")
      return true
    end
    -- if (input == env.prefix .. "ymj") then
    --   yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m")), "〔年月〕")
    --   return
    -- end

    if (input == env.prefix .. "ymh") then
      yield_c( string.gsub("民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月", "([^%d])0", "%1"), "〔民國〕")
      yield_c( string.gsub("民國 "..min_guo(os.date("%Y")).." 年 "..os.date("%m").." 月", "([^%d])0", "%1"), "〔民國*〕")
      yield_c( "民國"..fullshape_number(min_guo(os.date("%Y"))).."年"..fullshape_number(string.gsub(os.date("%m"), "0([%d])", "%1")).."月", "〔民國〕")
      yield_c( "民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月", "〔民國〕")
      yield_c( "民國 "..min_guo(os.date("%Y")).." 年 "..os.date("%m").." 月", "〔民國*〕")
      yield_c( "民國"..fullshape_number(min_guo(os.date("%Y"))).."年"..fullshape_number(os.date("%m")).."月", "〔民國〕")
      return true
    end

    if (input == env.prefix .. "ymg") then
      yield_c( "民國"..purech_number(min_guo(os.date("%Y"))).."年"..rqzdx1(2), "〔民國中數〕")
      yield_c( "民國"..read_number(confs[1], min_guo(os.date("%Y"))).."年"..rqzdx1(2), "〔民國中數〕")
      yield_c( "民國"..read_number(confs[2], min_guo(os.date("%Y"))).."年"..rqzdx2(2), "〔民國中數〕")
      return true
    end

    if (input == env.prefix .. "yml") then
      -- local a, b, chinese_y, chinese_m = to_chinese_cal_local(os.time())
      local a, b, ly_1, ly_2, lm = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( ly_1..lm, "〔農曆〕")
      yield_c( ly_2..lm, "〔農曆〕")
      local All_g, Y_g, M_g = lunarJzl(os.date("%Y%m%d%H"))
      yield_c( Y_g.."年"..M_g.."月", "〔農曆干支〕")
      return true
    end

    if (input == env.prefix .. "yma") then
      yield_c( eng1_m_date(os.date("%m"))..", "..os.date("%Y"), "〔月年〕")
      yield_c( eng2_m_date(os.date("%m"))..", "..os.date("%Y"), "〔月年〕")
      return true
    end

    if (input == env.prefix .. "yme") then
      yield_c( eng1_m_date(os.date("%m")).." "..os.date("%Y"), "〔月年〕")
      yield_c( eng2_m_date(os.date("%m")).." "..os.date("%Y"), "〔月年〕")
      yield_c( eng3_m_date(os.date("%m")).." "..os.date("%Y"), "〔月年〕")
      return true
    end

    if (input == env.prefix .. "ymc") then
      yield_c( string.gsub(os.date("%Y年%m月"), "([^%d])0", "%1"), "〔年月〕")
      yield_c( string.gsub(os.date(" %Y 年 %m 月 "), "([^%d])0", "%1"), "〔*年月*〕")
      yield_c( fullshape_number(string.gsub(os.date("%Y年%m月"), "([^%d])0", "%1")), "〔年月〕")
      yield_c( os.date("%Y年%m月"), "〔年月〕")
      yield_c( os.date(" %Y 年 %m 月 "), "〔*年月*〕")
      yield_c( fullshape_number(os.date("%Y")).."年"..fullshape_number(os.date("%m")).."月", "〔年月〕")
      return true
    end

    if (input == env.prefix .. "ymd") or (input == env.prefix .. "ymo") then
      yield_c( os.date("%Y%m"), "〔年月〕")
      yield_c( fullshape_number(os.date("%Y"))..fullshape_number(os.date("%m")), "〔年月〕")
      yield_c( os.date("%m%Y"), "〔月年〕")
      return true
    end

    if (input == env.prefix .. "yms") or (input == env.prefix .. "ymy") then
      yield_c( os.date("%Y/%m"), "〔年月〕")
      -- yield_c( fullshape_number(os.date("%Y")).."/"..fullshape_number(os.date("%m")), "〔年月〕")
      yield_c( fullshape_number(os.date("%Y")).."／"..fullshape_number(os.date("%m")), "〔年月〕")
      yield_c( os.date("%m/%Y"), "〔月年〕")
      return true
    end

    if (input == env.prefix .. "ymm") or (input == env.prefix .. "ymr") then
      yield_c( os.date("%Y-%m"), "〔年月〕")
      yield_c( fullshape_number(os.date("%Y")).."－"..fullshape_number(os.date("%m")), "〔年月〕")
      yield_c( os.date("%m-%Y"), "〔月年〕")
      return true
    end

    if (input == env.prefix .. "ymu") or (input == env.prefix .. "ymv") then
      yield_c( os.date("%Y_%m"), "〔年月〕")
      -- yield_c( fullshape_number(os.date("%Y")).."_"..fullshape_number(os.date("%m")), "〔年月〕")
      yield_c( fullshape_number(os.date("%Y")).."＿"..fullshape_number(os.date("%m")), "〔年月〕")
      yield_c( os.date("%m_%Y"), "〔月年〕")
      return true
    end

    if (input == env.prefix .. "ymp") or (input == env.prefix .. "ymq") then
      yield_c( os.date("%Y.%m"), "〔年月〕")
      -- yield_c( fullshape_number(os.date("%Y")).."."..fullshape_number(os.date("%m")), "〔年月〕")
      yield_c( fullshape_number(os.date("%Y")).."．"..fullshape_number(os.date("%m")), "〔年月〕")
      yield_c( os.date("%m.%Y"), "〔月年〕")
      return true
    end

    if (input == env.prefix .. "ymz") then
      yield_c( rqzdx1(12), "〔中數〕")
      yield_c( rqzdx2(12), "〔中數〕")
      return true
    end

-- function week_translator0(input, seg)
    if (input == env.prefix .. "w") then
      yield_c( "星期"..weekstyle()[1], "〔週〕 ~c")
      yield_c( "週"..weekstyle()[1], "〔週〕 ~z")
      yield_c( weekstyle()[5].."曜日", "〔週〕 ~j")
      yield_c( weekstyle()[6], "〔週〕 ~a")
      yield_c( weekstyle()[7], "〔週〕 ~e")
      return true
    end

    if (input == env.prefix .. "wa") then
      yield_c( weekstyle()[6], "〔週〕")
      yield_c( " "..weekstyle()[6].." ", "〔*週*〕")
      return true
    end

    if (input == env.prefix .. "we") then
      yield_c( weekstyle()[7], "〔週〕")
      yield_c( " "..weekstyle()[7].." ", "〔*週*〕")
      yield_c( weekstyle()[8], "〔週〕")
      yield_c( " "..weekstyle()[8].." ", "〔*週*〕")
      return true
    end

    if (input == env.prefix .. "wc") then
      yield_c( "星期"..weekstyle()[1], "〔週〕")
      yield_c( " ".."星期"..weekstyle()[1].." ", "〔*週*〕")
      yield_c( "(".."星期"..weekstyle()[1]..")", "〔週〕")
      yield_c( "（".."星期"..weekstyle()[1].."）", "〔週〕")
      yield_c( " ".."星期"..weekstyle()[2].." ", "〔*週*〕")
      return true
    end

    if (input == env.prefix .. "wz") then
      yield_c( " ".."週"..weekstyle()[1].." ", "〔*週*〕")
      yield_c( "週"..weekstyle()[1], "〔週〕")
      yield_c( "(".."週"..weekstyle()[1]..")", "〔週〕")
      yield_c( "（".."週"..weekstyle()[1].."）", "〔週〕")
      yield_c( " ".."週"..weekstyle()[2].." ", "〔*週*〕")
      return true
    end

    if (input == env.prefix .. "wj") then
      yield_c( " "..weekstyle()[5].."曜日 ", "〔*週*〕")
      yield_c( weekstyle()[5].."曜日", "〔週〕")
      yield_c( "("..weekstyle()[5].."曜日)", "〔週〕")
      yield_c( "（"..weekstyle()[5].."曜日）", "〔週〕")
      yield_c( weekstyle()[3], "〔週〕")
      yield_c( weekstyle()[4], "〔週〕")
      return true
    end

-- function week_translator1(input, seg)
    if (input == env.prefix .. "fw") then
      yield_c( string.gsub(os.date("%Y年%m月%d日"), "([^%d])0", "%1").." ".."星期"..weekstyle()[1].." ", "〔年月日週〕 ~c")
      yield_c( rqzdx1().." ".."星期"..weekstyle()[1].." ", "〔中數〕 ~z")
      -- yield_c( rqzdx2().." ".."星期"..weekstyle()[1].." ", "〔年月日週〕")
      yield_c( string.gsub("民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月"..os.date("%d").."日", "([^%d])0", "%1").." ".."星期"..weekstyle()[1].." ", "〔民國〕 ~h")
      yield_c( "民國"..purech_number(min_guo(os.date("%Y"))).."年"..rqzdx1(23).." ".."星期"..weekstyle()[1].." ", "〔民國中數〕 ~g")
      -- yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." "..weekstyle()[3].." ", "〔年月日週〕 ~j")
      local jpymd, jp_y = jp_ymd(os.date("%Y"),os.date("%m"),os.date("%d"))
      yield_c( string.gsub(jpymd, "([^%d])0", "%1")..weekstyle()[3], "〔日本元号〕 ~j")
      yield_c( weekstyle()[6]..", "..eng1_m_date(os.date("%m")).." "..eng2_d_date(os.date("%d"))..", "..os.date("%Y"), "〔週月日年〕 ~a")
      yield_c( weekstyle()[6]..", "..eng2_d_date(os.date("%d")).." "..eng1_m_date(os.date("%m")).." "..os.date("%Y"), "〔週日月年〕 ~e")
      -- local chinese_date = to_chinese_cal_local(os.time())
      local ll_1, ll_2 = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( ll_1.." "..weekstyle()[5].." ", "〔農曆〕 ~l")
      return true
    end

    if (input == env.prefix .. "fwj") then
      local jpymd, jp_y = jp_ymd(os.date("%Y"),os.date("%m"),os.date("%d"))
      yield_c( string.gsub(jpymd, "([^%d])0", "%1")..weekstyle()[3], "〔日本元号〕")
      yield_c( string.gsub(jpymd, "([^%d])0", "%1").." "..weekstyle()[5].."曜日 ", "〔日本元号〕")
      yield_c( string.gsub(jpymd, "([^%d])0", "%1").."("..weekstyle()[5].."曜日)", "〔日本元号〕")
      yield_c( string.gsub(jpymd, "([^%d])0", "%1").."（"..weekstyle()[5].."曜日）", "〔日本元号〕")
      yield_c( fullshape_number(string.gsub(jpymd, "([^%d])0", "%1")..weekstyle()[3]), "〔日本元号〕")
      yield_c( fullshape_number(string.gsub(jpymd, "([^%d])0", "%1").." "..weekstyle()[5].."曜日 "), "〔日本元号〕")
      yield_c( fullshape_number(string.gsub(jpymd, "([^%d])0", "%1").."("..weekstyle()[5].."曜日)"), "〔日本元号〕")
      yield_c( fullshape_number(string.gsub(jpymd, "([^%d])0", "%1").."（"..weekstyle()[5].."曜日）"), "〔日本元号〕")
      yield_c( jpymd..weekstyle()[3], "〔日本元号〕")
      yield_c( jpymd.." "..weekstyle()[5].."曜日 ", "〔日本元号〕")
      yield_c( jpymd.."("..weekstyle()[5].."曜日)", "〔日本元号〕")
      yield_c( jpymd.."（"..weekstyle()[5].."曜日）", "〔日本元号〕")
      yield_c( fullshape_number(jpymd..weekstyle()[3]), "〔日本元号〕")
      yield_c( fullshape_number(jpymd.." "..weekstyle()[5].."曜日 "), "〔日本元号〕")
      yield_c( fullshape_number(jpymd.."("..weekstyle()[5].."曜日)"), "〔日本元号〕")
      yield_c( fullshape_number(jpymd.."（"..weekstyle()[5].."曜日）"), "〔日本元号〕")
      return true
    end
    -- if (input == env.prefix .. "fwj") then
    --   yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." "..weekstyle()[3].." ", "〔年月日週〕")
    --   -- yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." ".."星期"..weekstyle()[1].." ", "〔年月日週〕")
    --   yield_c( os.date("%Y年%m月%d日").." "..weekstyle()[5].."曜日 ", "〔年月日週〕")
    --   yield_c( os.date("%Y年%m月%d日").."("..weekstyle()[5].."曜日)", "〔年月日週〕")
    --   yield_c( os.date("%Y年%m月%d日").."（"..weekstyle()[5].."曜日）", "〔年月日週〕")
    --   return
    -- end

    if (input == env.prefix .. "fwh") then
      yield_c( string.gsub("民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月"..os.date("%d").."日", "([^%d])0", "%1").." ".."星期"..weekstyle()[1].." ", "〔民國〕")
      yield_c( string.gsub("民國 "..min_guo(os.date("%Y")).." 年 "..os.date("%m").." 月 "..os.date("%d").." 日", "([^%d])0", "%1").." ".."星期"..weekstyle()[1].." ", "〔民國*〕")
      yield_c( "民國"..fullshape_number(min_guo(os.date("%Y"))).."年"..fullshape_number(string.gsub(os.date("%m月%d日"), "0([%d])", "%1")).." ".."星期"..weekstyle()[1].." ", "〔民國〕")
      yield_c( "民國"..min_guo(os.date("%Y")).."年"..os.date("%m").."月"..os.date("%d").."日".." ".."星期"..weekstyle()[1].." ", "〔民國〕")
      yield_c( "民國 "..min_guo(os.date("%Y")).." 年 "..os.date("%m").." 月 "..os.date("%d").." 日".." ".."星期"..weekstyle()[1].." ", "〔民國*〕")
      yield_c( "民國"..fullshape_number(min_guo(os.date("%Y"))).."年"..fullshape_number(os.date("%m")).."月"..fullshape_number(os.date("%d")).."日".." ".."星期"..weekstyle()[1].." ", "〔民國〕")
      return true
    end

    if (input == env.prefix .. "fwg") then
      yield_c( "民國"..purech_number(min_guo(os.date("%Y"))).."年"..rqzdx1(23).." ".."星期"..weekstyle()[1].." ", "〔民國中數〕")
      yield_c( "民國"..read_number(confs[1], min_guo(os.date("%Y"))).."年"..rqzdx1(23).." ".."星期"..weekstyle()[1].." ", "〔民國中數〕")
      yield_c( "民國"..read_number(confs[2], min_guo(os.date("%Y"))).."年"..rqzdx2(23).." ".."星期"..weekstyle()[2].." ", "〔民國中數〕")
      return true
    end

    if (input == env.prefix .. "fwl") then
      -- local chinese_date = to_chinese_cal_local(os.time())
      local ll_1, ll_2 = Date2LunarDate(os.date("%Y%m%d"))
      yield_c( ll_1.." "..weekstyle()[5].." ", "〔農曆〕")
      yield_c( ll_2.." "..weekstyle()[5].." ", "〔農曆〕")
      local All_g, Y_g, M_g, D_g = lunarJzl(os.date("%Y%m%d%H"))
      yield_c( Y_g.."年"..M_g.."月"..D_g.."日".." "..weekstyle()[5].." " , "〔農曆干支〕")
      return true
    end

    if (input == env.prefix .. "fwa") then
      yield_c( weekstyle()[6]..", "..eng1_m_date(os.date("%m")).." "..eng2_d_date(os.date("%d"))..", "..os.date("%Y"), "〔週月日年〕")
      yield_c( weekstyle()[6]..", "..eng1_m_date(os.date("%m")).." "..eng3_d_date(os.date("%d"))..", "..os.date("%Y"), "〔週月日年〕")
      yield_c( weekstyle()[7]..", "..eng2_m_date(os.date("%m")).." "..eng3_d_date(os.date("%d"))..", "..os.date("%Y"), "〔週月日年〕")
      yield_c( weekstyle()[8].." "..eng3_m_date(os.date("%m")).." "..eng4_d_date(os.date("%d")).." "..os.date("%Y"), "〔週月日年〕")
      yield_c( weekstyle()[6]..", "..eng1_m_date(os.date("%m")).." the "..eng1_d_date(os.date("%d"))..", "..os.date("%Y"), "〔週月日年〕")
      return true
    end

    if (input == env.prefix .. "fwe") then
      yield_c( weekstyle()[6]..", "..eng2_d_date(os.date("%d")).." "..eng1_m_date(os.date("%m")).." "..os.date("%Y"), "〔週日月年〕")
      yield_c( weekstyle()[6]..", "..eng3_d_date(os.date("%d")).." "..eng1_m_date(os.date("%m")).." "..os.date("%Y"), "〔週日月年〕")
      yield_c( weekstyle()[7]..", "..eng2_d_date(os.date("%d")).." "..eng2_m_date(os.date("%m")).." "..os.date("%Y"), "〔週日月年〕")
      yield_c( weekstyle()[6]..", ".."the "..eng1_d_date(os.date("%d")).." of "..eng1_m_date(os.date("%m"))..", "..os.date("%Y"), "〔週日月年〕")
      -- yield_c( weekstyle()[6]..", ".."The "..eng1_d_date(os.date("%d")).." of "..eng1_m_date(os.date("%m"))..", "..os.date("%Y"), "〔週日月年〕")
      return true
    end

    if (input == env.prefix .. "fwc") then
      yield_c( string.gsub(os.date("%Y年%m月%d日"), "([^%d])0", "%1").." ".."星期"..weekstyle()[1].." ", "〔年月日週〕")
      yield_c( string.gsub(os.date(" %Y 年 %m 月 %d 日"), "([^%d])0", "%1").." ".."星期"..weekstyle()[1].." ", "〔*年月日週*〕")
      yield_c( fullshape_number(string.gsub(os.date("%Y年%m月%d日"), "([^%d])0", "%1")).." 星期"..weekstyle()[1].." ", "〔年月日週〕")
      yield_c( os.date("%Y年%m月%d日").." ".."星期"..weekstyle()[1].." ", "〔年月日週〕")
      yield_c( os.date(" %Y 年 %m 月 %d 日").." ".."星期"..weekstyle()[1].." ", "〔*年月日週*〕")
      yield_c( fullshape_number(os.date("%Y")).."年"..fullshape_number(os.date("%m")).."月"..fullshape_number(os.date("%d")).."日 ".."星期"..weekstyle()[1].." ", "〔年月日週〕")
      return true
    end

    if (input == env.prefix .. "fwz") then
      yield_c( rqzdx1().." ".."星期"..weekstyle()[1].." ", "〔中數〕")
      yield_c( rqzdx2().." ".."星期"..weekstyle()[2].." ", "〔中數〕")
      return true
    end

-- function week_translator2(input, seg)
    -- if (input == env.prefix .. "fwt") then
    --   yield_c( os.date("%Y年%m月%d日").." ".."星期"..weekstyle()[1].." "..os.date("%H:%M:%S"), "〔年月日週 時:分:秒〕")
    --   yield_c( os.date(" %Y 年 %m 月 %d 日").." ".."星期"..weekstyle()[1].." "..os.date("%H:%M:%S"), "〔*年月日週 時:分:秒〕")
    --   yield_c( fullshape_number(os.date("%Y")).."年"..fullshape_number(os.date("%m")).."月"..fullshape_number(os.date("%d")).."日 ".."星期"..weekstyle()[1].." "..fullshape_number(os.date("%H")).."："..fullshape_number(os.date("%M")).."："..fullshape_number(os.date("%S")), "〔年月日週 時:分:秒〕")
    --   yield_c( os.date("%Y年%m月%d日").." "..weekstyle()[5].."曜日 "..os.date("%H:%M:%S"), "〔年月日週 時:分:秒〕")
    --   -- yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." ".."星期"..weekstyle()[1].." "..os.date("%H")..":"..os.date("%M")..":"..os.date("%S"), "〔年月日週 時:分:秒〕")
    --   yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." "..weekstyle()[3].." "..os.date("%H")..":"..os.date("%M")..":"..os.date("%S"), "〔年月日週 時:分:秒〕")
    --   yield_c( rqzdx1().." ".."星期"..weekstyle()[1].." "..os.date("%H:%M:%S"), "〔年月日週 時:分:秒〕 ~z")
    --   -- yield_c( rqzdx2().." ".."星期"..weekstyle()[1].." "..os.date("%H:%M:%S"), "〔年月日週 時:分:秒〕")
    --   return
    -- end

    -- if (input == env.prefix .. "fwtz") then
    --   yield_c( rqzdx1().." ".."星期"..weekstyle()[1].." "..os.date("%H:%M:%S"), "〔年月日週 時:分:秒〕")
    --   yield_c( rqzdx2().." ".."星期"..weekstyle()[1].." "..os.date("%H:%M:%S"), "〔年月日週 時:分:秒〕")
    --   return
    -- end
-- function week_translator3(input, seg)
    -- if (input == env.prefix .. "fwn") then
    --   yield_c( os.date("%Y年%m月%d日").." ".."星期"..weekstyle()[1].." "..os.date("%H:%M"), "〔年月日週 時:分〕")
    --   yield_c( os.date(" %Y 年 %m 月 %d 日").." ".."星期"..weekstyle()[1].." "..os.date("%H:%M"), "〔*年月日週 時:分〕")
    --   yield_c( fullshape_number(os.date("%Y")).."年"..fullshape_number(os.date("%m")).."月"..fullshape_number(os.date("%d")).."日 ".."星期"..weekstyle()[1].." "..fullshape_number(os.date("%H")).."："..fullshape_number(os.date("%M")), "〔年月日週 時:分〕")
    --   yield_c( os.date("%Y年%m月%d日").." "..weekstyle()[5].."曜日 "..os.date("%H:%M"), "〔年月日週 時:分〕")
    --   -- yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." ".."星期"..weekstyle()[1].." "..os.date("%H")..":"..os.date("%M"), "〔年月日週 時:分〕")
    --   yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." "..weekstyle()[3].." "..os.date("%H")..":"..os.date("%M"), "〔年月日週 時:分〕")
    --   yield_c( rqzdx1().." ".."星期"..weekstyle()[1].." "..os.date("%H:%M"), "〔年月日週 時:分〕 ~z")
    --   -- yield_c( rqzdx2().." ".."星期"..weekstyle()[1].." "..os.date("%H:%M"), "〔年月日週 時:分〕")
    --   return
    -- end

    -- if (input == env.prefix .. "fwnz") then
    --   yield_c( rqzdx1().." ".."星期"..weekstyle()[1].." "..os.date("%H:%M"), "〔年月日週 時:分〕")
    --   yield_c( rqzdx2().." ".."星期"..weekstyle()[1].." "..os.date("%H:%M"), "〔年月日週 時:分〕")
    --   return
    -- end

  return false
end

return { now = now }
