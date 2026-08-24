--[[
從 lunar_calendar 資料夾匯入兩個農曆相關函數集合
--]]

----------------------------------------------------------------------------------------
--- 日期時間薄調度器（原 mf_datetime.lua 依代碼家族再拆分，行為不變）：
---   mf_datetime_time.lua    t*/n* 時分秒類分支
---   mf_datetime_date.lua    f/y/m/d/w 及其組合（年月日/星期類）分支
---   mf_datetime_misc.lua    p 程式格式、z 時區、s 節氣、l 月相分支
---   mf_datetime_custom.lua  ○y○m○d 指定日期分支（原 custom()）
--- 各分支皆為互斥的 input 完全比對，依原檔內順序調度；
--- 子模組有處理到（原程式碼該處為 return）就回 true。

local mf_dt_time = require("mf_components/mf_datetime_time")
local mf_dt_date = require("mf_components/mf_datetime_date")
local mf_dt_misc = require("mf_components/mf_datetime_misc")
local mf_dt_custom = require("mf_components/mf_datetime_custom")

----------------------------------------------------------------------------------------
--- 即時日期時間各分支（原 translate() 內容純搬移）

local function now(input, seg, env, ctx)
  -- 原檔順序：p → t* → z → n* → l → s → f/y/m/d/w 各組合
  if mf_dt_misc.now(input, seg, env, ctx) then return true end
  if mf_dt_time.now(input, seg, env, ctx) then return true end
  if mf_dt_date.now(input, seg, env, ctx) then return true end
  return false
end

return { now = now, custom = mf_dt_custom.custom }
