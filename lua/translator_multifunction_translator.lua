----------------------------------------------------------------------------------------
--- 多功能翻譯器主檔（薄調度器）
--- 各分支已拆分至 lua/mf_components/ 子模組（純搬移，行為不變）：
---   mf_datetime.lua     日期時間分支（含 ○y○m○d）
---   mf_number_calc.lua  數字與計算機分支
---   mf_letters.lua      字母大小寫轉換分支（/ ; '）
---   mf_unicode.lua      u/x/c/o 內碼與 i URL encode/decode 分支
---   mf_open_menu.lua    j 快捷開啟、k* 鍵位表、v/g/gc 版本記憶體、'/ 功能總覽選單

local mf_datetime = require("mf_components/mf_datetime")
local mf_number_calc = require("mf_components/mf_number_calc")
local mf_letters = require("mf_components/mf_letters")
local mf_unicode = require("mf_components/mf_unicode")
local mf_open_menu = require("mf_components/mf_open_menu")

----------------------------------------------------------------------------------------
--- 快捷開啟

local run_pattern = require("p_components/p_run_pattern")
local run_menu = require("p_components/p_run_menu")

----------------------------------------------------------------------------------------
--- 置入方案範例
--[[
engine:
  translators:
    - lua_translator@mf_translator

mf_translator:
  prefix: "'/"  # "`" 或其他
--]]
----------------------------------------------------------------------------------------
local function init(env)
  local engine = env.engine
  local schema = engine.schema
  local config = schema.config
  -- local namespace = "mf_translator"
  env.prefix = config:get_string(env.name_space .. "/prefix") or "'/"  -- 防 schema 未設 prefix 時 nil 串接報錯
  env.schema_id = config:get_string("schema/schema_id")
  env.menu_table = {
        -- { "〔半角〕", "`" }
        { "【日期和時間】", "⓪" }
      , { "　f〔年月日〕  ym〔年月〕  md〔月日〕", "①" }
      , { "　y〔年〕  m〔月〕  d〔日〕  w〔週〕", "②" }
      , { "　n〔時:分〕  t〔時:分:秒〕", "③" }
      , { "　fw〔年月日週〕  mdw〔月日週〕", "④" }
      , { "　fn〔年月日 時:分〕  ft〔年月日 時:分:秒〕", "⑤" }
      , { "　p〔程式格式〕  z〔時區〕  s〔節氣〕  l〔月相〕", "⑥" }
      -- , { "  ○/○/○〔 ○ 年 ○ 月 ○ 日〕  ○/○〔 ○ 月 ○ 日〕", "⑥" }
      -- , { "  ○-○-○〔○年○月○日〕  ○-○〔○月○日〕", "⑦" }
      , { "　○ y ○ m ○ d〔○年○月○日〕", "⑦" }
      , { "　○ y ○ m〔○年○月〕    ○ m ○ d〔○月○日〕", "⑧" }
      , { "　○ y〔○年〕    ○ m〔○月〕    ○ d〔○日〕", "⑨" }
      , { "【數字和計算機】", "⑩" }
      -- , { "  ○○○〔數字〕", "⑨" }
      , { "　[-.0-9]+〔數字〕", "⑪" }
      , { "　[-.0-9]+[ + - * / ^ ( ) ]...〔計算機〕", "⑫" }
      , { "　※ 算符： ‹+ a›   ‹- r›   ‹* x›   ‹/ v›   ‹^ s›   ‹ ( q›   ‹ ) w›　", "⑬" }
      , { "【字母】", "⑭" }
      , { "　/ [a-z , . - \' / ]+〔小寫字母〕", "⑮" }
      , { "　; [a-z , . - \' / ]+〔大寫字母〕", "⑯" }
      , { "　\' [a-z , . - \' / ]+〔開頭大寫字母〕", "⑰" }
      , { "【Unicode 內碼】", "⑱" }
      , { "　i [0-9a-f]+〔Percent/URL encoding〕", "⑲" }
      , { "　u [0-9a-f]+〔內碼十六進制 Hex〕(Unicode)", "⑳" }
      , { "　x [0-9a-f]+〔內碼十六進制 Hex〕(Unicode)", "㉑" }
      , { "　c [0-9]+〔內碼十進制 Dec〕", "㉒" }
      , { "　o [0-7]+〔內碼八進制 Oct〕", "㉓" }
      , { "【快捷開啟】", "㉔" }
      , { "　j [a-z]+〔快捷開啟〕", "㉕" }
      , { "【鍵位和編碼】", "㉖" }
      , { "　kk〔快捷鍵 說明〕", "㉗" }
      , { "　ko〔操作鍵 說明〕", "㉘" }
      , { "　kj〔日文 羅馬字 編碼〕", "㉙" }
      , { "　kh〔韓文 HNC 編碼〕(注音系列)", "㉚" }
      , { "　ks〔韓文 洋蔥形碼 編碼〕(形碼系列)", "㉛" }
      , { "　ki〔拉丁 洋蔥形碼 IPA國際音標 編碼〕", "㉜" }
      , { "　kp〔拉丁 洋蔥形碼 KK/DJ/IPA音標 編碼〕", "㉝" }
      , { "　ky〔拉丁 洋蔥形碼 中文拼音 編碼〕", "㉞" }
      , { "　kg〔希臘 洋蔥形碼 編碼〕", "㉟" }
      , { "　kc〔西里爾 洋蔥形碼 編碼〕", "㊱" }
      , { "【版本和記憶體】", "㊲" }
      , { "　v〔版本資訊〕", "㊳" }
      , { "　g〔Lua 所佔記憶體〕(Garbage)", "㊴" }
      , { "　gc〔垃圾回收〕(Garbage Collection)", "㊵" }
      , { "═══  結束  ═══  ", "㊶" }
      , { "", "㊷" }
      , { "", "㊸" }
      , { "", "㊹" }
      , { "", "㊺" }
      , { "", "㊻" }
      , { "", "㊼" }
      , { "", "㊽" }
      , { "", "㊾" }
      , { "", "㊿" }
      -- , { "===========  結束  ===========    ", "㉛" }
      -- , { "〔夜思‧李白〕", "床前明月光，疑是地上霜。\r舉頭望明月，低頭思故鄉。" }
      }
  env.run_menu_table = run_menu(run_pattern)
  -- log.info("mf_translator Initilized!")
