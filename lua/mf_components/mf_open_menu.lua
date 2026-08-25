
----------------------------------------------------------------------------------------
--- 版本訊息

local Ver_info = require("f_components/f_ver_info")

----------------------------------------------------------------------------------------
--- 按鍵說明
local hotkeys = require("f_components/keys_table/hot_keys")
local kh_table = require("f_components/keys_table/kh_table")
local ks_table = require("f_components/keys_table/ks_table")
local kj_table = require("f_components/keys_table/kj_table")
local ki_table = require("f_components/keys_table/ki_table")
local kp_table = require("f_components/keys_table/kp_table")
local ky_table = require("f_components/keys_table/ky_table")
local kg_table = require("f_components/keys_table/kg_table")
local kc_table = require("f_components/keys_table/kc_table")

----------------------------------------------------------------------------------------
--- 快捷開啟

local run_pattern = require("p_components/p_run_pattern")

----------------------------------------------------------------------------------------
--- 選單類 handler 產生器：迭代表格逐條 yield tips 候選（原各 k*/j 選單迴圈共通結構）
--- get_table(env) 回傳選單表；tag 為 preedit 尾標

local function menu_handler(get_table, tag)
  return function(input, seg, env, ctx)
    for k, v in ipairs(get_table(env)) do
      local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
      cand.preedit = input .. "\t" .. tag
      yield(cand)
    end
    return true
  end
end

----------------------------------------------------------------------------------------
--- '/ 單獨的功能總覽選單（原 translate() 內容，改為精確代碼 handler）
--- 擴充模式 \r\n    日期 (年月日) ~d \r\n    年 ~y  月 ~m  日 ~day \r\n    年月 ~ym  月日 ~md \r\n    時間 (時分) ~n   (時分秒) ~t \r\n    日期時間 (年月日時分) ~dn\r\n    日期時間 (年月日時分秒) ~dt

      -- yield_c( "" , "擴充模式")
      -- yield_c( "║　d〔年月日〕┃   ym〔年月〕┃　md〔月日〕║" , "")
      -- yield_c( "║　　y〔年〕　┃　　m〔月〕 ┃　　dy〔日〕 ║" , "")
      -- yield_c( "║　　　n〔時:分〕　　 ┃　　　t〔時:分:秒〕　║" , "")
      -- yield_c( "║　dn〔年月日 時:分〕  ┃ dt〔年月日 時:分:秒〕║" , "")
      -- yield_c( "║*/*/*〔 * 年 * 月 * 日〕┃　*-*-*〔*年*月*日〕 ║" , "")
      -- yield_c( "║　　*/*〔 * 月 * 日〕   ┃　　 *-*〔*月*日〕　 ║" , "")

      -- yield_c( "┃ f〔年月日〕┇ ym〔年月〕┇ md〔月日〕┇ fw〔年月日週〕┇ mdw〔月日週〕" , "")
      -- yield_c( "┃ y〔年〕┇ m〔月〕┇ d〔日〕┇ w〔週〕┇ n〔時:分〕┇ t〔時:分:秒〕" , "")
      -- yield_c( "┃ fn〔年月日 時:分〕┇ ft〔年月日 時:分:秒〕" , "")
      -- -- yield_c( "┃ fwn〔年月日週 時:分〕┇ fwt〔年月日週 時:分:秒〕" , "")
      -- yield_c( "┃ ○/○/○〔 ○ 年 ○ 月 ○ 日〕┇ ○/○〔 ○ 月 ○ 日〕" , "")
      -- yield_c( "┃ ○-○-○〔○年○月○日〕┇ ○-○〔○月○日〕┇ ○○○〔數字〕" , "")
      -- -- yield_c( "┃ ○○○〔數字〕" , "")

-- cand.preedit = input .. "\t《時間日期數字字母》▶"
----------------------------------------------------------------------------------------
--- 分層選單（'/ 主選單、'/dt 日期時間、'/ca 計算機）
--- 資料在 mf_components/mf_menu_data.lua，與 processor_p_run_files.lua 共用同一份表：
--- 這裡只負責「顯示」，按下空白後的「跳轉/執行」由該 processor 依 selected_index 處理。
--- 候選 text 一律留空 —— 舊版把 ①②③ 當候選文字，選下去會在文件裡上屏一個圈圈數字，
--- 看起來就像「按了沒反應」。

