--- @@ schema_cycle
--[[
單按「右 Shift」循環切換語言方案（注音 → 日文 → 韓文 → 英文 → … → 回到注音）。

■ 為什麼要自己寫
  想要的是系統內建輸入法那種「按一下就換下一個語言」的手感，但 RIME 內建做不到：
  ‧ key_binder 只能綁「有按鍵值的鍵」，不能綁「單按一個修飾鍵」。
  ‧ ascii_composer/switch_key 可以認單按 Shift，但它只會切中英，不會切方案。
  ‧ key_binder 的 `select: .next` 不是循環：它選的是方案選單的第 2 項，而選單永遠把
    「目前的方案」排第 1，所以只會在兩個方案之間來回跳。

■ 怎麼判定「單按」
  右 Shift 按下 → 記一筆；中間按了任何別的鍵（＝拿它當一般 Shift 打大寫／符號）→ 取消；
  右 Shift 放開時那一筆還在 → 才算單按。正在組字（有編碼沒上屏）時不切，免得打到一半的字不見。

■ 循環順序＝方案選單的順序（default.yaml 的 schema_list，安裝選項 langs 決定有哪些），
  但跳過 na_default.yaml 的 schema_cycle/skip 列出的方案 —— 注音文、全形、符號這類
  「偶爾才用」的方案如果也排進循環，要按八九下才繞得回注音，就不順了；它們仍可從方案選單選。
  兩份清單都從 build/default.yaml 讀，那是部署後的最終結果，已經套完所有 patch。

■ 要掛在「每一個」會出現在選單裡的方案的 engine/processors 最前面：
  切過去之後是由新方案自己的 processor 鏈接手，沒掛的方案就切不走了。
  na_default.yaml 的 switch_key 也要把 Shift_R 設成 noop，否則右 Shift 同時會切中英。

■ 想換成別的鍵：改下面的 CYCLE_KEY（例如右 Ctrl 是 0xffe4），並把 switch_key 裡對應的鍵設成 noop。
--]]

local CYCLE_KEY = 0xffe2   -- Shift_R

local kAccepted, kNoop = 1, 2

-- 從部署後的 build/default.yaml 讀方案清單。librime 寫出來的格式固定是：
--   schema_list:
--     - schema: bopomo_onionplus
-- 以及要跳過的方案：
--   schema_cycle:
--     skip:
--       - allbpm
local function load_schema_list()
  local all, skip = {}, {}
  local path = rime_api.get_user_data_dir() .. "/build/default.yaml"
  local f = io.open(path, "r")
  if not f then return all end
  local section = nil
  for line in f:lines() do
    local top = line:match("^([%w_]+):")
    if top then
      section = top   -- 進入新的頂層鍵
    elseif section == "schema_list" then
      local id = line:match("^%s+%-%s*{?%s*schema:%s*([%w_%.%-]+)")
      if id then all[#all + 1] = id end
    elseif section == "schema_cycle" then
      local id = line:match("^%s+%-%s*([%w_%.%-]+)%s*$")
      if id then skip[id] = true end
    end
  end
  f:close()
  local list = {}
  for _, id in ipairs(all) do
    if not skip[id] then list[#list + 1] = id end
  end
  return list
end

local function init(env)
  env.schema_list = load_schema_list()
  env.pending = false
end

local function next_schema_id(env)
  local list = env.schema_list
  if #list < 2 then return nil end
  local current = env.engine.schema.schema_id
  for i, id in ipairs(list) do
    if id == current then
      return list[i % #list + 1]
    end
  end
  return list[1]   -- 目前的方案不在循環裡（從方案選單選了被跳過的方案）→ 回到第一個
end

local function processor(key, env)
  if key.keycode ~= CYCLE_KEY then
    -- 按了別的鍵＝右 Shift 是拿來當修飾鍵用的，不算單按。放開別的鍵不影響。
    if not key:release() then env.pending = false end
    return kNoop
  end

  if not key:release() then
    -- 帶著其他修飾鍵（Ctrl+Shift、Alt+Shift…）是系統或別的快捷鍵，不碰
    env.pending = not (key:ctrl() or key:alt() or key:super())
    return kNoop
  end

  -- 右 Shift 放開
  if not env.pending then return kNoop end
  env.pending = false
  if env.engine.context:is_composing() then return kNoop end

  local id = next_schema_id(env)
  if not id then return kNoop end

  -- 記住選擇：新開的視窗（新的 session）會沿用最後選的方案，行為才跟用方案選單切換一致。
  -- Switcher 型別較新的 librime-lua 才有，沒有就略過（只影響「新視窗沿用」這一點）。
  pcall(function()
    local sw = Switcher(env.engine)
    if sw.user_config then
      sw.user_config:set_string("var/previously_selected_schema", id)
      sw.user_config:set_int("var/schema_access_time/" .. id, os.time())
    end
  end)

  -- ⚠ apply_schema 會把目前這條 processor 鏈整個換掉（包含正在執行的這個元件），
  --   所以它之後不可以再碰 env，直接回 kAccepted 讓引擎停止往下傳。
  env.engine:apply_schema(Schema(id))
  return kAccepted
end

return { init = init, func = processor }
