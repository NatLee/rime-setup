----------------------------------------------------------------------------------------
--- 日期時間各種格式轉寫

local f_y_s = require("f_components/f_year_style")
local min_guo = f_y_s.min_guo
local jp_ymd = f_y_s.jp_ymd

local f_d_s = require("f_components/f_date_style")
local ch_y_date = f_d_s.ch_y_date
local ch_m_date = f_d_s.ch_m_date
local ch_d_date = f_d_s.ch_d_date
local chb_y_date = f_d_s.chb_y_date
local chb_m_date = f_d_s.chb_m_date
local chb_d_date = f_d_s.chb_d_date
local jp_m_date = f_d_s.jp_m_date
local jp_d_date = f_d_s.jp_d_date
local eng1_m_date = f_d_s.eng1_m_date
local eng2_m_date = f_d_s.eng2_m_date
local eng3_m_date = f_d_s.eng3_m_date
local eng1_d_date = f_d_s.eng1_d_date
local eng2_d_date = f_d_s.eng2_d_date
local eng3_d_date = f_d_s.eng3_d_date
local eng4_d_date = f_d_s.eng4_d_date
----------------------------------------------------------------------------------------
--- 農曆相關轉換
local lc_1 = require("lunar_calendar/lunar_calendar_1")
local Date2LunarDate = lc_1.Date2LunarDate
local LunarDate2Date = lc_1.LunarDate2Date
local lunarJzl = lc_1.lunarJzl

----------------------------------------------------------------------------------------
--- 數字字母各種格式轉寫

local f_n_s = require("f_components/f_number_style")
local fullshape_number = f_n_s.fullshape_number
local purech_number = f_n_s.purech_number

local f_c_n = require("f_components/f_chinese_number")
local read_number = f_c_n.read_number
local confs = f_c_n.confs

----------------------------------------------------------------------------------------
--- 指定日期 ○y○m○d 各分支（原 mf_datetime.lua custom() 純搬移）

