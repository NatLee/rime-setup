----------------------------------------------------------------------------------------
--- 日期時間規格表：t*（時:分:秒）與 n*（時:分）
---（原 mf_datetime_time.lua 各 yield_c 塊轉為純資料表項，行為不變）
---
--- 每碼為 { text_fn, comment } 陣列。重複的樣式組合使用 fmt 產生器
---（gen_oct／gen_cn4／gen_ampm_cn4，皆經回歸測試證明輸出 byte 一致）。

local fmt = require("mf_components/core/fmt")

local specs = {}

----------------------------------------------------------------------------------------
--- t 家族（時:分:秒）

specs["t"] = {
  -- yield_c( os.date("%H:%M"), "〔時:分〕 ~m")
  -- yield_c( os.date("%H:%M:%S"), "〔時:分:秒〕 ~d")
  { function() return fmt.s0lead(os.date("%H:%M:%S")) end, "〔時:分:秒〕 ~d" },
  { function() return fmt.t1()[6] end, "〔時:分:秒〕 ~m" },
  { function() return fmt.s0bd(os.date("%H時%M分%S秒")) end, "〔時:分:秒〕 ~c" },
  { function() return fmt.s0spd(fmt.t2()[7]) end, "〔時:分:秒〕 ~s" },
  { function() return fmt.s0bd(fmt.t2()[3]) end, "〔時:分:秒〕 ~w" },
  { function() return fmt.cntime(false, "%H", "時", true) end, "〔時:分:秒〕 ~z" },
  { function() return fmt.t2()[5] .. " " .. fmt.cntime(false, "%I", "時", true) end, "〔時:分:秒〕 ~u" },
}

specs["ts"] = {
  { function() return fmt.s0spd(fmt.t2()[7]) end, "〔時:分:秒〕" },
  { function() return fmt.t2()[5] .. " " .. fmt.fs(fmt.s0lead(os.date("%I"))) .. "：" .. fmt.fs(os.date("%M")) .. "：" .. fmt.fs(os.date("%S")) end, "〔時:分:秒〕" },
  { function() return fmt.t2()[7] end, "〔時:分:秒〕" },
  { function() return fmt.t2()[5] .. " " .. fmt.fs(os.date("%I")) .. "：" .. fmt.fs(os.date("%M")) .. "：" .. fmt.fs(os.date("%S")) end, "〔時:分:秒〕" },
}

specs["tw"] = fmt.gen_oct(function() return fmt.t2()[3] end, function() return fmt.t2()[4] end, "〔時:分:秒〕")

specs["tu"] = fmt.gen_ampm_cn4(true, "〔時:分:秒〕")

specs["td"] = {
  { function() return fmt.s0lead(os.date("%H:%M:%S")) end, "〔時:分:秒〕" },
  { function() return fmt.fs(fmt.s0lead(os.date("%H"))) .. "：" .. fmt.fs(os.date("%M")) .. "：" .. fmt.fs(os.date("%S")) end, "〔時:分:秒〕" },
  { function() return os.date("%H:%M:%S") end, "〔時:分:秒〕" },
  { function() return fmt.fs(os.date("%H")) .. "：" .. fmt.fs(os.date("%M")) .. "：" .. fmt.fs(os.date("%S")) end, "〔時:分:秒〕" },
}

specs["tm"] = {
  { function() return fmt.t1()[6] end, "〔時:分:秒〕" },
  { function() return fmt.t1()[8] end, "〔時:分:秒〕" },
  { function() return fmt.t1()[7] end, "〔時:分:秒〕" },
  { function() return fmt.t1()[5] end, "〔時:分:秒〕" },
  { function() return fmt.t1()[14] end, "〔時:分:秒〕" },
  { function() return fmt.t1()[16] end, "〔時:分:秒〕" },
  { function() return fmt.t1()[15] end, "〔時:分:秒〕" },
  { function() return fmt.t1()[13] end, "〔時:分:秒〕" },
}

specs["tc"] = fmt.gen_oct(function() return os.date("%H時%M分%S秒") end, function() return os.date("%H點%M分%S秒") end, "〔時:分:秒〕")

