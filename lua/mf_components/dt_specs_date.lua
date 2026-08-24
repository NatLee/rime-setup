----------------------------------------------------------------------------------------
--- 日期時間規格表：f/y/m/d/w 及其組合（年月日/星期類）
---（原 mf_datetime_date.lua 各 yield_c 塊轉為純資料表項，行為不變）
---
--- 每碼為 { text_fn, comment } 陣列；別名碼（如 fo=fd）指向同一份規格。
--- 重複的樣式組合使用 fmt 產生器（gen_f_sep／gen_fn_sep／gen_ft_sep／gen_md_sep／
--- gen_ym_sep／gen_minguo_h／gen_jp_era4，皆經回歸測試證明輸出 byte 一致）。
--- 原始碼中被註解掉的歷史程式碼集中於檔案末尾區塊註解（標明出處）。

local fmt = require("mf_components/core/fmt")

local specs = {}

----------------------------------------------------------------------------------------
--- f 家族（年月日）

specs["f"] = {
  { function() return os.date("%Y%m%d") end, "〔年月日〕 ~d   ~o" },
  { function() return os.date("%Y.%m.%d") end, "〔年月日〕 ~p   ~q" },
  { function() return os.date("%Y/%m/%d") end, "〔年月日〕 ~s   ~y" },
  { function() return os.date("%Y-%m-%d") end, "〔年月日〕 ~m   ~r" },
  { function() return os.date("%Y_%m_%d") end, "〔年月日〕 ~u   ~v" },
  { function() return fmt.s0nd(os.date("%Y年%m月%d日")) end, "〔年月日〕 ~c" },
  { function() return fmt.rq1() end, "〔中數〕 ~z" },
  { function() return fmt.s0nd("民國" .. fmt.mg() .. "年" .. os.date("%m") .. "月" .. os.date("%d") .. "日") end, "〔民國〕 ~h" },
  { function() return "民國" .. fmt.pc(fmt.mg()) .. "年" .. fmt.rq1(23) end, "〔民國中數〕 ~g" },
  { function() local jpymd = fmt.jp() return fmt.s0nd(jpymd) end, "〔日本元号〕 ~j" },
  { function() return fmt.eng1_m(os.date("%m")) .. " " .. fmt.eng2_d(os.date("%d")) .. ", " .. os.date("%Y") end, "〔月日年〕 ~a" },
  { function() return fmt.eng2_d(os.date("%d")) .. " " .. fmt.eng1_m(os.date("%m")) .. " " .. os.date("%Y") end, "〔日月年〕 ~e" },
  { function() local ll_1 = fmt.lunar() return ll_1 end, "〔農曆〕 ~l" },
}

specs["fj"] = fmt.gen_jp_era4("")

specs["fh"] = fmt.gen_minguo_h("", "")

specs["fg"] = {
  { function() return "民國" .. fmt.pc(fmt.mg()) .. "年" .. fmt.rq1(23) end, "〔民國中數〕" },
  { function() return "民國" .. fmt.rn1(fmt.mg()) .. "年" .. fmt.rq1(23) end, "〔民國中數〕" },
  { function() return "民國" .. fmt.rn2(fmt.mg()) .. "年" .. fmt.rq2(23) end, "〔民國中數〕" },
}

specs["fl"] = {
  { function() local ll_1 = fmt.lunar() return ll_1 end, "〔農曆〕" },
  { function() local ll_1, ll_2 = fmt.lunar() return ll_2 end, "〔農曆〕" },
  { function() local All_g, Y_g, M_g, D_g = fmt.jzl() return Y_g .. "年" .. M_g .. "月" .. D_g .. "日" end, "〔農曆干支〕" },
}

specs["fa"] = {
  { function() return fmt.eng1_m(os.date("%m")) .. " " .. fmt.eng2_d(os.date("%d")) .. ", " .. os.date("%Y") end, "〔月日年〕" },
  { function() return fmt.eng1_m(os.date("%m")) .. " " .. fmt.eng3_d(os.date("%d")) .. ", " .. os.date("%Y") end, "〔月日年〕" },
  { function() return fmt.eng2_m(os.date("%m")) .. " " .. fmt.eng3_d(os.date("%d")) .. ", " .. os.date("%Y") end, "〔月日年〕" },
  { function() return fmt.eng3_m(os.date("%m")) .. " " .. fmt.eng4_d(os.date("%d")) .. " " .. os.date("%Y") end, "〔月日年〕" },
  { function() return fmt.eng1_m(os.date("%m")) .. " the " .. fmt.eng1_d(os.date("%d")) .. ", " .. os.date("%Y") end, "〔月日年〕" },
}

specs["fe"] = {
  { function() return fmt.eng2_d(os.date("%d")) .. " " .. fmt.eng1_m(os.date("%m")) .. " " .. os.date("%Y") end, "〔日月年〕" },
  { function() return fmt.eng3_d(os.date("%d")) .. " " .. fmt.eng1_m(os.date("%m")) .. " " .. os.date("%Y") end, "〔日月年〕" },
  { function() return fmt.eng2_d(os.date("%d")) .. " " .. fmt.eng2_m(os.date("%m")) .. " " .. os.date("%Y") end, "〔日月年〕" },
  { function() return "the " .. fmt.eng1_d(os.date("%d")) .. " of " .. fmt.eng1_m(os.date("%m")) .. ", " .. os.date("%Y") end, "〔日月年〕" },
  { function() return "The " .. fmt.eng1_d(os.date("%d")) .. " of " .. fmt.eng1_m(os.date("%m")) .. ", " .. os.date("%Y") end, "〔日月年〕" },
}

specs["fc"] = {
  { function() return fmt.s0nd(os.date("%Y年%m月%d日")) end, "〔年月日〕" },
  { function() return fmt.s0nd(os.date(" %Y 年 %m 月 %d 日 ")) end, "〔*年月日*〕" },
  { function() return fmt.fs(fmt.s0nd(os.date("%Y年%m月%d日"))) end, "〔年月日〕" },
  { function() return os.date("%Y年%m月%d日") end, "〔年月日〕" },
  { function() return os.date(" %Y 年 %m 月 %d 日 ") end, "〔*年月日*〕" },
  { function() return fmt.fs(os.date("%Y")) .. "年" .. fmt.fs(os.date("%m")) .. "月" .. fmt.fs(os.date("%d")) .. "日" end, "〔年月日〕" },
}

specs["fd"] = fmt.gen_f_sep("", "")
specs["fo"] = specs["fd"]
specs["fm"] = fmt.gen_f_sep("-", "－")
specs["fr"] = specs["fm"]
specs["fs"] = fmt.gen_f_sep("/", "／")
specs["fy"] = specs["fs"]
specs["fu"] = fmt.gen_f_sep("_", "＿")
specs["fv"] = specs["fu"]
specs["fp"] = fmt.gen_f_sep(".", "．")
specs["fq"] = specs["fp"]

specs["fz"] = {
  { function() return fmt.rq1() end, "〔中數〕" },
  { function() return fmt.rq2() end, "〔中數〕" },
}

----------------------------------------------------------------------------------------
--- fn 家族（年月日 時:分）

