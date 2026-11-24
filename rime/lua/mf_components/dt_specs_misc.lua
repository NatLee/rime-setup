----------------------------------------------------------------------------------------
--- 日期時間規格表：p 程式格式、z 時區、l 月相、s 節氣
---（原 mf_datetime_misc.lua 各 yield_c 塊轉為純資料表項，行為不變）
---
--- 每碼為 { text_fn, comment } 陣列；comment 可為閉包（動態註釋）；
--- 候選數量不定的分支（s 節氣）為 function(yield_c) 特例。

local fmt = require("mf_components/core/fmt")

local specs = {}

----------------------------------------------------------------------------------------
--- lua 程式原生時間

specs["p"] = {
  { function() return os.date() end, "〔 os.date() 〕" },
  { function() return os.time() end, "〔 os.time()，當前距 1970.1.1.08:00 秒數〕" },
}

specs["z"] = {
  { function() return fmt.tz()[1] end, "〔世界協調時間〕" },
  { function() return fmt.tz()[5] end, "〔格林威治標準時間〕" },
  { function() return fmt.tz()[2] end, "〔本地時區代號〕" },
}

specs["l"] = {
  { function() return fmt.moon1()[1] end, function() return fmt.moon1()[2] end },
  { function() return fmt.moon2()[1] end, function() return fmt.moon2()[2] end },
}

specs["s"] = function(yield_c)
  local jq_1, jq_2, jq_3, jq_4 = fmt.jieqi_out1()
  yield_c( jq_1, jq_2)
  yield_c( jq_3, jq_4)
  local nt_jqs = fmt.now_jq(os.date("%Y%m%d"))
  -- local n_jqsy = GetNextJQ(os.date("%Y"))  -- 會少最近一期節氣
  for i =1,#nt_jqs do
    yield_c( nt_jqs[i], "〔節氣〕")
  end
end

return specs