end
----------------------------------------------------------------------------------------
--- @@ mf_translator
--[[
掛載 mf_translator 函數開始
--]]
local function translate(input, seg, env)
  local engine = env.engine
  local context = engine.context
  local caret_pos = context.caret_pos or 0

  --- 精簡程式碼用
  local yield_c = function(cand_text, comment)
    comment = comment == nil and "" or comment
    yield(Candidate("simp_mf", seg.start, seg._end, cand_text, comment))
  end

  if seg:has_tag("mf_translator") then
  -- if seg:has_tag("mf_translator") and string.match(input, env.prefix) then
  -- if string.match(input, env.prefix) then
  -- local start_key = string.match(input, env.prefix)
  -- if start_key then

    -- local jpymd, jp_y = jp_ymd(os.date("%Y"),os.date("%m"),os.date("%d"))
    -- local chinese_time = time_description_chinese(os.time())
    -- local All_g, Y_g, M_g, D_g, H_g = lunarJzl(os.date("%Y%m%d%H"))
    -- local ll_1, ll_2, ly_1, ly_2, lm, ld = Date2LunarDate(os.date("%Y%m%d"))
    -- local aptime1, aptime2, aptime3, aptime4, aptime5, aptime6, aptime7, aptime8, aptime0_1, aptime0_2, aptime0_3, aptime0_4, aptime00_1, aptime00_2,  aptime00_3, aptime00_4 = time_out1()
    -- local aptime_c1, aptime_c2, aptime_c3, aptime_c4, ap_5 = time_out2()

    --- 依原始 if/elseif 檔內順序依序調度各子模組；
    --- 子模組函數有處理到（原程式碼該處為 return）就回 true，主檔即結束。
    local ctx = { yield_c = yield_c, caret_pos = caret_pos }

    if mf_open_menu.main_menu(input, seg, env, ctx) then return end   -- '/ 功能總覽選單
    if mf_letters.tips(input, seg, env, ctx) then return end          -- / ; ' 前導提示
    if mf_unicode.tips(input, seg, env, ctx) then return end          -- x u c o i 前導提示
    if mf_open_menu.keys_run_ver(input, seg, env, ctx) then return end -- k* 鍵位表、j 快捷開啟、v/g/gc
    if mf_datetime.now(input, seg, env, ctx) then return end          -- 即時日期時間各分支
    if mf_letters.convert(input, seg, env, ctx) then return end       -- 字母大小寫轉換
    if mf_unicode.codes(input, seg, env, ctx) then return end         -- u/x/c/o 內碼、i URL encode/decode
    if mf_datetime.custom(input, seg, env, ctx) then return end       -- ○y○m○d 指定日期
    if mf_number_calc.calc(input, seg, env, ctx) then return end      -- 數字與計算機

  end
end


return {init = init, func = translate}
