----------------------------------------------------------------------------------------
--- 日期時間各種格式轉寫

local timezone_out = require("f_components/f_timezone_out")
----------------------------------------------------------------------------------------
--- 農曆相關轉換
local lc_1 = require("lunar_calendar/lunar_calendar_1")
-- local GetNextJQ = lc_1.GetNextJQ
local GetNowTimeJq = lc_1.GetNowTimeJq

local lc_2 = require("lunar_calendar/lunar_calendar_2")
local Moonphase_out1 = lc_2.Moonphase_out1
local Moonphase_out2 = lc_2.Moonphase_out2
local jieqi_out1 = lc_2.jieqi_out1

----------------------------------------------------------------------------------------
--- p 程式格式、z 時區、l 月相、s 節氣各分支（原 mf_datetime.lua now() 內容純搬移）

local function now(input, seg, env, ctx)
  local yield_c = ctx.yield_c
    -- lua 程式原生時間
    if (input == env.prefix .. "p") then
      yield_c( os.date(), "〔 os.date() 〕")
      yield_c( os.time(), "〔 os.time()，當前距 1970.1.1.08:00 秒數〕")
      return true
    end

    if (input == env.prefix .. "z") then
      -- local tz, tzd = timezone_out()
      yield_c( timezone_out()[1], "〔世界協調時間〕")
      yield_c( timezone_out()[5], "〔格林威治標準時間〕")
      yield_c( timezone_out()[2], "〔本地時區代號〕")
      return true
    end

    if (input == env.prefix .. "l") then
      -- local Moonshape, Moonangle = Moonphase_out1()
      yield_c( Moonphase_out1()[1], Moonphase_out1()[2])
      -- local p, d = Moonphase_out2()
      yield_c( Moonphase_out2()[1], Moonphase_out2()[2])
      return true
    end

    if (input == env.prefix .. "s") then
      local jq_1, jq_2, jq_3 ,jq_4 = jieqi_out1()
      yield_c( jq_1, jq_2)
      yield_c( jq_3, jq_4)
      local nt_jqs = GetNowTimeJq(os.date("%Y%m%d"))
      -- local n_jqsy = GetNextJQ(os.date("%Y"))  -- 會少最近一期節氣
      for i =1,#nt_jqs do
        yield_c( nt_jqs[i], "〔節氣〕")
      end
      local nt_jqs = nil
      return true
    end

  return false
end

return { now = now }