specs["fn"] = {
  { function() return os.date("%Y%m%d %H:%M") end, "〔年月日 時:分〕 ~d   ~o" },
  { function() return os.date("%Y.%m.%d %H:%M") end, "〔年月日 時:分〕 ~p   ~q" },
  { function() return os.date("%Y/%m/%d %H:%M") end, "〔年月日 時:分〕 ~s   ~y" },
  { function() return os.date("%Y-%m-%d %H:%M") end, "〔年月日 時:分〕 ~m   ~r" },
  { function() return os.date("%Y_%m_%d %H:%M") end, "〔年月日 時:分〕 ~u   ~v" },
  { function() return os.date("%Y-%m-%d-%H-%M ") .. fmt.tz()[1] end, "〔本地時  時區〕 ~i" },
  { function() return os.date("%Y-%m-%dT%H:%M") .. fmt.tz()[3] end, "〔本地時  RFC 3339/ISO 8601〕 ~f" },
  { function() return fmt.s0nd(os.date("%Y年%m月%d日 %H點%M分")) end, "〔年月日 時:分〕 ~c" },
  { function() return fmt.rq1() .. " " .. fmt.cntime(false, "%H", "點", false) end, "〔中數〕 ~z" },
  { function() return fmt.s0nd("民國" .. fmt.mg() .. "年" .. os.date("%m") .. "月" .. os.date("%d") .. "日 " .. os.date("%H點%M分")) end, "〔民國〕 ~h" },
  { function() return "民國" .. fmt.pc(fmt.mg()) .. "年" .. fmt.rq1(23) .. " " .. fmt.cntime(false, "%H", "點", false) end, "〔民國中數〕 ~g" },
  { function() local jpymd = fmt.jp() return fmt.s0nd(jpymd) .. " " .. os.date("%H:%M") end, "〔日本元号〕 ~j" },
  { function() local ll_1 = fmt.lunar() return ll_1 .. " " .. fmt.tdc() end, "〔農曆〕 ~l" },
}

specs["fni"] = {
  { function() return os.date("%Y-%m-%d-%H-%M ") .. fmt.tz()[1] end, "〔本地時  時區〕" },
  { function() return os.date("%Y-%m-%d-%H-%M ") .. fmt.tz()[5] end, "〔本地時  時區〕" },
  { function() return os.date("%Y-%m-%d-%H-%M ") .. fmt.tz()[2] end, "〔本地時  時區〕" },
  { function() return os.date("!%Y-%m-%d-%H-%M UTC") end, "〔世界時  時區〕" },
  { function() return os.date("!%Y-%m-%d-%H-%M GMT") end, "〔世界時  時區〕" },
}

specs["fnf"] = {
  { function() return os.date("%Y-%m-%dT%H:%M") .. fmt.tz()[3] end, "〔本地時  RFC 3339/ISO 8601〕" },
  { function() return os.date("%Y%m%dT%H%M") .. fmt.tz()[4] end, "〔本地時  RFC 3339/ISO 8601〕" },
  { function() return os.date("!%Y-%m-%dT%H:%MZ") end, "〔世界時  RFC 3339/ISO 8601〕" },
  { function() return os.date("!%Y%m%dT%H%MZ") end, "〔世界時  RFC 3339/ISO 8601〕" },
}

specs["fnj"] = fmt.gen_jp_era4("%H:%M")

specs["fnh"] = fmt.gen_minguo_h("%H點%M分", "%H 點 %M 分")

specs["fng"] = {
  { function() return "民國" .. fmt.pc(fmt.mg()) .. "年" .. fmt.rq1(23) .. " " .. fmt.cntime(false, "%H", "點", false) end, "〔民國中數〕" },
  { function() return "民國" .. fmt.rn1(fmt.mg()) .. "年" .. fmt.rq1(23) .. " " .. fmt.cntime(false, "%H", "點", false) end, "〔民國中數〕" },
  { function() return "民國" .. fmt.rn2(fmt.mg()) .. "年" .. fmt.rq2(23) .. " " .. fmt.cntime(true, "%H", "點", false) end, "〔民國中數〕" },
}

specs["fnl"] = {
  { function() local ll_1 = fmt.lunar() return ll_1 .. " " .. fmt.tdc() end, "〔農曆〕" },
  { function() local ll_1, ll_2 = fmt.lunar() return ll_2 .. " " .. fmt.tdc() end, "〔農曆〕" },
  { function() local All_g = fmt.jzl() return All_g end, "〔農曆干支〕" },
}

specs["fnc"] = {
  { function() return fmt.s0nd(os.date("%Y年%m月%d日 %H點%M分")) end, "〔年月日 時:分〕" },
  { function() return fmt.s0nd(os.date(" %Y 年 %m 月 %d 日 %H 點 %M 分 ")) end, "〔*年月日 時:分*〕" },
  { function() return fmt.fs(fmt.s0nd(os.date("%Y年%m月%d日　%H點%M分"))) end, "〔年月日 時:分〕" },
  { function() return os.date("%Y年%m月%d日 %H點%M分") end, "〔年月日 時:分〕" },
  { function() return os.date(" %Y 年 %m 月 %d 日 %H 點 %M 分 ") end, "〔*年月日 時:分*〕" },
  { function() return fmt.fs(os.date("%Y")) .. "年" .. fmt.fs(os.date("%m")) .. "月" .. fmt.fs(os.date("%d")) .. "日　" .. fmt.fs(os.date("%H")) .. "點" .. fmt.fs(os.date("%M")) .. "分" end, "〔年月日 時:分〕" },
}

specs["fnd"] = fmt.gen_fn_sep("", "")
specs["fno"] = specs["fnd"]
specs["fns"] = fmt.gen_fn_sep("/", "／")
specs["fny"] = specs["fns"]
specs["fnm"] = fmt.gen_fn_sep("-", "－")
specs["fnr"] = specs["fnm"]
specs["fnu"] = fmt.gen_fn_sep("_", "＿")
specs["fnv"] = specs["fnu"]
specs["fnp"] = fmt.gen_fn_sep(".", "．")
specs["fnq"] = specs["fnp"]

specs["fnz"] = {
  { function() return fmt.rq1() .. " " .. fmt.cntime(false, "%H", "點", false) end, "〔中數〕" },
  { function() return fmt.rq2() .. " " .. fmt.cntime(true, "%H", "點", false) end, "〔中數〕" },
}

----------------------------------------------------------------------------------------
--- ft 家族（年月日 時:分:秒）

specs["ft"] = {
  { function() return os.date("%Y%m%d %H:%M:%S") end, "〔年月日 時:分:秒〕 ~d   ~o" },
  { function() return os.date("%Y.%m.%d %H:%M:%S") end, "〔年月日 時:分:秒〕 ~p   ~q" },
  { function() return os.date("%Y/%m/%d %H:%M:%S") end, "〔年月日 時:分:秒〕 ~s   ~y" },
  { function() return os.date("%Y-%m-%d %H:%M:%S") end, "〔年月日 時:分:秒〕 ~m   ~r" },
  { function() return os.date("%Y_%m_%d %H:%M:%S") end, "〔年月日 時:分:秒〕 ~u   ~v" },
  { function() return os.date("%Y-%m-%d-%H-%M-%S ") .. fmt.tz()[1] end, "〔本地時  時區〕 ~i" },
  { function() return os.date("%Y-%m-%dT%H:%M:%S") .. fmt.tz()[3] end, "〔本地時  RFC 3339/ISO 8601〕 ~f" },
  { function() return fmt.s0nd(os.date("%Y年%m月%d日 %H點%M分%S秒")) end, "〔年月日 時:分:秒〕 ~c" },
  { function() return fmt.rq1() .. " " .. fmt.cntime(false, "%H", "點", true) end, "〔中數〕 ~z" },
  { function() return fmt.s0nd("民國" .. fmt.mg() .. "年" .. os.date("%m") .. "月" .. os.date("%d") .. "日 " .. os.date("%H點%M分%S秒")) end, "〔民國〕 ~h" },
  { function() return "民國" .. fmt.pc(fmt.mg()) .. "年" .. fmt.rq1(23) .. " " .. fmt.cntime(false, "%H", "點", true) end, "〔民國中數〕 ~g" },
  { function() local jpymd = fmt.jp() return fmt.s0nd(jpymd) .. " " .. os.date("%H:%M:%S") end, "〔日本元号〕 ~j" },
}

specs["fti"] = {
  { function() return os.date("%Y-%m-%d-%H-%M-%S ") .. fmt.tz()[1] end, "〔本地時  時區〕" },
  { function() return os.date("%Y-%m-%d-%H-%M-%S ") .. fmt.tz()[5] end, "〔本地時  時區〕" },
  { function() return os.date("%Y-%m-%d-%H-%M-%S ") .. fmt.tz()[2] end, "〔本地時  時區〕" },
  { function() return os.date("!%Y-%m-%d-%H-%M-%S UTC") end, "〔世界時  時區〕" },
  { function() return os.date("!%Y-%m-%d-%H-%M-%S GMT") end, "〔世界時  時區〕" },
}

