
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
--- '/ 單獨的功能總覽選單（原 translate() 內容純搬移）

local function main_menu(input, seg, env, ctx)
  local yield_c = ctx.yield_c
--- 擴充模式 \r\n    日期 (年月日) ~d \r\n    年 ~y  月 ~m  日 ~day \r\n    年月 ~ym  月日 ~md \r\n    時間 (時分) ~n   (時分秒) ~t \r\n    日期時間 (年月日時分) ~dn\r\n    日期時間 (年月日時分秒) ~dt
    if (input == env.prefix) then
    -- if input:find("^" .. env.prefix .. "$") then
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

      for k, v in ipairs(env.menu_table) do
        local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
        -- cand.preedit = input .. "\t《時間日期數字字母》▶"
        cand.preedit = input .. "\t《特殊功能集》▶"
        yield(cand)
      end
      return true
    end
  return false
end

----------------------------------------------------------------------------------------
--- k* 鍵位表、j 快捷開啟、v/g/gc 版本記憶體（原 translate() 內容純搬移）

local function keys_run_ver(input, seg, env, ctx)
  local yield_c = ctx.yield_c
  local caret_pos = ctx.caret_pos
    -- 鍵位編碼說明
    if (input == env.prefix .. "k") then
      local keys_table = {
          { "  ~k 〔快捷鍵 說明〕", "⓵" }
        , { "  ~o 〔操作鍵 說明〕", "⓶" }
        , { "  ~j 〔日文 羅馬字 編碼〕", "⓷" }
        , { "  ~h 〔韓文 HNC 編碼〕(注音系列)", "⓸" }
        , { "  ~s 〔韓文 洋蔥形碼 編碼〕(形碼系列)", "⓹" }
        , { "  ~i 〔拉丁 洋蔥形碼 IPA國際音標 編碼〕", "⓺" }
        , { "  ~p 〔拉丁 洋蔥形碼 KK/DJ/IPA音標 編碼〕", "⓻" }
        , { "  ~y 〔拉丁 洋蔥形碼 中文拼音 編碼〕", "⓼" }
        , { "  ~g 〔希臘 洋蔥形碼 編碼〕", "⓽" }
        , { "  ~c 〔西里爾 洋蔥形碼 編碼〕", "⓾" }
        , { "　═══  結束  ═══  ", "" }
        -- , { "===========  結束  ===========    ", "⓼" }
        }
      for k, v in ipairs(keys_table) do
        local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
        cand.preedit = input .. "\t【鍵位和編碼】▶"
        yield(cand)
      end
      return true
    end

    if (input == env.prefix .. "ko") then
      -- local keys_table = hotkeys(env.schema_id)[1]
      -- for k, v in ipairs(keys_table) do
      for k, v in ipairs(hotkeys(env.schema_id)[1]) do
        local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
        cand.preedit = input .. "\t【操作鍵 說明】"
        yield(cand)
      end
      return true
    end

    if (input == env.prefix .. "kk") then
      -- local keys_table = hotkeys(env.schema_id)[2]
      -- for k, v in ipairs(keys_table) do
      for k, v in ipairs(hotkeys(env.schema_id)[2]) do
        local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
        cand.preedit = input .. "\t【快捷鍵 說明】"
        yield(cand)
      end
      return true
    end

    -- if (input == env.prefix .. "kk") then
    --   local keys_table = {
    --       { "  h〔韓文 HNC 鍵位〕", "⁰" }
    --     , { "  s〔韓文 洋蔥形碼 鍵位〕", "¹" }
    --     }
    --   for k, v in ipairs(keys_table) do
    --     local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
    --     cand.preedit = input .. "\t【韓文鍵位】▶"
    --     yield(cand)
    --   end
    --   return
    -- end

    if (input == env.prefix .. "kh") then
      local keys_table = kh_table
      for k, v in ipairs(keys_table) do
        local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
        cand.preedit = input .. "\t【韓文 HNC 編碼】"
        yield(cand)
      end
      return true
    end

    if (input == env.prefix .. "ks") then
      local keys_table = ks_table
      for k, v in ipairs(keys_table) do
        local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
        cand.preedit = input .. "\t【韓文 洋蔥形碼 編碼】"
        yield(cand)
      end
      return true
    end

    if (input == env.prefix .. "kj") then
      local keys_table = kj_table
      for k, v in ipairs(keys_table) do
        local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
        cand.preedit = input .. "\t【日文 羅馬字 編碼】"
        yield(cand)
      end
      return true
    end

    if (input == env.prefix .. "ki") then
      local keys_table = ki_table
      for k, v in ipairs(keys_table) do
        local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
        cand.preedit = input .. "\t【拉丁 洋蔥形碼 IPA國際音標 編碼】"
        yield(cand)
      end
      return true
    end

    if (input == env.prefix .. "kp") then
      local keys_table = kp_table
      for k, v in ipairs(keys_table) do
        local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
        cand.preedit = input .. "\t【拉丁 洋蔥形碼 KK/DJ/IPA音標 編碼】"
        yield(cand)
      end
      return true
    end

    if (input == env.prefix .. "ky") then
      local keys_table = ky_table
      for k, v in ipairs(keys_table) do
        local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
        cand.preedit = input .. "\t【拉丁 洋蔥形碼 中文拼音 編碼】"
        yield(cand)
      end
      return true
    end

    if (input == env.prefix .. "kg") then
      local keys_table = kg_table
      for k, v in ipairs(keys_table) do
        local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
        cand.preedit = input .. "\t【希臘 洋蔥形碼 編碼】"
        yield(cand)
      end
      return true
    end

    if (input == env.prefix .. "kc") then
      local keys_table = kc_table
      for k, v in ipairs(keys_table) do
        local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
        cand.preedit = input .. "\t【西里爾 洋蔥形碼 編碼】"
        yield(cand)
      end
      return true
    end


    -- 快捷開啟（開啟檔案/程式/網站）
    if (input == env.prefix .. "j") then
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
      -- for k, v in ipairs(keys_table) do
      for k, v in ipairs(env.run_menu_table) do -- init 引入
        local cand = Candidate("simp_mf_tips", seg.start, seg._end, v[2], " " .. v[1])
        cand.preedit = input .. "\t【快捷開啟】▶"
        yield(cand)
      end
      return true
    end

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


    -- 版本資訊
    if (input == env.prefix .. "v") then
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
    if (input == env.prefix .. "g") then
      yield_c( ("%.f"):format(collectgarbage("count")) .." KB", "〔 the amount of Lua memory 〕")
      return true
    end

    -- 垃圾回收器(Garbage Collection)
    if (input == env.prefix .. "gc") then
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
  return false
end

return { main_menu = main_menu, keys_run_ver = keys_run_ver }
