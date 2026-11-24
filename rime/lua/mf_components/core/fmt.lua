----------------------------------------------------------------------------------------
--- 格式化原語庫（core/fmt）
---
--- 1) 將 f_components / lunar_calendar 常用函數集中再匯出，規格表（dt_specs_*）只需
---    require 本檔即可取得全部格式化原語。
--- 2) per-dispatch 記憶化：registry.dispatch() 每次按鍵會先呼叫 fmt.reset()；
---    同一次調度內 time_out1()/time_out2()/timezone_out()/weekstyle()/農曆轉換等
---    來源只計算一次（原始碼每個候選重複呼叫，輸出不變、效能改善）。
--- 3) 提供重複樣式組合的規格產生器（gen_*），僅在回歸測試證明輸出 byte 一致的
---    家族使用。

local f_t_s = require("f_components/f_time_style")
local f_y_s = require("f_components/f_year_style")
local f_d_s = require("f_components/f_date_style")
local f_c_d_s = require("f_components/f_chinese_date_style")
local weekstyle = require("f_components/f_week_style")
local timezone_out = require("f_components/f_timezone_out")
local f_n_s = require("f_components/f_number_style")
local f_c_n = require("f_components/f_chinese_number")
local lc_1 = require("lunar_calendar/lunar_calendar_1")
local lc_2 = require("lunar_calendar/lunar_calendar_2")
local GetLunarSichen = require("lunar_calendar/lunar_time")

local M = {}

----------------------------------------------------------------------------------------
--- per-dispatch 記憶化

local cache = {}

--- 每次 dispatch（按鍵）開始時清空快取
function M.reset()
  cache = {}
end

local function memo(key, fn)
  return function()
    local v = cache[key]
    if v == nil then
      v = fn()
      cache[key] = v
    end
    return v
  end
end

--- 回傳 table 的來源（原始碼即以 [n] 索引取用）
M.t1 = memo("t1", f_t_s.time_out1)          -- am/pm 時刻樣式表（時:分 與 時:分:秒）
M.t2 = memo("t2", f_t_s.time_out2)          -- 上午/下午 時刻樣式表
M.tz = memo("tz", timezone_out)             -- 時區樣式表
M.wk = memo("wk", weekstyle)                -- 星期樣式表
M.moon1 = memo("moon1", lc_2.Moonphase_out1) -- 月相（形）
M.moon2 = memo("moon2", lc_2.Moonphase_out2) -- 月相（名）

--- 回傳單值的即時來源
M.tdc = memo("tdc", function() return lc_2.time_description_chinese(os.time()) end)  -- 農曆時刻描述
M.mg = memo("mg", function() return f_y_s.min_guo(os.date("%Y")) end)                -- 民國紀年（今年）

--- 回傳多值的即時來源（打包記憶化）
--- ll_1, ll_2, ly_1, ly_2, lm, ld = Date2LunarDate(今日)
function M.lunar()
  local v = cache.lunar
  if v == nil then
    v = table.pack(lc_1.Date2LunarDate(os.date("%Y%m%d")))
    cache.lunar = v
  end
  return v[1], v[2], v[3], v[4], v[5], v[6]
end

--- All_g, Y_g, M_g, D_g, H_g = lunarJzl(今時)
function M.jzl()
  local v = cache.jzl
  if v == nil then
    v = table.pack(lc_1.lunarJzl(os.date("%Y%m%d%H")))
    cache.jzl = v
  end
  return v[1], v[2], v[3], v[4], v[5]
end

--- jpymd, jp_y = jp_ymd(今日)
function M.jp()
  local v = cache.jp
  if v == nil then
    v = table.pack(f_y_s.jp_ymd(os.date("%Y"), os.date("%m"), os.date("%d")))
    cache.jp = v
  end
  return v[1], v[2]
end

----------------------------------------------------------------------------------------
--- 原語再匯出（無狀態，直接轉出）

M.fs = f_n_s.fullshape_number      -- 全形數字
M.pc = f_n_s.purech_number         -- 純中文數字
M.rq1 = f_c_d_s.rqzdx1             -- 日期中數（小寫）
M.rq2 = f_c_d_s.rqzdx2             -- 日期中數（大寫）
M.ch_h = f_d_s.ch_h_date           -- 中文（小寫）時
M.ch_ms = f_d_s.ch_minsec_date     -- 中文（小寫）分秒
M.chb_h = f_d_s.chb_h_date         -- 中文（大寫）時
M.chb_ms = f_d_s.chb_minsec_date   -- 中文（大寫）分秒
M.jp_m = f_d_s.jp_m_date           -- 日本格式 月
M.jp_d = f_d_s.jp_d_date           -- 日本格式 日
M.eng1_m = f_d_s.eng1_m_date
M.eng2_m = f_d_s.eng2_m_date
M.eng3_m = f_d_s.eng3_m_date
M.eng1_d = f_d_s.eng1_d_date
M.eng2_d = f_d_s.eng2_d_date
M.eng3_d = f_d_s.eng3_d_date
M.eng4_d = f_d_s.eng4_d_date
M.sichen = GetLunarSichen          -- 農曆時辰
M.jieqi_out1 = lc_2.jieqi_out1     -- 目前節氣（前後各一）
M.now_jq = lc_1.GetNowTimeJq       -- 未來一年節氣表

