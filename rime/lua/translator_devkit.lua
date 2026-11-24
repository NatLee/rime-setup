--- @@ devkit_translator
--[[
開發者小工具（掛在 mf_translator 的「'/」段落上，與其並存）：
  '/ts             現在的 Unix 時間戳（秒／毫秒）
  '/ts<10或13位數>  時間戳轉日期時間（本地＋UTC）
  '/uuid           UUID v4（小寫／大寫）
  '/pw、'/pw<n>    隨機密碼（預設 16 碼，範圍 4~64，含大小寫數字符號）
  '/rgb<hex>       色碼轉換：#HEX / rgb() / RIME 設定用 BGR（支援 3 或 6 位 hex）
  '/cs<字.串>      命名風格轉換（單字用「.」或「-」分隔）
掛載：engine/translators 加 lua_translator@devkit_translator（沿用 mf_translator 的 recognizer/segmentor）
--]]

math.randomseed(os.time() % 2147483647 + math.floor(os.clock() * 1000000))

----------------------------------------------------------------------------------------

local function uuid4()
  return (string.gsub("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx", "[xy]", function(ch)
    local v = (ch == "x") and math.random(0, 15) or math.random(8, 11)
    return string.format("%x", v)
  end))
end

local pw_sets = {
  "abcdefghijkmnopqrstuvwxyz",  -- 去掉易混淆的 l
  "ABCDEFGHJKLMNPQRSTUVWXYZ",   -- 去掉易混淆的 I、O
  "23456789",                   -- 去掉易混淆的 0、1
  "!@#$%^&*-_=+?",
}
local pw_all = table.concat(pw_sets)

local function gen_pw(len)
  local out = {}
  for i = 1, 4 do  -- 大寫、小寫、數字、符號至少各一
    local s = pw_sets[i]
    local idx = math.random(1, #s)
    out[#out + 1] = string.sub(s, idx, idx)
  end
  for _ = 5, len do
    local idx = math.random(1, #pw_all)
    out[#out + 1] = string.sub(pw_all, idx, idx)
  end
  for i = #out, 2, -1 do  -- 洗牌
    local j = math.random(1, i)
    out[i], out[j] = out[j], out[i]
  end
  return table.concat(out)
end

local function capitalize(w)
  return string.upper(string.sub(w, 1, 1)) .. string.sub(w, 2)
end

----------------------------------------------------------------------------------------

local function init(env)
  local config = env.engine.schema.config
  env.prefix = config:get_string("mf_translator/prefix") or "'/"
end

local function translate(input, seg, env)
  if not seg:has_tag("mf_translator") then return end
  if string.sub(input, 1, #env.prefix) ~= env.prefix then return end
  local body = string.sub(input, #env.prefix + 1)
  if body == "" then return end

  local yield_c = function(text, comment)
    local cand = Candidate("devkit", seg.start, seg._end, text, comment or "")
    cand.quality = 100
    yield(cand)
  end

  --- '/ts：現在的時間戳
  if body == "ts" then
    local now = os.time()
    yield_c(tostring(now), "〔Unix 時間戳・秒〕")
    yield_c(tostring(now) .. "000", "〔Unix 時間戳・毫秒〕")

  --- '/ts<digits>：時間戳轉日期
  elseif string.match(body, "^ts%d+$") then
    local digits = string.match(body, "^ts(%d+)$")
    local sec = tonumber(digits)
    if #digits == 13 then sec = math.floor(sec / 1000) end
    if #digits == 10 or #digits == 13 then
      local ok_l, dt_local = pcall(os.date, "%Y-%m-%d %H:%M:%S", sec)
      local ok_u, dt_utc = pcall(os.date, "!%Y-%m-%d %H:%M:%S", sec)
      if ok_l and dt_local then yield_c(dt_local, "〔本地時間〕") end
      if ok_u and dt_utc then yield_c(dt_utc, "〔UTC〕") end
    else
      yield_c("", "〔時間戳需 10（秒）或 13（毫秒）位數〕")
    end

  --- '/uuid：UUID v4
  elseif body == "uuid" then
    local u = uuid4()
    yield_c(u, "〔UUID v4〕")
    yield_c(string.upper(u), "〔UUID v4・大寫〕")

  --- '/pw、'/pw<n>：隨機密碼
  elseif string.match(body, "^pw%d*$") then
    local len = tonumber(string.match(body, "^pw(%d+)$") or "") or 16
    if len < 4 then len = 4 elseif len > 64 then len = 64 end
    for i = 1, 3 do
      yield_c(gen_pw(len), "〔隨機密碼 " .. len .. " 碼・" .. i .. "〕")
    end

  --- '/rgb<hex>：色碼轉換（3 或 6 位）
  elseif string.match(body, "^rgb%x+$") then
    local h = string.match(body, "^rgb(%x+)$")
    if #h == 3 then h = string.gsub(h, "(%x)", "%1%1") end
    if #h == 6 then
      local r = tonumber(string.sub(h, 1, 2), 16)
      local g = tonumber(string.sub(h, 3, 4), 16)
      local b = tonumber(string.sub(h, 5, 6), 16)
      yield_c("#" .. string.upper(h), "〔HEX〕")
      yield_c(string.format("rgb(%d, %d, %d)", r, g, b), "〔CSS〕")
      yield_c(string.format("0x%02X%02X%02X", b, g, r), "〔RIME 設定用 BGR〕")
    else
      yield_c("", "〔色碼需 3 或 6 位 hex，如 rgb1a73e8〕")
    end

  --- '/cs<字.串>：命名風格轉換（. 或 - 分隔）
  elseif string.match(body, "^cs[a-z0-9.-]+$") then
    local words = {}
    for w in string.gmatch(string.match(body, "^cs(.+)$"), "[^.-]+") do
      words[#words + 1] = string.lower(w)
    end
    if #words > 0 then
      local caps = {}
      for i, w in ipairs(words) do caps[i] = capitalize(w) end
      local camel = words[1] .. table.concat(caps, "", 2)
      yield_c(camel, "〔camelCase〕")
      yield_c(table.concat(caps, ""), "〔PascalCase〕")
      yield_c(table.concat(words, "_"), "〔snake_case〕")
      yield_c(table.concat(words, "-"), "〔kebab-case〕")
      yield_c(string.upper(table.concat(words, "_")), "〔SCREAMING_SNAKE〕")
    end
  end
end

return { init = init, func = translate }