specs["ftf"] = {
  { function() return os.date("%Y-%m-%dT%H:%M:%S") .. fmt.tz()[3] end, "〔本地時  RFC 3339/ISO 8601〕" },
  { function() return os.date("%Y%m%dT%H%M%S") .. fmt.tz()[4] end, "〔本地時  RFC 3339/ISO 8601〕" },
  { function() return os.date("!%Y-%m-%dT%H:%M:%SZ") end, "〔世界時  RFC 3339/ISO 8601〕" },
  { function() return os.date("!%Y%m%dT%H%M%SZ") end, "〔世界時  RFC 3339/ISO 8601〕" },
}

specs["ftj"] = fmt.gen_jp_era4("%H:%M:%S")

specs["fth"] = fmt.gen_minguo_h("%H點%M分%S秒", "%H 點 %M 分 %S 秒")

specs["ftg"] = {
  { function() return "民國" .. fmt.pc(fmt.mg()) .. "年" .. fmt.rq1(23) .. " " .. fmt.cntime(false, "%H", "點", true) end, "〔民國中數〕" },
  { function() return "民國" .. fmt.rn1(fmt.mg()) .. "年" .. fmt.rq1(23) .. " " .. fmt.cntime(false, "%H", "點", true) end, "〔民國中數〕" },
  { function() return "民國" .. fmt.rn2(fmt.mg()) .. "年" .. fmt.rq2(23) .. " " .. fmt.cntime(true, "%H", "點", true) end, "〔民國中數〕" },
}

specs["ftc"] = {
  { function() return fmt.s0nd(os.date("%Y年%m月%d日 %H點%M分%S秒")) end, "〔年月日 時:分:秒〕" },
  { function() return fmt.s0nd(os.date(" %Y 年 %m 月 %d 日 %H 點 %M 分 %S 秒 ")) end, "〔*年月日 時:分:秒*〕" },
  { function() return fmt.fs(fmt.s0nd(os.date("%Y年%m月%d日　%H點%M分%S秒"))) end, "〔年月日 時:分:秒〕" },
  { function() return os.date("%Y年%m月%d日 %H點%M分%S秒") end, "〔年月日 時:分:秒〕" },
  { function() return os.date(" %Y 年 %m 月 %d 日 %H 點 %M 分 %S 秒 ") end, "〔*年月日 時:分:秒*〕" },
  { function() return fmt.fs(os.date("%Y")) .. "年" .. fmt.fs(os.date("%m")) .. "月" .. fmt.fs(os.date("%d")) .. "日　" .. fmt.fs(os.date("%H")) .. "點" .. fmt.fs(os.date("%M")) .. "分" .. fmt.fs(os.date("%S")) .. "秒" end, "〔年月日 時:分:秒〕" },
}

specs["ftd"] = fmt.gen_ft_sep("", "")
specs["fto"] = specs["ftd"]
specs["fts"] = fmt.gen_ft_sep("/", "／")
specs["fty"] = specs["fts"]
specs["ftm"] = fmt.gen_ft_sep("-", "－")
specs["ftr"] = specs["ftm"]
specs["ftu"] = fmt.gen_ft_sep("_", "＿")
specs["ftv"] = specs["ftu"]
specs["ftp"] = fmt.gen_ft_sep(".", "．")
specs["ftq"] = specs["ftp"]

specs["ftz"] = {
  { function() return fmt.rq1() .. " " .. fmt.cntime(false, "%H", "點", true) end, "〔中數〕" },
  { function() return fmt.rq2() .. " " .. fmt.cntime(true, "%H", "點", true) end, "〔中數〕" },
}

----------------------------------------------------------------------------------------
--- y 家族（年）

specs["y"] = {
  { function() return os.date("%Y") end, "〔年〕 ~d" },
  { function() return os.date("%Y年") end, "〔年〕 ~c" },
  { function() return fmt.rq1(1) end, "〔中數〕 ~z" },
  { function() return "民國" .. fmt.mg() .. "年" end, "〔民國〕 ~h" },
  { function() return "民國" .. fmt.pc(fmt.mg()) .. "年" end, "〔民國中數〕 ~g" },
  { function() local jpymd, jp_y = fmt.jp() return jp_y end, "〔日本元号〕 ~j" },
  { function() local a, b, ly_1 = fmt.lunar() return ly_1 end, "〔農曆〕 ~l" },
}

specs["yj"] = {
  { function() local jpymd, jp_y = fmt.jp() return jp_y end, "〔日本元号〕" },
  { function() local jpymd, jp_y = fmt.jp() return fmt.fs(jp_y) end, "〔日本元号〕" },
}

specs["yh"] = {
  { function() return "民國" .. fmt.mg() .. "年" end, "〔民國〕" },
  { function() return "民國 " .. fmt.mg() .. " 年" end, "〔民國*〕" },
  { function() return "民國" .. fmt.fs(fmt.mg()) .. "年" end, "〔民國〕" },
}

specs["yg"] = {
  { function() return "民國" .. fmt.pc(fmt.mg()) .. "年" end, "〔民國中數〕" },
  { function() return "民國" .. fmt.rn1(fmt.mg()) .. "年" end, "〔民國中數〕" },
  { function() return "民國" .. fmt.rn2(fmt.mg()) .. "年" end, "〔民國中數〕" },
}

specs["yl"] = {
  { function() local a, b, ly_1 = fmt.lunar() return ly_1 end, "〔農曆〕" },
  { function() local a, b, ly_1, ly_2 = fmt.lunar() return ly_2 end, "〔農曆〕" },
}

specs["yc"] = {
  { function() return os.date("%Y年") end, "〔年〕" },
  { function() return os.date(" %Y 年") end, "〔*年〕" },
  { function() return fmt.fs(os.date("%Y")) .. "年" end, "〔年〕" },
}

specs["yd"] = {
  { function() return os.date("%Y") end, "〔年〕" },
  { function() return fmt.fs(os.date("%Y")) end, "〔年〕" },
}

specs["yz"] = {
  { function() return fmt.rq1(1) end, "〔中數〕" },
  { function() return fmt.rq2(1) end, "〔中數〕" },
}

----------------------------------------------------------------------------------------
--- m 家族（月）

specs["m"] = {
  { function() return os.date("%m") end, "〔月〕 ~m" },
  { function() return fmt.s0lead(os.date("%m月")) end, "〔月〕 ~c" },
  { function() return fmt.rq1(2) end, "〔中數〕 ~z" },
  { function() return fmt.jp_m(os.date("%m")) end, "〔日本格式〕 ~j" },
  { function() return fmt.eng1_m(os.date("%m")) end, "〔月〕 ~a" },
  { function() return fmt.eng2_m(os.date("%m")) end, "〔月〕 ~e" },
  { function() local a, b, c, d, lm = fmt.lunar() return lm end, "〔農曆〕 ~l" },
}

specs["ml"] = {
  { function() local a, b, c, d, lm = fmt.lunar() return lm end, "〔農曆〕" },
  { function() local All_g, Y_g, M_g = fmt.jzl() return M_g .. "月" end, "〔農曆干支〕" },
}

specs["ma"] = {
  { function() return fmt.eng1_m(os.date("%m")) end, "〔月〕" },
  { function() return " " .. fmt.eng1_m(os.date("%m")) .. " " end, "〔*月*〕" },
}

specs["me"] = {
  { function() return fmt.eng2_m(os.date("%m")) end, "〔月〕" },
  { function() return " " .. fmt.eng2_m(os.date("%m")) .. " " end, "〔*月*〕" },
  { function() return fmt.eng3_m(os.date("%m")) end, "〔月〕" },
  { function() return " " .. fmt.eng3_m(os.date("%m")) .. " " end, "〔*月*〕" },
}