--- read_number（中文讀法）小寫/大寫設定
function M.rn1(s) return f_c_n.read_number(f_c_n.confs[1], s) end
function M.rn2(s) return f_c_n.read_number(f_c_n.confs[2], s) end

----------------------------------------------------------------------------------------
--- 去零字串原語（gsub 回傳兩值，包裝成單值以便當 text_fn 使用）

--- 去開頭的一個 0："07:04" → "7:04"
function M.s0lead(s) local r = string.gsub(s, "^0", "") return r end
--- 去「0+數字」的 0（全串）："07時04分" → "7時4分"
function M.s0bd(s) local r = string.gsub(s, "0([%d])", "%1") return r end
--- 去「非數字+0」的 0（全串）："2026年08月" → "2026年8月"
function M.s0nd(s) local r = string.gsub(s, "([^%d])0", "%1") return r end
--- 去「空格+0」的 0（全串）：" 08 月" → " 8 月"
function M.s0sp(s) local r = string.gsub(s, "([ ])0", "%1") return r end
--- 去「空格0數字」的 0（保留空格）："上午 07:04" → "上午 7:04"
function M.s0spd(s) local r = string.gsub(s, " 0([%d])", " %1") return r end

----------------------------------------------------------------------------------------
--- 具名組合

--- 中文時刻：big=false 用小寫（ch_*）、true 用大寫（chb_*）；
--- hfmt "%H"（24 時制）或 "%I"（12 時制）；hword "時" 或 "點"；sec=true 加「分秒」
function M.cntime(big, hfmt, hword, sec)
  local h = big and M.chb_h or M.ch_h
  local ms = big and M.chb_ms or M.ch_ms
  local s = h(os.date(hfmt)) .. hword .. ms(os.date("%M")) .. "分"
  if sec then s = s .. ms(os.date("%S")) .. "秒" end
  return s
end

----------------------------------------------------------------------------------------
--- 規格產生器（每個回傳一份 render 規格陣列）

--- 時刻八連發（tw/nw/tc/nc 家族）：去零 a、去零 b、全形去零 a、全形去零 b、
--- 原樣 a、原樣 b、全形 a、全形 b
function M.gen_oct(afn, bfn, comment)
  return {
    { function() return M.s0bd(afn()) end, comment },
    { function() return M.s0bd(bfn()) end, comment },
    { function() return M.fs(M.s0bd(afn())) end, comment },
    { function() return M.fs(M.s0bd(bfn())) end, comment },
    { function() return afn() end, comment },
    { function() return bfn() end, comment },
    { function() return M.fs(afn()) end, comment },
    { function() return M.fs(bfn()) end, comment },
  }
end

--- 中文時刻四連發（tz/nz 家族）：小寫時、小寫點、大寫時、大寫點
function M.gen_cn4(sec, comment)
  return {
    { function() return M.cntime(false, "%H", "時", sec) end, comment },
    { function() return M.cntime(false, "%H", "點", sec) end, comment },
    { function() return M.cntime(true, "%H", "時", sec) end, comment },
    { function() return M.cntime(true, "%H", "點", sec) end, comment },
  }
end

--- 上午/下午＋中文時刻四連發（tu/nu 家族）
function M.gen_ampm_cn4(sec, comment)
  return {
    { function() return M.t2()[5] .. " " .. M.cntime(false, "%I", "時", sec) end, comment },
    { function() return M.t2()[5] .. " " .. M.cntime(false, "%I", "點", sec) end, comment },
    { function() return M.t2()[5] .. " " .. M.cntime(true, "%I", "時", sec) end, comment },
    { function() return M.t2()[5] .. " " .. M.cntime(true, "%I", "點", sec) end, comment },
  }
end

--- 年月日分隔符家族（fd/fo、fm/fr、fs/fy、fu/fv、fp/fq）
function M.gen_f_sep(sep, fsep)
  return {
    { function() return os.date("%Y" .. sep .. "%m" .. sep .. "%d") end, "〔年月日〕" },
    { function() return M.fs(os.date("%Y")) .. fsep .. M.fs(os.date("%m")) .. fsep .. M.fs(os.date("%d")) end, "〔年月日〕" },
    { function() return os.date("%d" .. sep .. "%m" .. sep .. "%Y") end, "〔日月年〕" },
    { function() return os.date("%m" .. sep .. "%d" .. sep .. "%Y") end, "〔月日年〕" },
  }
end

--- 年月日 時:分 分隔符家族（fnd/fno、fnm/fnr、fns/fny、fnu/fnv、fnp/fnq）
function M.gen_fn_sep(sep, fsep)
  return {
    { function() return os.date("%Y" .. sep .. "%m" .. sep .. "%d %H:%M") end, "〔年月日 時:分〕" },
    { function() return M.fs(os.date("%Y")) .. fsep .. M.fs(os.date("%m")) .. fsep .. M.fs(os.date("%d")) .. "　" .. M.fs(os.date("%H")) .. "：" .. M.fs(os.date("%M")) end, "〔年月日 時:分〕" },
    { function() return os.date("%d" .. sep .. "%m" .. sep .. "%Y %H:%M") end, "〔日月年 時:分〕" },
    { function() return os.date("%m" .. sep .. "%d" .. sep .. "%Y %H:%M") end, "〔月日年 時:分〕" },
  }
