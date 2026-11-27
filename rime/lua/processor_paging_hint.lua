--- @@ paging_hint
--[[
翻頁提示（macOS）：候選不只一頁時，在編碼列後面顯示頁碼，前後還有候選的那一邊加 ‹ ›。

    ㄋㄧˇ  1 ›        第一頁（後面還有）
    ㄋㄧˇ  ‹ 2 ›      中間的頁
    ㄋㄧˇ  ‹ 3        最後一頁
    （只有一頁：什麼都不顯示）

■ 為什麼 Mac 要自己做
  鼠鬚管內建的 show_paging 是兩個浮在候選窗「外面」左邊的三角形，還會把候選窗往右推
  「標籤字級 ×1.5」，跟游標對不齊；位置、形狀、顏色都沒有鍵可以調（原委見 docs/GOTCHAS.md「翻頁提示」）。
  Windows 不需要這支：小狼毫內建的 < > 在編碼列右側、可以點，直接用它（na_weasel.yaml）。
  所以這支只在鼠鬚管上作用，小狼毫（含 rime-test.ps1 的沙盒，它也自稱 Weasel）上 init 什麼都不做。

■ 為什麼長這樣
  只能用文字（改的是編碼列），顏色就是編碼列的文字色。試過幾種（用 CoreText 照實際字型畫出來比）：
  ‧ ◂▸◃▹、◀▶◁▷：不在中文字型裡，各自掉到不同的後備字型，空心跟實心大小差一大截。
  ‧ ▲▼△▽：大小一致，但實心三角形太重，搶過編碼本身。
  ‧ ‹ ›＋頁碼：跟文字同一套字形、線條輕，讀起來就是一般的分頁器，還看得出在第幾頁。
    總頁數不顯示：要知道總數得把整個候選清單算完，候選多的時候很慢。

■ 怎麼做到的
  不攔任何按鍵（func 永遠回 kNoop）。init 時掛上 context 的兩個通知，在通知裡改最後一個段落的 segment.prompt：
  ‧ update_notifier：組字、換候選、翻頁（Selector 翻頁是呼叫 Context::Highlight，會觸發它）之後。
  ‧ select_notifier：只選了前半段（例如 ㄋㄧˇㄏㄠˇ 先選「你」）時，引擎直接重新組字、不發 update，
    不掛它的話剩下那段的提示要等下一個按鍵才出現。引擎自己的處理先掛、先跑，所以輪到這裡時新的候選已經在了。
  librime 組編碼列時會把 prompt 接在游標後面（Composition::GetPreedit），所以提示出現在候選窗裡的編碼列，
  不動候選字和註解，也不會跟著上屏。
  ‧ prompt 可能本來就有內容（例如前綴掛接的「《日》▶」），所以是「接在後面」，每次先把自己上次加的拿掉。
  ‧ 游標不在最後（← 移進編碼中間）時不顯示：prompt 是插在游標位置的，會把編碼列切成兩半。
  ‧ 編碼列直接顯示在 App 裡（inline_preedit，或 app_options 的 inline）時不顯示，否則「1 ›」會出現在
    使用者的文件裡。怎麼知道：鼠鬚管自己算好要不要 inline，把結果寫進 librime 的 soft_cursor 選項
    （在候選窗裡顯示＝true，見 SquirrelInputController.swift 的 rimeUpdate）。它是在換方案後才設的，
    所以也掛 option_update_notifier，換方案後的第一個鍵就跟著對。
  ‧ 候選自己也可能在編碼列後面接一段（preedit 裡 \t 後面那段，例如英文方案的「（個排：字數）」），
    librime 把 prompt 插在那段前面、改不了，所以這時提示後面也空兩格，讀起來是三段而不是黏在一起：
        ab  1 ›  （個排：字數）
  ‧ 要知道「還有沒有下一頁」只多準備一個候選（menu:prepare 到下一頁第一個），不會把整個清單翻完。

■ 開關：安裝選項（'/setup 的「翻頁提示」），預設值在 na_style.yaml 的 paging_hint。
  方案設定讀不到 na_style（放進方案會讓「換主題」也重編所有方案，見 na_style.yaml 檔頭），所以
  squirrel.custom.yaml 把它帶進前端設定的頂層 na_paging_hint，這裡從部署後的 build/squirrel.yaml 讀
  （同 processor_schema_cycle 讀 build/default.yaml 的做法）。讀不到就當成「開」。
  關掉時 init 不掛通知，等於沒有這個元件。

■ 要掛在每一個選單方案的 engine/processors（跟 schema_cycle 同一批方案）；放哪個位置都可以，它不吃鍵。
--]]