local menu_data = require("mf_components/mf_menu_data")

local function hier_menu(code)
  return function(input, seg, env, ctx)
    local menu = menu_data.menus[code]
    if not menu then return false end
    for _, row in ipairs(menu.rows) do
      local cand = Candidate("simp_mf_tips", seg.start, seg._end, "", " " .. row.label)
      cand.preedit = input .. "\t" .. menu.tag
      yield(cand)
    end
    return true
  end
end

----------------------------------------------------------------------------------------
--- k 鍵位編碼說明子選單（原 keys_run_ver() 內容）

local k_keys_table = {
    { "  ~k 〔快捷鍵 說明〕", "⓵" }
  , { "  ~o 〔操作鍵 說明〕", "⓶" }
  , { "  ~j 〔日文 羅馬字 編碼〕", "⓷" }
  , { "  ~h 〔韓文 HNC 編碼〕(注音系列)", "⓸" }
  , { "  ~s 〔韓文 形碼 編碼〕(形碼系列)", "⓹" }
  , { "  ~i 〔拉丁 形碼 IPA國際音標 編碼〕", "⓺" }
  , { "  ~p 〔拉丁 形碼 KK/DJ/IPA音標 編碼〕", "⓻" }
  , { "  ~y 〔拉丁 形碼 中文拼音 編碼〕", "⓼" }
  , { "  ~g 〔希臘 形碼 編碼〕", "⓽" }
  , { "  ~c 〔西里爾 形碼 編碼〕", "⓾" }
  , { "　═══  結束  ═══  ", "" }
  -- , { "===========  結束  ===========    ", "⓼" }
  }

    -- if (input == env.prefix .. "kk") then
    --   local keys_table = {
    --       { "  h〔韓文 HNC 鍵位〕", "⁰" }
    --     , { "  s〔韓文 形碼 鍵位〕", "¹" }
    --     }
    --   for k, v in ipairs(keys_table) do
    --     local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
    --     cand.preedit = input .. "\t【韓文鍵位】▶"
    --     yield(cand)
    --   end
    --   return
    -- end

----------------------------------------------------------------------------------------
--- j 快捷開啟（開啟檔案/程式/網站）之 pattern 分支（原 keys_run_ver() 內容，
--- matcher 保序：位於日期時間各精確代碼之前，j 開頭後接字母，無交集）

      -- local keys_table = {
      --     { "※ 限起始輸入，限英文 [a-z]+  ", "⓿" }  -- ≤ 2
      --   , { "※ 編輯後須「重新部署」生效  ", "❶" }  --  "────────────  "
      --   , { "  ~t   〔 編輯 快捷開啟 table 〕", "❷" }
      --   , { "  ~c   〔 編輯 custom 短語 〕", "❸" }
      --   , { "  ~r   〔 Rime 官方 GitHub 〕", "❹" }
      --   , { "  ~rw 〔 Rime 詳解 〕", "❺" }
      --   , { "  ~l   〔 librime-lua 官方 GitHub 〕", "❻" }
      --   , { "  ~lw 〔 librime-lua 腳本開發指南 〕", "❼" }
      --   , { "  ~o   〔 Onion 洋蔥 GitHub 〕", "❽" }
      --   , { "  ~ow 〔 Onion 洋蔥 GitHub Wiki 〕", "❾" }
      --   , { "═══  結束  ═══  ", "❿" }
      --   , { "", "⓫" }
      --   , { "", "⓬" }
      --   , { "", "⓭" }
      --   , { "", "⓮" }
      --   , { "", "⓯" }
      --   , { "", "⓰" }
      --   , { "", "⓱" }
      --   , { "", "⓲" }
      --   , { "", "⓳" }
      --   , { "", "⓴" }
      --   }
      -- local keys_table = run_menu(run_pattern)  -- 不用 init 引入，直接引入