end

--- 年月日 時:分:秒 分隔符家族（ftd/fto、ftm/ftr、fts/fty、ftu/ftv、ftp/ftq）
function M.gen_ft_sep(sep, fsep)
  return {
    { function() return os.date("%Y" .. sep .. "%m" .. sep .. "%d %H:%M:%S") end, "〔年月日 時:分:秒〕" },
    { function() return M.fs(os.date("%Y")) .. fsep .. M.fs(os.date("%m")) .. fsep .. M.fs(os.date("%d")) .. "　" .. M.fs(os.date("%H")) .. "：" .. M.fs(os.date("%M")) .. "：" .. M.fs(os.date("%S")) end, "〔年月日 時:分:秒〕" },
    { function() return os.date("%d" .. sep .. "%m" .. sep .. "%Y %H:%M:%S") end, "〔日月年 時:分:秒〕" },
    { function() return os.date("%m" .. sep .. "%d" .. sep .. "%Y %H:%M:%S") end, "〔月日年 時:分:秒〕" },
  }
end

--- 月日分隔符家族（mdd/mdo、mdm/mdr、mds/mdy、mdu/mdv、mdp/mdq）
function M.gen_md_sep(sep, fsep)
  return {
    { function() return os.date("%m" .. sep .. "%d") end, "〔月日〕" },
    { function() return M.fs(os.date("%m")) .. fsep .. M.fs(os.date("%d")) end, "〔月日〕" },
    { function() return os.date("%d" .. sep .. "%m") end, "〔日月〕" },
  }
end

--- 年月分隔符家族（ymd/ymo、ymm/ymr、yms/ymy、ymu/ymv、ymp/ymq）
function M.gen_ym_sep(sep, fsep)
  return {
    { function() return os.date("%Y" .. sep .. "%m") end, "〔年月〕" },
    { function() return M.fs(os.date("%Y")) .. fsep .. M.fs(os.date("%m")) end, "〔年月〕" },
    { function() return os.date("%m" .. sep .. "%Y") end, "〔月年〕" },
  }
end

--- 民國六連發（fh/fnh/fth 家族）：
--- tc  緊接時刻格式（"" | "%H點%M分" | "%H點%M分%S秒"）
--- tsp 空格版時刻格式（"" | "%H 點 %M 分" | "%H 點 %M 分 %S 秒"）
function M.gen_minguo_h(tc, tsp)
  local function t_c() return tc ~= "" and " " .. os.date(tc) or "" end
  local function t_sp() return tsp ~= "" and " " .. os.date(tsp) or "" end
  local function t_c0() return tc ~= "" and os.date(tc) or "" end
  return {
    { function() return M.s0nd("民國" .. M.mg() .. "年" .. os.date("%m") .. "月" .. os.date("%d") .. "日" .. t_c()) end, "〔民國〕" },
    { function() return M.s0nd("民國 " .. M.mg() .. " 年 " .. os.date("%m") .. " 月 " .. os.date("%d") .. " 日" .. t_sp()) end, "〔民國*〕" },
    { function() return "民國" .. M.fs(M.mg()) .. "年" .. M.fs(M.s0bd(os.date("%m月%d日" .. tc))) end, "〔民國〕" },
    { function() return "民國" .. M.mg() .. "年" .. os.date("%m") .. "月" .. os.date("%d") .. "日" .. t_c0() end, "〔民國〕" },
    { function() return "民國 " .. M.mg() .. " 年 " .. os.date("%m") .. " 月 " .. os.date("%d") .. " 日" .. t_sp() end, "〔民國*〕" },
    { function() return "民國" .. M.fs(M.mg()) .. "年" .. M.fs(os.date("%m")) .. "月" .. M.fs(os.date("%d")) .. "日" .. (tc ~= "" and M.fs(os.date(tc)) or "") end, "〔民國〕" },
  }
end

--- 日本元号四連發（fj/fnj/ftj 家族）：tfmt "" | "%H:%M" | "%H:%M:%S"
function M.gen_jp_era4(tfmt)
  local function tail() return tfmt ~= "" and " " .. os.date(tfmt) or "" end
  return {
    { function() local jpymd = M.jp() return M.s0nd(jpymd) .. tail() end, "〔日本元号〕" },
    { function() local jpymd = M.jp() return M.fs(M.s0nd(jpymd) .. tail()) end, "〔日本元号〕" },  -- 全形化包含時間整串（修正原版只包日期的不一致）
    { function() local jpymd = M.jp() return jpymd .. tail() end, "〔日本元号〕" },
    { function() local jpymd = M.jp() return M.fs(jpymd .. tail()) end, "〔日本元号〕" },
  }
end

return M