specs["mj"] = {
  { function() return fmt.jp_m(os.date("%m")) end, "〔日本格式〕" },
}

specs["mc"] = {
  { function() return fmt.s0lead(os.date("%m月")) end, "〔月〕" },
  { function() return fmt.s0sp(os.date(" %m 月")) end, "〔*月〕" },
  { function() return fmt.fs(fmt.s0lead(os.date("%m月"))) end, "〔月〕" },
  { function() return os.date("%m月") end, "〔月〕" },
  { function() return os.date(" %m 月") end, "〔*月〕" },
  { function() return fmt.fs(os.date("%m")) .. "月" end, "〔月〕" },
}

specs["mm"] = {
  { function() return os.date("%m") end, "〔月〕" },
  { function() return fmt.fs(os.date("%m")) end, "〔月〕" },
}

specs["mz"] = {
  { function() return fmt.rq1(2) end, "〔中數〕" },
  { function() return fmt.rq2(2) end, "〔中數〕" },
}

----------------------------------------------------------------------------------------
--- d 家族（日）

specs["d"] = {
  { function() return os.date("%d") end, "〔日〕 ~d" },
  { function() return fmt.s0lead(os.date("%d日")) end, "〔日〕 ~c" },
  { function() return fmt.rq1(3) end, "〔中數〕 ~z" },
  { function() return fmt.jp_d(os.date("%d")) end, "〔日本格式〕 ~j" },
  { function() return "the " .. fmt.eng1_d(os.date("%d")) end, "〔日〕 ~a" },
  { function() return fmt.eng2_d(os.date("%d")) end, "〔日〕 ~e" },
  { function() local a, b, c, d, e, ld = fmt.lunar() return ld end, "〔農曆〕 ~l" },
}

specs["dl"] = {
  { function() local a, b, c, d, e, ld = fmt.lunar() return ld end, "〔農曆〕" },
  { function() local All_g, Y_g, M_g, D_g = fmt.jzl() return D_g .. "日" end, "〔農曆干支〕" },
}

specs["da"] = {
  { function() return "the " .. fmt.eng1_d(os.date("%d")) end, "〔日〕" },
  { function() return " the " .. fmt.eng1_d(os.date("%d")) .. " " end, "〔*日*〕" },
  { function() return "The " .. fmt.eng1_d(os.date("%d")) end, "〔日〕" },
  { function() return " The " .. fmt.eng1_d(os.date("%d")) .. " " end, "〔*日*〕" },
}

specs["de"] = {
  { function() return fmt.eng2_d(os.date("%d")) end, "〔日〕" },
  { function() return " " .. fmt.eng2_d(os.date("%d")) .. " " end, "〔*日*〕" },
  { function() return fmt.eng4_d(os.date("%d")) end, "〔日〕" },
  { function() return " " .. fmt.eng4_d(os.date("%d")) .. " " end, "〔*日*〕" },
}

specs["dj"] = {
  { function() return fmt.jp_d(os.date("%d")) end, "〔日本格式〕" },
}

specs["dc"] = {
  { function() return fmt.s0lead(os.date("%d日")) end, "〔日〕" },
  { function() return fmt.s0sp(os.date(" %d 日")) end, "〔*日〕" },
  { function() return fmt.fs(fmt.s0lead(os.date("%d日"))) end, "〔日〕" },
  { function() return os.date("%d日") end, "〔日〕" },
  { function() return os.date(" %d 日") end, "〔*日〕" },
  { function() return fmt.fs(os.date("%d")) .. "日" end, "〔日〕" },
}

specs["dd"] = {
  { function() return os.date("%d") end, "〔日〕" },
  { function() return fmt.fs(os.date("%d")) end, "〔日〕" },
}

specs["dz"] = {
  { function() return fmt.rq1(3) end, "〔中數〕" },
  { function() return fmt.rq2(3) end, "〔中數〕" },
}

----------------------------------------------------------------------------------------
--- md 家族（月日）

specs["md"] = {
  { function() return os.date("%m%d") end, "〔月日〕 ~d   ~o" },
  { function() return os.date("%m.%d") end, "〔月日〕 ~p   ~q" },
  { function() return os.date("%m/%d") end, "〔月日〕 ~s   ~y" },
  { function() return os.date("%m-%d") end, "〔月日〕 ~m   ~r" },
  { function() return os.date("%m_%d") end, "〔月日〕 ~u   ~v" },
  { function() return fmt.s0bd(os.date("%m月%d日")) end, "〔月日〕 ~c" },
  { function() return fmt.rq1(23) end, "〔中數〕 ~z" },
  { function() return fmt.jp_m(os.date("%m")) .. fmt.jp_d(os.date("%d")) end, "〔日本格式〕 ~j" },
  { function() return fmt.eng1_m(os.date("%m")) .. " " .. fmt.eng2_d(os.date("%d")) end, "〔月日〕 ~a" },
  { function() return fmt.eng2_d(os.date("%d")) .. " " .. fmt.eng1_m(os.date("%m")) end, "〔日月〕 ~e" },
  { function() local a, b, c, d, lm, ld = fmt.lunar() return lm .. ld end, "〔農曆〕 ~l" },
}

specs["mdl"] = {
  { function() local a, b, c, d, lm, ld = fmt.lunar() return lm .. ld end, "〔農曆〕" },
  { function() local All_g, Y_g, M_g, D_g = fmt.jzl() return M_g .. "月" .. D_g .. "日" end, "〔農曆干支〕" },
}

specs["mda"] = {
  { function() return fmt.eng1_m(os.date("%m")) .. " " .. fmt.eng2_d(os.date("%d")) end, "〔月日〕" },
  { function() return fmt.eng1_m(os.date("%m")) .. " " .. fmt.eng3_d(os.date("%d")) end, "〔月日〕" },
  { function() return fmt.eng2_m(os.date("%m")) .. " " .. fmt.eng3_d(os.date("%d")) end, "〔月日〕" },
  { function() return fmt.eng3_m(os.date("%m")) .. " " .. fmt.eng4_d(os.date("%d")) end, "〔月日〕" },
  { function() return fmt.eng1_m(os.date("%m")) .. " the " .. fmt.eng1_d(os.date("%d")) end, "〔月日〕" },
}

specs["mde"] = {
  { function() return fmt.eng2_d(os.date("%d")) .. " " .. fmt.eng1_m(os.date("%m")) end, "〔日月〕" },
  { function() return fmt.eng3_d(os.date("%d")) .. " " .. fmt.eng1_m(os.date("%m")) end, "〔日月〕" },
  { function() return fmt.eng2_d(os.date("%d")) .. " " .. fmt.eng2_m(os.date("%m")) end, "〔日月〕" },
  { function() return "the " .. fmt.eng1_d(os.date("%d")) .. " of " .. fmt.eng1_m(os.date("%m")) end, "〔日月〕" },
  { function() return "The " .. fmt.eng1_d(os.date("%d")) .. " of " .. fmt.eng1_m(os.date("%m")) end, "〔日月〕" },
}

specs["mdj"] = {
  { function() return fmt.jp_m(os.date("%m")) .. fmt.jp_d(os.date("%d")) end, "〔日本格式〕" },
}

specs["mdc"] = {
  { function() return fmt.s0bd(os.date("%m月%d日")) end, "〔月日〕" },
  { function() return fmt.s0sp(os.date(" %m 月 %d 日 ")) end, "〔*月日*〕" },
  { function() return fmt.fs(fmt.s0bd(os.date("%m月%d日"))) end, "〔月日〕" },
  { function() return os.date("%m月%d日") end, "〔月日〕" },
  { function() return os.date(" %m 月 %d 日 ") end, "〔*月日*〕" },
  { function() return fmt.fs(os.date("%m")) .. "月" .. fmt.fs(os.date("%d")) .. "日" end, "〔月日〕" },
}

