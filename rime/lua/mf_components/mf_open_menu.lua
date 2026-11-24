
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
--- 分層選單（'/ 主選單、'/dt 日期時間、'/num 計算機、'/dev 小工具、'/code 編碼）
--- 資料在 mf_components/mf_menu_data.lua，與 processor_p_run_files.lua 共用同一份表：
--- 這裡只負責「顯示」，按下空白後的「跳轉/執行」由該 processor 依 selected_index 處理。
--- 候選文字放「該列的代碼」（'/dt、'/f…）：一來看得到代碼、下次可以直接打，
--- 二來每列文字不同，才不會被 engine/filters 末端的 uniquifier 合併掉
--- （舊版把 ①②③ 當文字就是為了這個；試過留空，六列會被併成一列）。

local menu_data = require("mf_components/mf_menu_data")

-- 選單列的算繪。hier_menu（固定選單）與 bare_prefix（前綴搜尋）共用同一份，
-- 兩邊長相與候選文字規則才會完全一致。
local function render_rows(rows, tag, input, seg, env)
  for _, row in ipairs(rows) do
    local text = env.prefix .. (row.key or "")
    local cand = Candidate("simp_mf_tips", seg.start, seg._end, text, "  " .. row.label)
    cand.preedit = input .. "\t" .. tag
    yield(cand)
  end
  return true
end

local function hier_menu(code)
  return function(input, seg, env, ctx)
    local rows, tag = menu_data.lookup(code)
    if not rows then return false end
    return render_rows(rows, tag, input, seg, env)
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
      --   , { "═══  結束  ═══  ", "❿" }
      --   , { "", "⓫" }
      --   , { "", "⓬" }
      --   , { "", "⓭" }
      --   , { "", "⓮" }
      --   , { "", "⓯" }
      --   , { "", "⓰" }
      --   , { "", "⓱" }

----------------------------------------------------------------------------------------
--- 裸代碼前綴搜尋：'/gi → '/git、'/co → '/code、'/uu → '/uuid。
--- 判斷規則全部在 mf_menu_data.lookup（三道護欄的理由寫在那裡），這裡只負責算繪。
--- 註冊位置：mf_letters／mf_unicode 之前。
---   ‧ 不能更晚：mf_unicode 的 codes() 對 '/ca 這種 [xuco]+hex 會 return true
---     （雖然一個候選都不吐），排在它後面就永遠輪不到，畫面空白但 p_run_files
---     那邊卻認得選單，兩邊會不一致。
--- 實測不會蓋到別人：letters 吃 / ; ' 開頭、calc 與指定日期都要數字，
--- 而 devkit 是獨立的 translator，本來就與這裡並存。

local function bare_prefix(input, seg, env, ctx)
  local code = string.match(input, "^" .. env.prefix .. "([a-z]+)$")
  if not code then return false end
  if ctx.caret_pos - #input ~= 0 then return false end   -- 非起始輸入不介入
  local rows, tag = menu_data.lookup(code)
  if not rows then return false end
  return render_rows(rows, tag, input, seg, env)
end

----------------------------------------------------------------------------------------
--- 一級指令代碼的提示候選（'/h、'/git、'/phrase、'/cmd…）。
--- 資料驅動：p_run_pattern 裡每個 direct = true 的條目自動有一個，
--- 不必再為每個指令寫一份 handler（'/git 以前就是寫死的一份）。
--- 動作本身由 processor_p_run_files.lua 攔截空白鍵執行，這裡只負責讓使用者
--- 「看得到按下去會發生什麼事」。
local function direct_tip(code)
  return function(input, seg, env, ctx)
    local run_in = run_pattern[code]
    local tip
    if ctx.caret_pos - #input ~= 0 then
      tip = "〔非起始輸入〕"
    elseif run_in == nil then
      tip = "〔本平台未提供〕"
    else
      tip = "〘 " .. run_in.name .. " 〙"
    end
    local cand = Candidate("simp_mf_tips", seg.start, seg._end, "", tip)
    cand.preedit = env.prefix .. code .. "\t【指令】"
    yield(cand)
    return true
  end
end

--- 掛載所有 direct 指令。由 translator_multifunction_translator 在**所有其他模組
--- 註冊完之後**呼叫 —— registry 是「後註冊覆蓋先註冊」，這樣才有辦法用
--- has_exact 檢查代碼有沒有被佔用，撞到就跳過（讓路給既有功能，不會靜默弄壞它）。
--- processor_p_run_files 也用同一個判斷，兩邊一致。
local function register_direct(reg)
  for code, v in pairs(run_pattern) do
    if v.direct and not reg.has_exact(code) then
      reg.register_exact(code, direct_tip(code))
      reg.claim_direct(code)          -- 讓 processor 知道這個代碼真的掛上了
    end
  end
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
  reg.register_exact("",    hier_menu(""))                                             -- '/ 功能總覽（分層選單）
  reg.register_exact("dt",  hier_menu("dt"))                                           -- '/dt 日期與時間
  reg.register_exact("num", hier_menu("num"))                                          -- '/num 計算機用法
  reg.register_exact("dev",  hier_menu("dev"))                                         -- '/dev 開發小工具＋版本
  -- ⚠ "code" 開頭雖然撞到 mf_unicode 的 c（十進制內碼），但 registry 是「先查
  --   精確表、再跑 matcher」，精確碼永遠贏；而且 mf_unicode 只註冊單字母 c，
  --   不會覆蓋 code 這一鍵。'/co、'/cod 中間狀態沒有候選是預期的。
  reg.register_exact("code", hier_menu("code"))                                        -- '/code 編碼與字母
  -- 第三層：把以前只能背代碼才找得到的功能全部給一個入口
  reg.register_exact("dty",  hier_menu("dty"))                                         -- '/dty  日期：單項
  reg.register_exact("dts",  hier_menu("dts"))                                         -- '/dts  日期：其他
  reg.register_exact("set",  hier_menu("set"))                                         -- '/set  設定與維護（編輯短語／指令清單、'/v '/g '/gc）
  reg.register_exact("case", hier_menu("case"))                                        -- '/case 字母大小寫（'// '/; '/'）
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
  reg.register_matcher(bare_prefix)  -- 裸代碼前綴搜尋（'/gi → '/git）
  reg.register_exact("v", ver)
  reg.register_exact("g", garbage)
  reg.register_exact("gc", garbage_collect)
end

return { register = register, register_direct = register_direct }