specs["tz"] = fmt.gen_cn4(true, "〔時:分:秒〕")

-- if (input == env.prefix .. "tm") then
--   yield_c( os.date("%H:%M"), "〔時:分〕")
--   return
-- end

----------------------------------------------------------------------------------------
--- n 家族（時:分）

specs["n"] = {
  -- yield_c( os.date("%H:%M:%S"), "〔時:分:秒〕 ~s")
  -- yield_c( os.date("%H:%M"), "〔時:分〕 ~d")
  { function() return fmt.s0lead(os.date("%H:%M")) end, "〔時:分〕 ~d" },
  { function() return fmt.t1()[2] end, "〔時:分〕 ~m" },
  { function() return fmt.s0bd(os.date("%H時%M分")) end, "〔時:分〕 ~c" },
  { function() return fmt.s0spd(fmt.t2()[6]) end, "〔時:分〕 ~s" },
  { function() return fmt.s0bd(fmt.t2()[1]) end, "〔時:分〕 ~w" },
  { function() return fmt.cntime(false, "%H", "時", false) end, "〔時:分〕 ~z" },
  { function() return fmt.t2()[5] .. " " .. fmt.cntime(false, "%I", "時", false) end, "〔時:分〕 ~u" },
  { function() return fmt.tdc() end, "〔農曆〕 ~l" },
}

specs["ns"] = {
  { function() return fmt.s0spd(fmt.t2()[6]) end, "〔時:分〕" },
  { function() return fmt.t2()[5] .. " " .. fmt.fs(fmt.s0lead(os.date("%I"))) .. "：" .. fmt.fs(os.date("%M")) end, "〔時:分〕" },
  { function() return fmt.t2()[6] end, "〔時:分〕" },
  { function() return fmt.t2()[5] .. " " .. fmt.fs(os.date("%I")) .. "：" .. fmt.fs(os.date("%M")) end, "〔時:分〕" },
}

specs["nw"] = fmt.gen_oct(function() return fmt.t2()[1] end, function() return fmt.t2()[2] end, "〔時:分〕")

specs["nu"] = fmt.gen_ampm_cn4(false, "〔時:分〕")

specs["nd"] = {
  { function() return fmt.s0lead(os.date("%H:%M")) end, "〔時:分〕" },
  { function() return fmt.fs(fmt.s0lead(os.date("%H"))) .. "：" .. fmt.fs(os.date("%M")) end, "〔時:分〕" },
  { function() return os.date("%H:%M") end, "〔時:分〕" },
  { function() return fmt.fs(os.date("%H")) .. "：" .. fmt.fs(os.date("%M")) end, "〔時:分〕" },
}

specs["nm"] = {
  { function() return fmt.t1()[2] end, "〔時:分〕" },
  { function() return fmt.t1()[4] end, "〔時:分〕" },
  { function() return fmt.t1()[3] end, "〔時:分〕" },
  { function() return fmt.t1()[1] end, "〔時:分〕" },
  { function() return fmt.t1()[10] end, "〔時:分〕" },
  { function() return fmt.t1()[12] end, "〔時:分〕" },
  { function() return fmt.t1()[11] end, "〔時:分〕" },
  { function() return fmt.t1()[9] end, "〔時:分〕" },
}

specs["nc"] = fmt.gen_oct(function() return os.date("%H時%M分") end, function() return os.date("%H點%M分") end, "〔時:分〕")

specs["nz"] = fmt.gen_cn4(false, "〔時:分〕")

specs["nl"] = {
  { function() return fmt.tdc() end, "〔農曆〕" },
  { function() local All_g, Y_g, M_g, D_g, H_g = fmt.jzl() return H_g .. "時" end, "〔農曆干支〕" },
  { function() return fmt.sichen(os.date("%H")) end, "〔農曆時辰〕" },
}

-- if (input == env.prefix .. "ns") then
--   yield_c( os.date("%H:%M:%S"), "〔時:分:秒〕")
--   return
-- end

return specs