local function j_run(input, seg, env, ctx)
  local caret_pos = ctx.caret_pos
    local op_check = string.match(input, env.prefix .. "j([a-z]+)$")
    local first_check = caret_pos - #input
    if op_check and first_check ~= 0 then
      local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "〔非起始輸入〕")
      cand2.preedit = env.prefix .. "j " .. op_check .. "\t【快捷開啟】"
      yield(cand2)
      return true
    elseif op_check == "t" then
      local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "〘 編輯 快捷開啟 table 〙")  -- or〔錯誤〕
      cand2.preedit = env.prefix .. "j " .. op_check .. "\t【快捷開啟】"
      yield(cand2)
      return true
    elseif op_check == "c" and env.prefix == "`" then
      local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "〔無短語功能〕")  -- or〔錯誤〕
      cand2.preedit = env.prefix .. "j " .. op_check .. "\t【快捷開啟】"
      yield(cand2)
      return true
    elseif op_check == "c" then
      local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "〘 編輯 custom 短語 〙")  -- or〔錯誤〕
      cand2.preedit = env.prefix .. "j " .. op_check .. "\t【快捷開啟】"
      yield(cand2)
      return true
    elseif op_check and first_check == 0 then
      local run_in = run_pattern[ op_check ]
      if run_in ~= nil then
        local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "〘 " .. run_in.name .. " 〙")  -- or〔錯誤〕
        cand2.preedit = env.prefix .. "j " .. op_check .. "\t【快捷開啟】"
        yield(cand2)
      return true
      elseif run_in == nil then
        local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "〔無〕")  -- 〔無此開啟碼〕or〔錯誤〕
        cand2.preedit = env.prefix .. "j " .. op_check .. "\t【快捷開啟】"
        yield(cand2)
        return true
      end
    -- elseif op_check == "fc" then
    --   local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "〔無短語功能〕")  -- or〔錯誤〕
    --   cand2.preedit = env.prefix .. "j " .. op_check .. "\t【快捷開啟】"
    --   yield(cand2)
    --   return
    -- elseif op_check and first_check == 0 then
    -- -- if (input == env.prefix .. "opp" ) then
    --   local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "〔無此開啟碼〕")  -- or〔錯誤〕
    --   cand2.preedit = env.prefix .. "j " .. op_check .. "\t【快捷開啟】"
    --   yield(cand2)
    --   return
    end
  return false
end

----------------------------------------------------------------------------------------
--- '/git 直達碼：更新設定並重新部署
--- 動作本身由 processor_p_run_files.lua 攔截空白鍵執行，這裡只負責顯示提示候選，
--- 免得按下去不知道會發生什麼事。與 '/jgit 走同一個 run_pattern 條目。

local function git_update(input, seg, env, ctx)
  local caret_pos = ctx.caret_pos
  local run_in = run_pattern["git"]
  local tip
  if caret_pos - #input ~= 0 then
    tip = "〔非起始輸入〕"
  elseif run_in == nil then
    tip = "〔本平台未提供〕"
  else
    tip = "〘 " .. run_in.name .. " 〙"
  end
  local cand = Candidate("simp_mf_tips", seg.start, seg._end, "", tip)
  cand.preedit = env.prefix .. "git" .. "\t【快捷開啟】"
  yield(cand)
  return true
end

----------------------------------------------------------------------------------------
--- v/g/gc 版本資訊與記憶體（原 keys_run_ver() 內容，改為精確代碼 handler）

-- 版本資訊
local function ver(input, seg, env, ctx)
  local yield_c = ctx.yield_c
      yield_c( Ver_info(env)[1], "〔 distribution_version 〕")
      yield_c( Ver_info(env)[2], "〔 rime_version 〕")
      yield_c( Ver_info(env)[3], "〔 librime-lua_version 〕")
      yield_c( Ver_info(env)[4], "〔 lua_version 〕")
      yield_c( Ver_info(env)[5], "〔 installation_id 〕")
      --- 記憶體回收，上方可能讓記憶暴漲，故增 collectgarbage。
      -- collectgarbage()  -- 強制進行垃圾回收
      -- collectgarbage("collect")  -- 做一次完整的垃圾收集循環
      return true