local key_util = require("p_components/p_key_util")

local kNoop = 2

local GAP = "  "          -- 編碼與提示之間
local PREV, NEXT = "‹ ", " ›"

-- 上次可能加上去的提示，拿掉時比對用（長的先比）。‹ › 是多位元組字元，在 lua 的 pattern 裡照字面比對。
local OURS = {
  GAP .. PREV .. "%d+" .. NEXT .. GAP .. "$", GAP .. PREV .. "%d+" .. NEXT .. "$",
  GAP .. PREV .. "%d+" .. GAP .. "$",         GAP .. PREV .. "%d+$",
  GAP .. "%d+" .. NEXT .. GAP .. "$",         GAP .. "%d+" .. NEXT .. "$",
}

local function strip_hint(s)
  for _, pat in ipairs(OURS) do
    local i = s:find(pat)
    if i then return s:sub(1, i - 1) end
  end
  return s
end

-- 只在鼠鬚管上作用；開關是 build/squirrel.yaml 頂層的 na_paging_hint（讀不到＝開，跟 na_style.yaml 一致）
local function enabled()
  local ok, dist = pcall(function() return rime_api.get_distribution_code_name() end)
  if not ok or dist ~= "Squirrel" then return false end
  local f = io.open(rime_api.get_user_data_dir() .. "/build/squirrel.yaml", "r")
  if not f then return true end
  local value = nil
  for line in f:lines() do
    value = line:match("^na_paging_hint:%s*(%a+)")
    if value then break end
  end
  f:close()
  return value ~= "false"
end

local function update(env, ctx)
  local comp = ctx.composition
  if comp:empty() then return end
  local seg = comp:back()
  local base = strip_hint(seg.prompt or "")
  local hint = ""
  local menu = seg.menu
  if menu and not menu:empty() and ctx.caret_pos == #ctx.input and ctx:get_option("soft_cursor") then
    local ps = env.page_size
    local start = key_util.page_base(seg, ps)   -- 當頁第一列的序號（跟其他 processor 用同一個算法）
    local page = math.floor(start / ps)
    local has_prev = page > 0
    local has_next = menu:prepare(start + ps + 1) > start + ps
    if has_prev or has_next then
      hint = GAP .. (has_prev and PREV or "") .. tostring(page + 1) .. (has_next and NEXT or "")
      local cand = ctx:get_selected_candidate()
      if cand and cand.preedit:find("\t", 1, true) then hint = hint .. GAP end
    end
  end
  if seg.prompt ~= base .. hint then seg.prompt = base .. hint end
end

local function init(env)
  if not enabled() then return end
  local ps = env.engine.schema.page_size
  env.page_size = (ps and ps > 0) and ps or 5
  local ctx = env.engine.context
  local on_change = function(c) update(env, c) end
  env.conns = {
    ctx.update_notifier:connect(on_change),
    ctx.select_notifier:connect(on_change),
    ctx.option_update_notifier:connect(function(c, name) if name == "soft_cursor" then update(env, c) end end),
  }
end

local function func(key, env)
  return kNoop
end

local function fini(env)
  for _, c in ipairs(env.conns or {}) do c:disconnect() end
  env.conns = nil
end

return { init = init, func = func, fini = fini }
