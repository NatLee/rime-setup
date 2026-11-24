--- @@ mix_apc_s2rm_ltk
--[[
注音主方案（bopomo_onionplus）的按鍵調度。名字是上游三個 processor 合併後的縮寫：
  apc  ascii_punct_change  英文標點模式下，Shift+, Shift+. 直接出半形 , .
  s2rm space → return      掛接語言（英／日／韓…）的段落按空白／Enter 時的上屏修正
  ltk  lua_tran_kp         '/ 計算機裡，小鍵盤可以輸入數字與運算符

（'/ 指令的「選中即執行」不在這裡，在排在更前面的 processor_p_run_files.lua。
  舊版這裡還有一段 '/j<代碼> 的開檔邏輯，那個命名空間已經退役，連同程式一起移除。）
--]]

local key_util = require("p_components/p_key_util")

local kAccepted, kNoop = 1, 2

-- 「前綴掛接」的語言段落：tag → 該段落前綴在方案設定裡的路徑。
-- 順序即判斷的優先序。新增一種掛接語言，在這裡加一列即可。
local PREFIXED_SEGMENTS = {
  { "japan",           "japan/prefix" },
  { "cyr2",            "cyr2/prefix" },
  { "gr2",             "gr2/prefix" },
  { "fs2",             "fs2/prefix" },
  { "reverse2_lookup", "reverse2_lookup/prefix" },
  { "european",        "european/prefix" },
  { "korea",           "korea/prefix" },
  { "easy_en",         "easy_en/prefix" },
  { "emoji_series",    "emoji_series/prefix" },
}

-- 小鍵盤按鍵（KP_ 後面那段）→ 要送進輸入碼的字元
local KEYPAD = {
  ["0"] = "0", ["1"] = "1", ["2"] = "2", ["3"] = "3", ["4"] = "4",
  ["5"] = "5", ["6"] = "6", ["7"] = "7", ["8"] = "8", ["9"] = "9",
  Add = "+", Subtract = "-", Multiply = "*", Divide = "/", Decimal = ".",
}

-- 英文標點模式下，這兩個鍵直接出半形標點
local ASCII_PUNCT = { ["Shift+less"] = ",", ["Shift+greater"] = "." }

local function init(env)
  local config = env.engine.schema.config
  env.segment_prefix = {}
  for i, item in ipairs(PREFIXED_SEGMENTS) do
    env.segment_prefix[i] = { tag = item[1], prefix = config:get_string(item[2]) or "" }
  end
end

--- 目前段落若是前綴掛接的語言，回傳它的前綴；不是則回 nil。
local function prefix_of(seg, env)
  for _, item in ipairs(env.segment_prefix) do
    if seg:has_tag(item.tag) then return item.prefix end
  end
  return nil
end

--- '/ 計算機：小鍵盤輸入數字與運算符。
--- 只在「剛打完 '/（可帶負號、小數點）」或「已經是數字／算式」時才接手，
--- 否則小鍵盤照常給選字等其他用途。
local function keypad_input(context, c_input, repr)
  local ch = KEYPAD[string.match(repr, "^KP_([%d%a]+)$")]
  if not ch then return kNoop end

  local just_prefix = string.match(c_input, "'/[-]?[.]?$")
  local in_number = string.match(c_input, "'/[-]?[.]?%d+%.?%d*$")
                 or string.match(c_input, "'/[-.rq(]?[%d.]+[-+*/^asrvxqw()][-+*/^asrvxqw().%d]*$")
  if not just_prefix and not in_number then return kNoop end

  if string.match(ch, "[%d.-]") then        -- 數字、小數點、負號：任何時候都可以接
    context:push_input(ch)
    return kAccepted
  end
  if just_prefix then return kNoop end      -- 還沒有數字，+ * / 沒有意義
  if string.match(ch, "[+*/]") then
    context:push_input(ch)
    return kAccepted
  end
  return kNoop
end

local function processor(key, env)
  local engine = env.engine
  local context = engine.context
  if context:get_option("ascii_mode") then return kNoop end
  if not key_util.is_plain_press(key) then return kNoop end

  local repr = key:repr()

  -- ── 英文標點模式：Shift+, Shift+. 出半形 , . ──
  -- 要放在下面「沒在組字就略過」之前：沒在組字時也要能直接打出來。
  local punct = context:get_option("ascii_punct") and ASCII_PUNCT[repr]
  if punct then
    if context:is_composing() then
      engine:commit_text(context:get_commit_text() .. punct)
    else
      engine:commit_text(punct)
    end
    context:clear()
    return kAccepted
  end

  -- 空 composition 呼叫 back() 是未定義行為（會 core dumped），先擋掉
  local comp = context.composition
  if comp:empty() then return kNoop end
  if not context:is_composing() then return kNoop end
  local seg = comp:back()
  -- 一般注音／注音文的段落完全交給內建元件，這裡不插手
  if seg:has_tag("abc") or seg:has_tag("all_bpm") then return kNoop end

  local c_input = context.input
  local caret_pos = context.caret_pos

  -- ── 確認鍵（空白／Enter）：掛接段落的上屏修正 ──
  if key_util.is_confirm(repr) then
    if #c_input == caret_pos then
      -- 加這個限定是防止游標移到中間時不能翻頁選字
      if seg:has_tag("paging") then return kNoop end
      context:confirm_current_selection()   -- 用 confirm 而不是 commit_text：這樣詞頻才會被記住
      return kAccepted
    end

    -- 游標在編碼中間：上屏已選的部分，沒選到的編碼補回前綴重新輸入。
    -- 不補前綴的話，剩下的編碼會跳回主方案被當成注音。
    local prefix = prefix_of(seg, env)
    if prefix then
      local commit_text = context:get_commit_text()
      local cand = context:get_selected_candidate()
      engine:commit_text(string.sub(commit_text, 1, #commit_text + cand._end - caret_pos))
      -- 末尾還沒被選到的輸入碼長度
      local retain = #c_input - cand._end
      context.input = prefix .. string.sub(c_input, -retain)
      return kAccepted
    end
    return kNoop
  end

  -- ── '/ 計算機的小鍵盤 ──
  if seg:has_tag("mf_translator") then
    return keypad_input(context, c_input, repr)
  end

  return kNoop
end

return { init = init, func = processor }