end

-- lua 所佔垃圾/記憶體(Garbage)
local function garbage(input, seg, env, ctx)
  local yield_c = ctx.yield_c
      yield_c( ("%.f"):format(collectgarbage("count")) .." KB", "〔 the amount of Lua memory 〕")
      return true
end

-- 垃圾回收器(Garbage Collection)
local function garbage_collect(input, seg, env, ctx)
  local yield_c = ctx.yield_c
      yield_c( ("%.f"):format(collectgarbage("count")) .." KB", "〔 the amount of Lua memory before GC 〕")
      -- yield_c( ("%.f"):format(collectgarbage("count")*1024) .." Bytes", "〔 the amount of lua memory before GC 〕")
      -- yield_c( collectgarbage("count") .." KB", "〔 the amount of lua memory before GC 〕")
      -- yield_c( collectgarbage("count")*1024, "〔 the amount of lua memory before GC 〕")
      collectgarbage()  -- 強制進行垃圾回收
      -- collectgarbage("collect")  -- 做一次完整的垃圾收集循環
      yield_c( ("%.f"):format(collectgarbage("count")) .." KB", "〔 the amount of Lua memory after GC 〕")
      -- yield_c( ("%.f"):format(collectgarbage("count")*1024) .." Bytes", "〔 the amount of lua memory after GC 〕")
      -- yield_c( collectgarbage("count") .." KB", "〔 the amount of lua memory after GC 〕")
      -- yield_c( collectgarbage("count")*1024, "〔 the amount of lua memory after GC 〕")
      return true
end

----------------------------------------------------------------------------------------
--- 向 registry 註冊（精確代碼查表；j[a-z]+ 為 matcher，保持原 if 鏈順序）

local function register(reg)
  reg.register_exact("",   hier_menu(""))                                              -- '/ 功能總覽（分層選單）
  reg.register_exact("dt", hier_menu("dt"))                                            -- '/dt 日期與時間
  reg.register_exact("ca", hier_menu("ca"))                                            -- '/ca 計算機用法
  reg.register_exact("k",  menu_handler(function() return k_keys_table end, "【鍵位和編碼】▶"))
  reg.register_exact("ko", menu_handler(function(env) return hotkeys(env.schema_id)[1] end, "【操作鍵 說明】"))
  reg.register_exact("kk", menu_handler(function(env) return hotkeys(env.schema_id)[2] end, "【快捷鍵 說明】"))
  reg.register_exact("kh", menu_handler(function() return kh_table end, "【韓文 HNC 編碼】"))
  reg.register_exact("ks", menu_handler(function() return ks_table end, "【韓文 形碼 編碼】"))
  reg.register_exact("kj", menu_handler(function() return kj_table end, "【日文 羅馬字 編碼】"))
  reg.register_exact("ki", menu_handler(function() return ki_table end, "【拉丁 形碼 IPA國際音標 編碼】"))
  reg.register_exact("kp", menu_handler(function() return kp_table end, "【拉丁 形碼 KK/DJ/IPA音標 編碼】"))
  reg.register_exact("ky", menu_handler(function() return ky_table end, "【拉丁 形碼 中文拼音 編碼】"))
  reg.register_exact("kg", menu_handler(function() return kg_table end, "【希臘 形碼 編碼】"))
  reg.register_exact("kc", menu_handler(function() return kc_table end, "【西里爾 形碼 編碼】"))
  reg.register_exact("j",  menu_handler(function(env) return env.run_menu_table end, "【快捷開啟】▶"))  -- init 引入
  reg.register_matcher(j_run)                                                          -- j[a-z]+ 快捷開啟
  reg.register_exact("git", git_update)                                                -- '/git 更新設定並重新部署
  reg.register_exact("v", ver)
  reg.register_exact("g", garbage)
  reg.register_exact("gc", garbage_collect)
end

return { register = register }
