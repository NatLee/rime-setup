--- @@ p_select_keys
--[[
⇧1~⇧6 選字 —— 取代 RIME 內建的 menu/alternative_select_keys。

■ 為什麼不用內建的 menu/alternative_select_keys（macOS 會壞）
  librime 會把「選字鍵」與「選字標籤」兩份資料都交給前端
  （RimeContext.menu.select_keys 與 RimeContext.select_labels），
  但兩邊前端取用的優先序剛好相反：
    ‧ 小狼毫 RimeWithWeasel.cpp        ：select_labels 優先，沒有才退回 select_keys
    ‧ 鼠鬚管 SquirrelInputController.swift：**select_keys 優先**，有值就不看 labels
  所以只要設了 alternative_select_keys，macOS 的候選標籤永遠是 !@#$%^，
  怎麼改 alternative_select_labels 都沒用。
  → select_keys 一律留空（兩邊就都會拿 labels，顯示 ⇧1~⇧6），選字由這裡接手。

■ 為什麼不用 key_binder 把 ⇧1~⇧6 轉成 KP_1~KP_6（試過，會壞）
  librime 的 selector 對小鍵盤數字有獨立分支（keycode ≥ 0x7f，不比對 select_keys），
  看起來可以借用，但 mix_apc_s2rm_ltk 會在 '/ 計算機／純數字模式把 KP_n 當成
  「用小鍵盤打數字」塞進輸入：'/12345 按 ⇧2 會變成 '/123452，選不到「12,345」。
  上游那個小鍵盤功能與選字鍵搶同一批 keycode，無法共存。

■ 掛載位置（engine/processors）：recognizer 之後、speller／selector 之前
  ‧ 要在 recognizer **之後**：'@' 會被 email 樣式（^[a-z][-_.0-9a-z]*@.*$）接走
    去打信箱，那是上游刻意的設計。搶在它前面會打不出 email；代價是「輸入以
    英文字母開頭時 ⇧2 選不到字」（su3 按 ⇧2 → 輸入變成 su3@）——
    這個現象在改用本 processor 之前就存在，不是本次改動造成的。
  ‧ 要在 speller／selector **之前**：行為才與原本 selector 比對 select_keys 一致。
  ‧ 要在 punctuator 之前：否則沒選到字時 '!' 會先被轉成「！」。
  ‧ '/ 分層選單那幾頁不會走到這裡：p_run_files 排在鏈首、已先把選字鍵接走
    （它讀的是同一個 p_select_keys/keys 設定）。

⚠ 元件名 p_select_keys 必須在 rime.lua 有 bind，否則 yaml 那行等於沒寫（靜默失效）。
--]]

local key_util = require("p_components/p_key_util")

local function init(env)
  local config = env.engine.schema.config
  -- 選字鍵字串，第 n 個字元 = 該頁第 n 列。namespace 即 yaml 的 lua_processor@p_select_keys
  env.keys = config:get_string(env.name_space .. "/keys") or ""
  -- 選字鍵給的是「當頁第幾個」，換算絕對序號要知道一頁幾列
  env.page_size = config:get_int("menu/page_size") or 6
end

local function processor(key, env)
  if env.keys == "" then return 2 end
  --- pass release ctrl alt super（Shift 不能排除：選字鍵本身就是 Shift+數字）
  if not key_util.is_plain_press(key) then return 2 end

  local context = env.engine.context
  if not context:has_menu() then return 2 end          -- 沒候選就不動作，'!' 照常上屏「！」

  local n = key_util.select_index(key, env.keys)
  if not n then return 2 end

  local comp = context.composition
  if comp:empty() then return 2 end                    -- 空 composition 呼叫 back() 是未定義行為
  local seg = comp:back()
  if seg:has_tag("raw") then return 2 end              -- 與 librime selector 的判斷一致

  -- ⇧1 是「這一頁的第 1 列」；翻到第 2 頁要補上該頁起始的絕對序號
  if context:select(key_util.page_base(seg, env.page_size) + n - 1) then
    return 1  -- kAccepted（select 會觸發 engine 的 OnSelect，該上屏就上屏）
  end
  return 2    -- 該頁沒有第 n 列（最後一頁不滿），交還給後面的 processor
end

return { init = init, func = processor }