local function custom(input, seg, env, ctx)
  local yield_c = ctx.yield_c
    local y, m, d = string.match(input, env.prefix .. "(%d+)y(%d?%d)m(%d?%d)d?$")
    -- if not y then y, m, d = string.match(input, env.prefix .. "y(%d+)m(%d?%d)d(%d?%d)$") end
    if y and tonumber(m)<13 and tonumber(d)<32 then
      yield_c( y.."年"..m.."月"..d.."日", "〔日期〕")
      yield_c( " "..y.." 年 "..m.." 月 "..d.." 日 ", "〔*日期*〕")
      yield_c( fullshape_number(y).."年"..fullshape_number(m).."月"..fullshape_number(d).."日", "〔全形日期〕")
      yield_c( ch_y_date(y).."年"..ch_m_date(m).."月"..ch_d_date(d).."日", "〔小寫中文日期〕")
      yield_c( chb_y_date(y).."年"..chb_m_date(m).."月"..chb_d_date(d).."日", "〔大寫中文日期〕")
      if (tonumber(y) > 1911) then
        yield_c( "民國"..min_guo(y).."年"..m.."月"..d.."日", "〔民國〕")
        yield_c( "民國"..purech_number(min_guo(y)).."年"..ch_m_date(m).."月"..ch_d_date(d).."日", "〔民國〕")
        yield_c( "民國"..read_number(confs[1], min_guo(y)).."年"..ch_m_date(m).."月"..ch_d_date(d).."日", "〔民國〕")
      elseif (tonumber(y) <= 1911) then
        yield_c( "民國前"..min_guo(y).."年"..m.."月"..d.."日", "〔民國〕")
        yield_c( "民國前"..purech_number(min_guo(y)).."年"..ch_m_date(m).."月"..ch_d_date(d).."日", "〔民國〕")
        yield_c( "民國前"..read_number(confs[1], min_guo(y)).."年"..ch_m_date(m).."月"..ch_d_date(d).."日", "〔民國〕")
      end
      -- yield_c( y.."年 "..jp_m_date(m)..jp_d_date(d), "〔日文日期〕")
      local jpymd2, jp_y2 = jp_ymd(y,m,d)
      yield_c( jp_y2..m.."月"..d.."日" , "〔日本元号〕")
      yield_c( eng1_m_date(m).." "..eng2_d_date(d)..", "..y, "〔美式月日年〕")
      yield_c( eng1_m_date(m).." "..eng3_d_date(d)..", "..y, "〔美式月日年〕")
      yield_c( eng2_m_date(m).." "..eng3_d_date(d)..", "..y, "〔美式月日年〕")
      yield_c( eng3_m_date(m).." "..eng4_d_date(d).." "..y, "〔美式月日年〕")
      yield_c( eng1_m_date(m).." the "..eng1_d_date(d)..", "..y, "〔美式月日年〕")
      yield_c( eng2_d_date(d).." "..eng1_m_date(m).." "..y, "〔英式日月年〕")
      yield_c( eng3_d_date(d).." "..eng1_m_date(m).." "..y, "〔英式日月年〕")
      yield_c( eng2_d_date(d).." "..eng2_m_date(m).." "..y, "〔英式日月年〕")
      yield_c( "the "..eng1_d_date(d).." of "..eng1_m_date(m)..", "..y, "〔英式日月年〕")
      yield_c( "The "..eng1_d_date(d).." of "..eng1_m_date(m)..", "..y, "〔英式日月年〕")
      if tonumber(y) > 1899 and tonumber(y) < 2101 then
        -- local chinese_date_input = to_chinese_cal_local(os.time({year = y, month = m, day = d, hour = 12}))
        local ll_1b, ll_2b = Date2LunarDate(y .. string.format("%02d", m) .. string.format("%02d", d))
        -- if (Date2LunarDate~=nil) then
        if ll_1b~=nil and ll_2b~=nil then
          yield_c( ll_1b, "〔西曆→農曆〕")
          yield_c( ll_2b, "〔西曆→農曆〕")
        end
      end
      if tonumber(y) > 1901 and tonumber(y) < 2101 then
        local All_g2, Y_g2, M_g2, D_g2 = lunarJzl(y .. string.format("%02d", m) .. string.format("%02d", d) .. 12)
        if (All_g2~=nil) then
          yield_c( Y_g2.."年"..M_g2.."月"..D_g2.."日", "〔西曆→農曆干支〕")
        end
        local LDD2D = LunarDate2Date(y .. string.format("%02d", m) .. string.format("%02d", d), 0 )
        local LDD2D_leap_year  = LunarDate2Date(y .. string.format("%02d", m) .. string.format("%02d", d), 1 )
        -- if (Date2LunarDate~=nil) then
        if (LDD2D~=nil) then
          yield_c( LDD2D, "〔農曆→西曆〕")
          yield_c( LDD2D_leap_year, "〔農曆(閏)→西曆〕")
        end
        -- local chinese_date_input2 = to_chinese_cal(y, m, d)
        -- if (chinese_date_input2~=nil) then
        --   yield_c( chinese_date_input2 .. " ", "〔農曆，可能有誤！〕")
        -- end
      end
      return true
    end

    local m, d = string.match(input, env.prefix .. "(%d?%d)m(%d?%d)d?$")
    -- if not m then m, d =  string.match(input, env.prefix .. "m(%d?%d)d(%d?%d)$") end
    if m and tonumber(m)<13 and tonumber(d)<32 then
      yield_c( m.."月"..d.."日" , "〔日期〕")
      yield_c( " "..m.." 月 "..d.." 日 " , "〔*日期*〕")
      yield_c( fullshape_number(m).."月"..fullshape_number(d).."日" , "〔全形日期〕")
      yield_c( ch_m_date(m).."月"..ch_d_date(d).."日" , "〔小寫中文日期〕")
      yield_c( chb_m_date(m).."月"..chb_d_date(d).."日" , "〔大寫中文日期〕")
      yield_c( jp_m_date(m)..jp_d_date(d), "〔日文日期〕")
      yield_c( eng1_m_date(m).." "..eng2_d_date(d), "〔美式月日〕")
      yield_c( eng1_m_date(m).." "..eng3_d_date(d), "〔美式月日〕")
      yield_c( eng2_m_date(m).." "..eng3_d_date(d), "〔美式月日〕")
      yield_c( eng3_m_date(m).." "..eng4_d_date(d), "〔美式月日〕")
      yield_c( eng1_m_date(m).." the "..eng1_d_date(d), "〔美式月日〕")
      yield_c( eng2_d_date(d).." "..eng1_m_date(m), "〔英式日月〕")
      yield_c( eng3_d_date(d).." "..eng1_m_date(m), "〔英式日月〕")
      yield_c( eng2_d_date(d).." "..eng2_m_date(m), "〔英式日月〕")
      yield_c( "the "..eng1_d_date(d).." of "..eng1_m_date(m), "〔英式日月〕")
      yield_c( "The "..eng1_d_date(d).." of "..eng1_m_date(m), "〔英式日月〕")
      return true
    end

    local y, m = string.match(input, env.prefix .. "(%d+)y(%d?%d)m?$")
    -- if not y then y, m = string.match(input, env.prefix .. "y(%d+)m(%d?%d)$") end
    if y and tonumber(m)<13 then
      yield_c( y.."年"..m.."月" , "〔日期〕")
      yield_c( " "..y.." 年 "..m.." 月 " , "〔*日期*〕")
      yield_c( fullshape_number(y).."年"..fullshape_number(m).."月" , "〔全形日期〕")
      yield_c( ch_y_date(y).."年"..ch_m_date(m).."月" , "〔小寫中文日期〕")
      yield_c( chb_y_date(y).."年"..chb_m_date(m).."月" , "〔大寫中文日期〕")
      if (tonumber(y) > 1911) then
        yield_c( "民國"..min_guo(y).."年"..m.."月" , "〔民國〕")
        yield_c( "民國"..purech_number(min_guo(y)).."年"..ch_m_date(m).."月" , "〔民國〕")
        yield_c( "民國"..read_number(confs[1], min_guo(y)).."年"..ch_m_date(m).."月" , "〔民國〕")
      elseif (tonumber(y) <= 1911) then
        yield_c( "民國前"..min_guo(y).."年"..m.."月" , "〔民國〕")
        yield_c( "民國前"..purech_number(min_guo(y)).."年"..ch_m_date(m).."月" , "〔民國〕")
        yield_c( "民國前"..read_number(confs[1], min_guo(y)).."年"..ch_m_date(m).."月" , "〔民國〕")
      end
      -- yield_c( y.."年 "..jp_m_date(m), "〔日文日期〕")
      -- local jpymd2, jp_y2 = jp_ymd(y,m,"1")
      -- yield_c( jp_y2..m.."月" , "〔日本元号〕(沒有日，元号可能有誤)")
      yield_c( eng1_m_date(m)..", "..y, "〔美式/英式月年〕")
      yield_c( eng2_m_date(m)..", "..y, "〔美式月年〕")
      yield_c( eng3_m_date(m).." "..y, "〔美式月年〕")
      yield_c( eng1_m_date(m).." "..y, "〔英式月年〕")
      yield_c( eng2_m_date(m).." "..y, "〔英式月年〕")
      return true
    end

    local y = string.match(input, env.prefix .. "(%d+)y$")
    -- if not y then y = string.match(input, env.prefix .. "y(%d+)$") end
    if y then
      yield_c( y.."年" , "〔日期〕")
      yield_c( " "..y.." 年 " , "〔*日期*〕")
      yield_c( fullshape_number(y).."年" , "〔全形日期〕")
      yield_c( ch_y_date(y).."年" , "〔小寫中文日期〕")
      yield_c( chb_y_date(y).."年" , "〔大寫中文日期〕")
      if (tonumber(y) > 1911) then
        yield_c( "民國"..min_guo(y).."年", "〔民國〕")
        yield_c( "民國"..purech_number(min_guo(y)).."年", "〔民國〕")
        yield_c( "民國"..read_number(confs[1], min_guo(y)).."年", "〔民國〕")
      elseif (tonumber(y) <= 1911) then
        yield_c( "民國前"..min_guo(y).."年", "〔民國〕")
        yield_c( "民國前"..purech_number(min_guo(y)).."年", "〔民國〕")
        yield_c( "民國前"..read_number(confs[1], min_guo(y)).."年", "〔民國〕")
      end
      -- yield_c( y.."年 ", "〔日文日期〕")
      -- local jpymd2, jp_y2 = jp_ymd(y,"1","1")
      -- yield_c( jp_y2 , "〔日本元号〕(沒有月日，元号可能有誤)")
      yield_c( y, "〔美式/英式月年〕")

      return true
    end

    local m = string.match(input, env.prefix .. "(%d?%d)m$")
    -- if not m then m =  string.match(input, env.prefix .. "m(%d?%d)$") end
    if m and tonumber(m)<13 then
      yield_c( m.."月" , "〔日期〕")
      yield_c( " "..m.." 月 " , "〔*日期*〕")
      yield_c( fullshape_number(m).."月" , "〔全形日期〕")
      yield_c( ch_m_date(m).."月" , "〔小寫中文日期〕")
      yield_c( chb_m_date(m).."月" , "〔大寫中文日期〕")
      yield_c( jp_m_date(m), "〔日文日期〕")
      yield_c( eng1_m_date(m), "〔美式/英式月日〕")
      yield_c( eng2_m_date(m), "〔美式/英式月日〕")
      yield_c( eng3_m_date(m), "〔美式月日〕")
      return true
    end

    local d = string.match(input, env.prefix .. "(%d?%d)d$")
    -- if not d then d =  string.match(input, env.prefix .. "d(%d?%d)$") end
    if d and tonumber(d)<32 then
      yield_c( d.."日" , "〔日期〕")
      yield_c( " "..d.." 日 " , "〔*日期*〕")
      yield_c( fullshape_number(d).."日" , "〔全形日期〕")
      yield_c( ch_d_date(d).."日" , "〔小寫中文日期〕")
      yield_c( chb_d_date(d).."日" , "〔大寫中文日期〕")
      yield_c( jp_d_date(d), "〔日文日期〕")
      yield_c( eng2_d_date(d), "〔美式/英式月日〕")
      yield_c( eng3_d_date(d), "〔美式/英式月日〕")
      yield_c( eng4_d_date(d), "〔美式月日〕")
      yield_c( "the "..eng1_d_date(d), "〔美式/英式月日〕")
      yield_c( "The "..eng1_d_date(d), "〔英式日月〕")
      return true
    end
  return false
end

return { custom = custom }