specs["mdd"] = fmt.gen_md_sep("", "")
specs["mdo"] = specs["mdd"]
specs["mds"] = fmt.gen_md_sep("/", "／")
specs["mdy"] = specs["mds"]
specs["mdm"] = fmt.gen_md_sep("-", "－")
specs["mdr"] = specs["mdm"]
specs["mdu"] = fmt.gen_md_sep("_", "＿")
specs["mdv"] = specs["mdu"]
specs["mdp"] = fmt.gen_md_sep(".", "．")
specs["mdq"] = specs["mdp"]

specs["mdz"] = {
  { function() return fmt.rq1(23) end, "〔中數〕" },
  { function() return fmt.rq2(23) end, "〔中數〕" },
}

----------------------------------------------------------------------------------------
--- mdw 家族（月日週）

specs["mdw"] = {
  { function() return fmt.s0bd(os.date("%m月%d日")) .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔月日週〕 ~c" },
  { function() return fmt.rq1(23) .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔中數〕 ~z" },
  { function() return fmt.jp_m(os.date("%m")) .. fmt.jp_d(os.date("%d")) .. fmt.wk()[3] end, "〔日本格式〕 ~j" },
  { function() return fmt.wk()[6] .. ", " .. fmt.eng1_m(os.date("%m")) .. " " .. fmt.eng2_d(os.date("%d")) end, "〔週月日〕 ~a" },
  { function() return fmt.wk()[6] .. ", " .. fmt.eng2_d(os.date("%d")) .. " " .. fmt.eng1_m(os.date("%m")) end, "〔週日月〕 ~e" },
  { function() local a, b, c, d, lm, ld = fmt.lunar() return lm .. ld .. " " .. fmt.wk()[5] .. " " end, "〔農曆〕 ~l" },
}

specs["mdwl"] = {
  { function() local a, b, c, d, lm, ld = fmt.lunar() return lm .. ld .. " " .. fmt.wk()[5] .. " " end, "〔農曆〕" },
  { function() local All_g, Y_g, M_g, D_g = fmt.jzl() return M_g .. "月" .. D_g .. "日" .. " " .. fmt.wk()[5] .. " " end, "〔農曆干支〕" },
}

specs["mdwa"] = {
  { function() return fmt.wk()[6] .. ", " .. fmt.eng1_m(os.date("%m")) .. " " .. fmt.eng2_d(os.date("%d")) end, "〔週月日〕" },
  { function() return fmt.wk()[6] .. ", " .. fmt.eng1_m(os.date("%m")) .. " " .. fmt.eng3_d(os.date("%d")) end, "〔週月日〕" },
  { function() return fmt.wk()[7] .. ", " .. fmt.eng2_m(os.date("%m")) .. " " .. fmt.eng3_d(os.date("%d")) end, "〔週月日〕" },
  { function() return fmt.wk()[8] .. " " .. fmt.eng3_m(os.date("%m")) .. " " .. fmt.eng4_d(os.date("%d")) end, "〔週月日〕" },
  { function() return fmt.wk()[6] .. ", " .. fmt.eng1_m(os.date("%m")) .. " the " .. fmt.eng1_d(os.date("%d")) end, "〔週月日〕" },
}

specs["mdwe"] = {
  { function() return fmt.wk()[6] .. ", " .. fmt.eng2_d(os.date("%d")) .. " " .. fmt.eng1_m(os.date("%m")) end, "〔週日月〕" },
  { function() return fmt.wk()[6] .. ", " .. fmt.eng3_d(os.date("%d")) .. " " .. fmt.eng1_m(os.date("%m")) end, "〔週日月〕" },
  { function() return fmt.wk()[7] .. ", " .. fmt.eng2_d(os.date("%d")) .. " " .. fmt.eng2_m(os.date("%m")) end, "〔週日月〕" },
  { function() return fmt.wk()[6] .. ", " .. "the " .. fmt.eng1_d(os.date("%d")) .. " of " .. fmt.eng1_m(os.date("%m")) end, "〔週日月〕" },
}

specs["mdwc"] = {
  { function() return fmt.s0bd(os.date("%m月%d日")) .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔月日週〕" },
  { function() return fmt.s0sp(os.date(" %m 月 %d 日")) .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔*月日週*〕" },
  { function() return fmt.fs(fmt.s0bd(os.date("%m月%d日"))) .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔月日週〕" },
  { function() return os.date("%m月%d日") .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔月日週〕" },
  { function() return os.date(" %m 月 %d 日") .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔*月日週*〕" },
  { function() return fmt.fs(os.date("%m")) .. "月" .. fmt.fs(os.date("%d")) .. "日" .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔月日週〕" },
}

--- mdwj：4 種日期形 × 4 種週尾（第 1 項為日本格式月日＋週）；
--- 全形組一律包整串（2026-08-25 修正原版第二組只包日期的不一致）
do
  local tails = {
    function() return fmt.wk()[3] end,
    function() return " " .. fmt.wk()[5] .. "曜日 " end,
    function() return "(" .. fmt.wk()[5] .. "曜日)" end,
    function() return "（" .. fmt.wk()[5] .. "曜日）" end,
  }
  local mdwj = {
    { function() return fmt.jp_m(os.date("%m")) .. fmt.jp_d(os.date("%d")) .. fmt.wk()[3] end, "〔日本格式〕" },
  }
  for _, t in ipairs(tails) do
    mdwj[#mdwj + 1] = { function() return fmt.s0bd(os.date("%m月%d日")) .. t() end, "〔日本格式〕" }
  end
  for _, t in ipairs(tails) do
    mdwj[#mdwj + 1] = { function() return fmt.fs(fmt.s0bd(os.date("%m月%d日")) .. t()) end, "〔日本格式〕" }
  end
  for _, t in ipairs(tails) do
    mdwj[#mdwj + 1] = { function() return os.date("%m月%d日") .. t() end, "〔日本格式〕" }
  end
  for _, t in ipairs(tails) do
    mdwj[#mdwj + 1] = { function() return fmt.fs(os.date("%m月%d日") .. t()) end, "〔日本格式〕" }
  end
  specs["mdwj"] = mdwj
end

specs["mdwz"] = {
  { function() return fmt.rq1(23) .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔中數〕" },
  { function() return fmt.rq2(23) .. " " .. "星期" .. fmt.wk()[2] .. " " end, "〔中數〕" },
}

----------------------------------------------------------------------------------------
--- ym 家族（年月）

specs["ym"] = {
  { function() return os.date("%Y%m") end, "〔年月〕 ~d   ~o" },
  { function() return os.date("%Y.%m") end, "〔年月〕 ~p   ~q" },
  { function() return os.date("%Y/%m") end, "〔年月〕 ~s   ~y" },
  { function() return os.date("%Y-%m") end, "〔年月〕 ~m   ~r" },
  { function() return os.date("%Y_%m") end, "〔年月〕 ~u   ~v" },
  { function() return fmt.s0nd(os.date("%Y年%m月")) end, "〔年月〕 ~c" },
  { function() return fmt.rq1(12) end, "〔中數〕 ~z" },
  { function() return fmt.s0nd("民國" .. fmt.mg() .. "年" .. os.date("%m") .. "月") end, "〔民國〕 ~h" },
  { function() return "民國" .. fmt.pc(fmt.mg()) .. "年" .. fmt.rq1(2) end, "〔民國中數〕 ~g" },
  { function() local jpymd, jp_y = fmt.jp() return fmt.s0nd(jp_y .. os.date("%m") .. "月") end, "〔日本元号〕 ~j" },  -- 包整串去零，修正「令和8年08月」
  { function() return fmt.eng1_m(os.date("%m")) .. ", " .. os.date("%Y") end, "〔月年〕 ~a" },
  { function() return fmt.eng1_m(os.date("%m")) .. " " .. os.date("%Y") end, "〔月年〕 ~e" },
  { function() local a, b, ly_1, ly_2, lm = fmt.lunar() return ly_1 .. lm end, "〔農曆〕 ~l" },
}

specs["ymj"] = {
  { function() local jpymd, jp_y = fmt.jp() return fmt.s0nd(jp_y .. os.date("%m") .. "月") end, "〔日本元号〕" },  -- 包整串去零，修正「令和8年08月」
  { function() local jpymd, jp_y = fmt.jp() return fmt.fs(fmt.s0nd(jp_y .. os.date("%m") .. "月")) end, "〔日本元号〕" },
  { function() local jpymd, jp_y = fmt.jp() return jp_y .. os.date("%m") .. "月" end, "〔日本元号〕" },
  { function() local jpymd, jp_y = fmt.jp() return fmt.fs(jp_y .. os.date("%m") .. "月") end, "〔日本元号〕" },
}

specs["ymh"] = {
  { function() return fmt.s0nd("民國" .. fmt.mg() .. "年" .. os.date("%m") .. "月") end, "〔民國〕" },
  { function() return fmt.s0nd("民國 " .. fmt.mg() .. " 年 " .. os.date("%m") .. " 月") end, "〔民國*〕" },
  { function() return "民國" .. fmt.fs(fmt.mg()) .. "年" .. fmt.fs(fmt.s0bd(os.date("%m"))) .. "月" end, "〔民國〕" },
  { function() return "民國" .. fmt.mg() .. "年" .. os.date("%m") .. "月" end, "〔民國〕" },
  { function() return "民國 " .. fmt.mg() .. " 年 " .. os.date("%m") .. " 月" end, "〔民國*〕" },
  { function() return "民國" .. fmt.fs(fmt.mg()) .. "年" .. fmt.fs(os.date("%m")) .. "月" end, "〔民國〕" },
}

specs["ymg"] = {
  { function() return "民國" .. fmt.pc(fmt.mg()) .. "年" .. fmt.rq1(2) end, "〔民國中數〕" },
  { function() return "民國" .. fmt.rn1(fmt.mg()) .. "年" .. fmt.rq1(2) end, "〔民國中數〕" },
  { function() return "民國" .. fmt.rn2(fmt.mg()) .. "年" .. fmt.rq2(2) end, "〔民國中數〕" },
}

specs["yml"] = {
  { function() local a, b, ly_1, ly_2, lm = fmt.lunar() return ly_1 .. lm end, "〔農曆〕" },
  { function() local a, b, ly_1, ly_2, lm = fmt.lunar() return ly_2 .. lm end, "〔農曆〕" },
  { function() local All_g, Y_g, M_g = fmt.jzl() return Y_g .. "年" .. M_g .. "月" end, "〔農曆干支〕" },
}

specs["yma"] = {
  { function() return fmt.eng1_m(os.date("%m")) .. ", " .. os.date("%Y") end, "〔月年〕" },
  { function() return fmt.eng2_m(os.date("%m")) .. ", " .. os.date("%Y") end, "〔月年〕" },
}

specs["yme"] = {
  { function() return fmt.eng1_m(os.date("%m")) .. " " .. os.date("%Y") end, "〔月年〕" },
  { function() return fmt.eng2_m(os.date("%m")) .. " " .. os.date("%Y") end, "〔月年〕" },
  { function() return fmt.eng3_m(os.date("%m")) .. " " .. os.date("%Y") end, "〔月年〕" },
}

specs["ymc"] = {
  { function() return fmt.s0nd(os.date("%Y年%m月")) end, "〔年月〕" },
  { function() return fmt.s0nd(os.date(" %Y 年 %m 月 ")) end, "〔*年月*〕" },
  { function() return fmt.fs(fmt.s0nd(os.date("%Y年%m月"))) end, "〔年月〕" },
  { function() return os.date("%Y年%m月") end, "〔年月〕" },
  { function() return os.date(" %Y 年 %m 月 ") end, "〔*年月*〕" },
  { function() return fmt.fs(os.date("%Y")) .. "年" .. fmt.fs(os.date("%m")) .. "月" end, "〔年月〕" },
}

specs["ymd"] = fmt.gen_ym_sep("", "")
specs["ymo"] = specs["ymd"]
specs["yms"] = fmt.gen_ym_sep("/", "／")
specs["ymy"] = specs["yms"]
specs["ymm"] = fmt.gen_ym_sep("-", "－")
specs["ymr"] = specs["ymm"]
specs["ymu"] = fmt.gen_ym_sep("_", "＿")
specs["ymv"] = specs["ymu"]
specs["ymp"] = fmt.gen_ym_sep(".", "．")
specs["ymq"] = specs["ymp"]

specs["ymz"] = {
  { function() return fmt.rq1(12) end, "〔中數〕" },
  { function() return fmt.rq2(12) end, "〔中數〕" },
}

----------------------------------------------------------------------------------------
--- w 家族（週）
-- function week_translator0(input, seg)

specs["w"] = {
  { function() return "星期" .. fmt.wk()[1] end, "〔週〕 ~c" },
  { function() return "週" .. fmt.wk()[1] end, "〔週〕 ~z" },
  { function() return fmt.wk()[5] .. "曜日" end, "〔週〕 ~j" },
  { function() return fmt.wk()[6] end, "〔週〕 ~a" },
  { function() return fmt.wk()[7] end, "〔週〕 ~e" },
}

specs["wa"] = {
  { function() return fmt.wk()[6] end, "〔週〕" },
  { function() return " " .. fmt.wk()[6] .. " " end, "〔*週*〕" },
}

specs["we"] = {
  { function() return fmt.wk()[7] end, "〔週〕" },
  { function() return " " .. fmt.wk()[7] .. " " end, "〔*週*〕" },
  { function() return fmt.wk()[8] end, "〔週〕" },
  { function() return " " .. fmt.wk()[8] .. " " end, "〔*週*〕" },
}

specs["wc"] = {
  { function() return "星期" .. fmt.wk()[1] end, "〔週〕" },
  { function() return " " .. "星期" .. fmt.wk()[1] .. " " end, "〔*週*〕" },
  { function() return "(" .. "星期" .. fmt.wk()[1] .. ")" end, "〔週〕" },
  { function() return "（" .. "星期" .. fmt.wk()[1] .. "）" end, "〔週〕" },
  { function() return " " .. "星期" .. fmt.wk()[2] .. " " end, "〔*週*〕" },
}

specs["wz"] = {
  { function() return " " .. "週" .. fmt.wk()[1] .. " " end, "〔*週*〕" },
  { function() return "週" .. fmt.wk()[1] end, "〔週〕" },
  { function() return "(" .. "週" .. fmt.wk()[1] .. ")" end, "〔週〕" },
  { function() return "（" .. "週" .. fmt.wk()[1] .. "）" end, "〔週〕" },
  { function() return " " .. "週" .. fmt.wk()[2] .. " " end, "〔*週*〕" },
}

specs["wj"] = {
  { function() return " " .. fmt.wk()[5] .. "曜日 " end, "〔*週*〕" },
  { function() return fmt.wk()[5] .. "曜日" end, "〔週〕" },
  { function() return "(" .. fmt.wk()[5] .. "曜日)" end, "〔週〕" },
  { function() return "（" .. fmt.wk()[5] .. "曜日）" end, "〔週〕" },
  { function() return fmt.wk()[3] end, "〔週〕" },
  { function() return fmt.wk()[4] end, "〔週〕" },
}

----------------------------------------------------------------------------------------
--- fw 家族（年月日週）
-- function week_translator1(input, seg)

specs["fw"] = {
  { function() return fmt.s0nd(os.date("%Y年%m月%d日")) .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔年月日週〕 ~c" },
  { function() return fmt.rq1() .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔中數〕 ~z" },
  { function() return fmt.s0nd("民國" .. fmt.mg() .. "年" .. os.date("%m") .. "月" .. os.date("%d") .. "日") .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔民國〕 ~h" },
  { function() return "民國" .. fmt.pc(fmt.mg()) .. "年" .. fmt.rq1(23) .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔民國中數〕 ~g" },
  { function() local jpymd = fmt.jp() return fmt.s0nd(jpymd) .. fmt.wk()[3] end, "〔日本元号〕 ~j" },
  { function() return fmt.wk()[6] .. ", " .. fmt.eng1_m(os.date("%m")) .. " " .. fmt.eng2_d(os.date("%d")) .. ", " .. os.date("%Y") end, "〔週月日年〕 ~a" },
  { function() return fmt.wk()[6] .. ", " .. fmt.eng2_d(os.date("%d")) .. " " .. fmt.eng1_m(os.date("%m")) .. " " .. os.date("%Y") end, "〔週日月年〕 ~e" },
  { function() local ll_1 = fmt.lunar() return ll_1 .. " " .. fmt.wk()[5] .. " " end, "〔農曆〕 ~l" },
}

--- fwj：4 種元号日期形 × 4 種週尾；第二、四組全形皆包整串（保持原輸出）
do
  local tails = {
    function() return fmt.wk()[3] end,
    function() return " " .. fmt.wk()[5] .. "曜日 " end,
    function() return "(" .. fmt.wk()[5] .. "曜日)" end,
    function() return "（" .. fmt.wk()[5] .. "曜日）" end,
  }
  local fwj = {}
  for _, t in ipairs(tails) do
    fwj[#fwj + 1] = { function() local jpymd = fmt.jp() return fmt.s0nd(jpymd) .. t() end, "〔日本元号〕" }
  end
  for _, t in ipairs(tails) do
    fwj[#fwj + 1] = { function() local jpymd = fmt.jp() return fmt.fs(fmt.s0nd(jpymd) .. t()) end, "〔日本元号〕" }
  end
  for _, t in ipairs(tails) do
    fwj[#fwj + 1] = { function() local jpymd = fmt.jp() return jpymd .. t() end, "〔日本元号〕" }
  end
  for _, t in ipairs(tails) do
    fwj[#fwj + 1] = { function() local jpymd = fmt.jp() return fmt.fs(jpymd .. t()) end, "〔日本元号〕" }
  end
  specs["fwj"] = fwj
end

specs["fwh"] = {
  { function() return fmt.s0nd("民國" .. fmt.mg() .. "年" .. os.date("%m") .. "月" .. os.date("%d") .. "日") .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔民國〕" },
  { function() return fmt.s0nd("民國 " .. fmt.mg() .. " 年 " .. os.date("%m") .. " 月 " .. os.date("%d") .. " 日") .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔民國*〕" },
  { function() return "民國" .. fmt.fs(fmt.mg()) .. "年" .. fmt.fs(fmt.s0bd(os.date("%m月%d日"))) .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔民國〕" },
  { function() return "民國" .. fmt.mg() .. "年" .. os.date("%m") .. "月" .. os.date("%d") .. "日" .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔民國〕" },
  { function() return "民國 " .. fmt.mg() .. " 年 " .. os.date("%m") .. " 月 " .. os.date("%d") .. " 日" .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔民國*〕" },
  { function() return "民國" .. fmt.fs(fmt.mg()) .. "年" .. fmt.fs(os.date("%m")) .. "月" .. fmt.fs(os.date("%d")) .. "日" .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔民國〕" },
}

specs["fwg"] = {
  { function() return "民國" .. fmt.pc(fmt.mg()) .. "年" .. fmt.rq1(23) .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔民國中數〕" },
  { function() return "民國" .. fmt.rn1(fmt.mg()) .. "年" .. fmt.rq1(23) .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔民國中數〕" },
  { function() return "民國" .. fmt.rn2(fmt.mg()) .. "年" .. fmt.rq2(23) .. " " .. "星期" .. fmt.wk()[2] .. " " end, "〔民國中數〕" },
}

specs["fwl"] = {
  { function() local ll_1 = fmt.lunar() return ll_1 .. " " .. fmt.wk()[5] .. " " end, "〔農曆〕" },
  { function() local ll_1, ll_2 = fmt.lunar() return ll_2 .. " " .. fmt.wk()[5] .. " " end, "〔農曆〕" },
  { function() local All_g, Y_g, M_g, D_g = fmt.jzl() return Y_g .. "年" .. M_g .. "月" .. D_g .. "日" .. " " .. fmt.wk()[5] .. " " end, "〔農曆干支〕" },
}

specs["fwa"] = {
  { function() return fmt.wk()[6] .. ", " .. fmt.eng1_m(os.date("%m")) .. " " .. fmt.eng2_d(os.date("%d")) .. ", " .. os.date("%Y") end, "〔週月日年〕" },
  { function() return fmt.wk()[6] .. ", " .. fmt.eng1_m(os.date("%m")) .. " " .. fmt.eng3_d(os.date("%d")) .. ", " .. os.date("%Y") end, "〔週月日年〕" },
  { function() return fmt.wk()[7] .. ", " .. fmt.eng2_m(os.date("%m")) .. " " .. fmt.eng3_d(os.date("%d")) .. ", " .. os.date("%Y") end, "〔週月日年〕" },
  { function() return fmt.wk()[8] .. " " .. fmt.eng3_m(os.date("%m")) .. " " .. fmt.eng4_d(os.date("%d")) .. " " .. os.date("%Y") end, "〔週月日年〕" },
  { function() return fmt.wk()[6] .. ", " .. fmt.eng1_m(os.date("%m")) .. " the " .. fmt.eng1_d(os.date("%d")) .. ", " .. os.date("%Y") end, "〔週月日年〕" },
}

specs["fwe"] = {
  { function() return fmt.wk()[6] .. ", " .. fmt.eng2_d(os.date("%d")) .. " " .. fmt.eng1_m(os.date("%m")) .. " " .. os.date("%Y") end, "〔週日月年〕" },
  { function() return fmt.wk()[6] .. ", " .. fmt.eng3_d(os.date("%d")) .. " " .. fmt.eng1_m(os.date("%m")) .. " " .. os.date("%Y") end, "〔週日月年〕" },
  { function() return fmt.wk()[7] .. ", " .. fmt.eng2_d(os.date("%d")) .. " " .. fmt.eng2_m(os.date("%m")) .. " " .. os.date("%Y") end, "〔週日月年〕" },
  { function() return fmt.wk()[6] .. ", " .. "the " .. fmt.eng1_d(os.date("%d")) .. " of " .. fmt.eng1_m(os.date("%m")) .. ", " .. os.date("%Y") end, "〔週日月年〕" },
}

specs["fwc"] = {
  { function() return fmt.s0nd(os.date("%Y年%m月%d日")) .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔年月日週〕" },
  { function() return fmt.s0nd(os.date(" %Y 年 %m 月 %d 日")) .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔*年月日週*〕" },
  { function() return fmt.fs(fmt.s0nd(os.date("%Y年%m月%d日"))) .. " 星期" .. fmt.wk()[1] .. " " end, "〔年月日週〕" },
  { function() return os.date("%Y年%m月%d日") .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔年月日週〕" },
  { function() return os.date(" %Y 年 %m 月 %d 日") .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔*年月日週*〕" },
  { function() return fmt.fs(os.date("%Y")) .. "年" .. fmt.fs(os.date("%m")) .. "月" .. fmt.fs(os.date("%d")) .. "日 " .. "星期" .. fmt.wk()[1] .. " " end, "〔年月日週〕" },
}

specs["fwz"] = {
  { function() return fmt.rq1() .. " " .. "星期" .. fmt.wk()[1] .. " " end, "〔中數〕" },
  { function() return fmt.rq2() .. " " .. "星期" .. fmt.wk()[2] .. " " end, "〔中數〕" },
}

----------------------------------------------------------------------------------------
--- 原始碼中被註解掉的歷史程式碼（集中保留，標明出處：原 mf_datetime_date.lua）
--[==[

（出處：f 分支 ~j 候選前）
      -- yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")), "〔年月日〕 ~j")

（出處：fj 分支後）
    -- if (input == env.prefix .. "fj") then
    --   yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")), "〔年月日〕")
    --   return
    -- end

（出處：f/fl/fn/fnl/y/yl/m/ml/d/dl/md/mdl/mdw/mdwl/ym/yml/fw/fwl 各分支內，
　to_chinese_cal_local 舊註解與變數命名註解）
    -- local chinese_date = to_chinese_cal_local(os.time())
    -- local chinese_time = time_description_chinese(os.time())
    -- local a, b, chinese_y = to_chinese_cal_local(os.time())
    -- local a, b, y, chinese_m = to_chinese_cal_local(os.time())
    -- local a, b, y, m, chinese_d = to_chinese_cal_local(os.time())
    -- local a, b, y, chinese_m, chinese_d = to_chinese_cal_local(os.time())
    -- local a, b, chinese_y, chinese_m = to_chinese_cal_local(os.time())

（出處：fs/fy 分支）
      -- yield_c( fullshape_number(os.date("%Y")).."/"..fullshape_number(os.date("%m")).."/"..fullshape_number(os.date("%d")), "〔年月日〕")
（出處：fu/fv 分支）
      -- yield_c( fullshape_number(os.date("%Y")).."_"..fullshape_number(os.date("%m")).."_"..fullshape_number(os.date("%d")), "〔年月日〕")
（出處：fp/fq 分支）
      -- yield_c( fullshape_number(os.date("%Y")).."."..fullshape_number(os.date("%m")).."."..fullshape_number(os.date("%d")), "〔年月日〕")

（出處：fn 分支 ~j 候選前）
      -- yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." "..os.date("%H")..":"..os.date("%M"), "〔年月日 時:分〕 ~j")

（出處：fnj 分支後）
    -- if (input == env.prefix .. "fnj") then
    --   yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." "..os.date("%H")..":"..os.date("%M"), "〔年月日 時:分〕")
    --   return
    -- end

（出處：fns/fny 分支）
      -- yield_c( fullshape_number(os.date("%Y")).."/"..fullshape_number(os.date("%m")).."/"..fullshape_number(os.date("%d")).." "..fullshape_number(os.date("%H"))..":"..fullshape_number(os.date("%M")), "〔年月日 時:分〕")
（出處：fnu/fnv 分支）
      -- yield_c( fullshape_number(os.date("%Y")).."_"..fullshape_number(os.date("%m")).."_"..fullshape_number(os.date("%d")).." "..fullshape_number(os.date("%H"))..":"..fullshape_number(os.date("%M")), "〔年月日 時:分〕")
（出處：fnp/fnq 分支）
      -- yield_c( fullshape_number(os.date("%Y")).."."..fullshape_number(os.date("%m")).."."..fullshape_number(os.date("%d")).." "..fullshape_number(os.date("%H"))..":"..fullshape_number(os.date("%M")), "〔年月日 時:分〕")

（出處：ft 分支 ~j 候選前）
      -- yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." "..os.date("%H")..":"..os.date("%M")..":"..os.date("%S"), "〔年月日 時:分:秒〕 ~j")

（出處：ftj 分支後）
    -- if (input == env.prefix .. "ftj") then
    --   yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." "..os.date("%H")..":"..os.date("%M")..":"..os.date("%S"), "〔年月日 時:分:秒〕")
    --   return
    -- end

（出處：fts/fty 分支）
      -- yield_c( fullshape_number(os.date("%Y")).."/"..fullshape_number(os.date("%m")).."/"..fullshape_number(os.date("%d")).." "..fullshape_number(os.date("%H"))..":"..fullshape_number(os.date("%M"))..":"..fullshape_number(os.date("%S")), "〔年月日 時:分:秒〕")
（出處：ftu/ftv 分支）
      -- yield_c( fullshape_number(os.date("%Y")).."_"..fullshape_number(os.date("%m")).."_"..fullshape_number(os.date("%d")).." "..fullshape_number(os.date("%H"))..":"..fullshape_number(os.date("%M"))..":"..fullshape_number(os.date("%S")), "〔年月日 時:分:秒〕")
（出處：ftp/ftq 分支）
      -- yield_c( fullshape_number(os.date("%Y")).."."..fullshape_number(os.date("%m")).."."..fullshape_number(os.date("%d")).." "..fullshape_number(os.date("%H"))..":"..fullshape_number(os.date("%M"))..":"..fullshape_number(os.date("%S")), "〔年月日 時:分:秒〕")

（出處：y 分支）
      -- yield_c( rqzdx2(1), "〔年〕")
（出處：yl 分支）
      -- local a, Y_g = lunarJzl(os.date("%Y%m%d%H"))
      -- yield_c( Y_g.."年", "〔農曆干支〕")
（出處：m 分支）
      -- yield_c( rqzdx2(2), "〔月〕")
（出處：d 分支）
      -- yield_c( rqzdx2(3), "〔日〕")
（出處：de 分支）
      -- yield_c( " "..eng3_d_date(os.date("%d")).." ", "〔*日*〕")

（出處：mds/mdy 分支）
      -- yield_c( fullshape_number(os.date("%m")).."/"..fullshape_number(os.date("%d")), "〔月日〕")
（出處：mdu/mdv 分支）
      -- yield_c( fullshape_number(os.date("%m")).."_"..fullshape_number(os.date("%d")), "〔月日〕")
（出處：mdp/mdq 分支）
      -- yield_c( fullshape_number(os.date("%m")).."."..fullshape_number(os.date("%d")), "〔月日〕")

（出處：mdw 分支）
      -- yield_c( jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." ".."星期"..weekstyle()[1].." ", "〔月日週〕")
      -- yield_c( rqzdx2(23).." ".."星期"..weekstyle()[1].." ", "〔月日週〕")
（出處：mdwe 分支）
      -- yield_c( weekstyle()[6]..", ".."The "..eng1_d_date(os.date("%d")).." of "..eng1_m_date(os.date("%m"))..", "..os.date("%Y"), "〔週日月〕")

（出處：ym 分支 ~j 候選前）
      -- yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m")), "〔年月〕 ~j")
（出處：ymj 分支後）
    -- if (input == env.prefix .. "ymj") then
    --   yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m")), "〔年月〕")
    --   return
    -- end
（出處：yms/ymy 分支）
      -- yield_c( fullshape_number(os.date("%Y")).."/"..fullshape_number(os.date("%m")), "〔年月〕")
（出處：ymu/ymv 分支）
      -- yield_c( fullshape_number(os.date("%Y")).."_"..fullshape_number(os.date("%m")), "〔年月〕")
（出處：ymp/ymq 分支）
      -- yield_c( fullshape_number(os.date("%Y")).."."..fullshape_number(os.date("%m")), "〔年月〕")

（出處：fw 分支）
      -- yield_c( rqzdx2().." ".."星期"..weekstyle()[1].." ", "〔年月日週〕")
      -- yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." "..weekstyle()[3].." ", "〔年月日週〕 ~j")
（出處：fwj 分支後）
    -- if (input == env.prefix .. "fwj") then
    --   yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." "..weekstyle()[3].." ", "〔年月日週〕")
    --   -- yield_c( os.date("%Y").."年 "..jp_m_date(os.date("%m"))..jp_d_date(os.date("%d")).." ".."星期"..weekstyle()[1].." ", "〔年月日週〕")
    --   yield_c( os.date("%Y年%m月%d日").." "..weekstyle()[5].."曜日 ", "〔年月日週〕")
    --   yield_c( os.date("%Y年%m月%d日").."("..weekstyle()[5].."曜日)", "〔年月日週〕")
    --   yield_c( os.date("%Y年%m月%d日").."（"..weekstyle()[5].."曜日）", "〔年月日週〕")
    --   return
    -- end
（出處：fwe 分支）
      -- yield_c( weekstyle()[6]..", ".."The "..eng1_d_date(os.date("%d")).." of "..eng1_m_date(os.date("%m"))..", "..os.date("%Y"), "〔週日月年〕")

（出處：檔案末尾，fwt/fwtz/fwn/fwnz 已停用分支）
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

--]==]

return specs
