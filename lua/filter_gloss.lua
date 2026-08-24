--- @@ gloss_filter
--[[
三語可切換候選釋義濾鏡（取代 reverse_lookup_filter@jp_gloss 與 @e_reverse_lookup）。

排版統一為「候選字大、右側小字註解、最多兩行」：
  開頭補全形空格「　」、兩義之間以「\n　」換行（Weasel 支援 comment 換行），
  每義超過 30 個顯示字元（utf8.len）截斷加「…」，最多取 2 義。

作用段落（tags_match）：
  abc（僅 jpnin1 方案，以 schema_id 判斷）、japan → 查日文釋義詞典，
    語言由 radio 選項 gloss_zh / gloss_en / gloss_ja 決定（皆未設視同 gloss_zh），
    所選語言查無 → 依 zh → en → ja 順序 fallback。
  easy_en → 查 easy_en_lcomment（英文詞維持單一來源，不受語言切換影響）。

詞典（反查碼中「@」代空格、「@@」代多義分行；同詞多行時 lookup 以空格連接）：
  gloss_zh → jpnin1_gloss_zh（日本語 WordNet ＋ CWN(Taiwan)/COW，synset 對齊）
  gloss_en → jpnin1_gloss   （JMdict 日英）
  gloss_ja → jpnin1_gloss_ja（日本語 WordNet 日語定義句 def_ja）

查無釋義 → comment 設為空字串（蓋掉補全提示雜訊；easy_en 原本 comment_format
即清掉未完成碼提示，比照）。惟 convert_japan_filter / convert_english_filter
產生的轉換候選（simp_jp / simp_en）保留其原標籤：simp_en 不查（維持〔開頭大寫〕
等提示），simp_jp 查得到才覆寫（假名轉換形有些查得到釋義）。

ReverseLookup 建構以 pcall 防護（詞典未編譯時不可讓整個方案掛掉）。
狀態全部存 env.xxx，不用全域（防多方案互踩）。
--]]

----------------------------------------------------------------------------------------
local change_comment = require("filter_cand/change_comment")
----------------------------------------------------------------------------------------

local MAX_SENSES = 2    -- 最多兩行
local MAX_WIDTH  = 44   -- 每義最多顯示寬度（全形字算 2、半形算 1，故約 22 個中日文字）
local PAD        = "　" -- 行首全形空格：候選字與小字註解間留距


-- 單一碼點的顯示寬度：CJK／假名／諺文／全形符號算 2，其餘算 1。
-- 用字元數截斷會使中日文註解比英文寬一倍，故改以顯示寬度計。
local function cp_width(cp)
  if (cp >= 0x1100 and cp <= 0x115F)
    or (cp >= 0x2E80 and cp <= 0xA4CF)   -- 部首、假名、CJK
    or (cp >= 0xAC00 and cp <= 0xD7A3)   -- 諺文
    or (cp >= 0xF900 and cp <= 0xFAFF)   -- CJK 相容
    or (cp >= 0xFE30 and cp <= 0xFE6F)   -- CJK 相容形式
    or (cp >= 0xFF00 and cp <= 0xFF60)   -- 全形 ASCII
    or (cp >= 0xFFE0 and cp <= 0xFFE6)
    or (cp >= 0x20000 and cp <= 0x3FFFD) -- CJK 擴充
  then
    return 2
  end
  return 1
end


-- 依顯示寬度截斷，超出加「…」；非法 UTF-8 時原樣回傳（不讓濾鏡中斷）
local function truncate_disp(s, maxw)
  local ok, res = pcall(function()
    local w, buf = 0, {}
    for _, cp in utf8.codes(s) do
      local cw = cp_width(cp)
      if w + cw > maxw then
        return table.concat(buf) .. "…"
      end
      w = w + cw
      buf[#buf + 1] = utf8.char(cp)
    end
    return s
  end)
  return ok and res or s
end


-- 反查碼還原＋排版：@→空格、@@ 切分多義，取前 2 義，每義 30 字元截斷。
-- 查無（nil / ""）回傳 nil。
local function format_gloss(raw)
  if not raw or raw == "" then return nil end
  local senses = {}
  for code in raw:gmatch("%S+") do            -- 同詞多行：lookup 以空格連接各碼
    for sense in (code .. "@@"):gmatch("(.-)@@") do  -- 「@@」切分多義
      sense = sense:gsub("@", " "):gsub("^%s+", ""):gsub("%s+$", "")
      if sense ~= "" then
        local dup = false
        for _, s in ipairs(senses) do
          if s == sense then dup = true break end
        end
        if not dup then
          senses[#senses + 1] = truncate_disp(sense, MAX_WIDTH)
          if #senses >= MAX_SENSES then break end
        end
      end
    end
    if #senses >= MAX_SENSES then break end
  end
  if #senses == 0 then return nil end
  return PAD .. table.concat(senses, "\n" .. PAD)
end


-- 依語言順序查日文釋義詞典，回傳排版後 comment 或 nil
local function lookup_jp(env, order, text)
  for _, rl in ipairs(order) do
    if rl then
      local gloss = format_gloss(rl:lookup(text))
      if gloss then return gloss end
    end
  end
  return nil
end


local function safe_rl(dict_name)
  local ok, rl = pcall(ReverseLookup, dict_name)
  if ok then return rl end
  log.warning("gloss_filter: ReverseLookup(" .. dict_name .. ") 建構失敗（詞典未編譯？）")
  return nil
end


local function init(env)
  local config = env.engine.schema.config
  local schema_id = config:get_string("schema/schema_id") or ""
  env.is_jpnin1 = (schema_id == "jpnin1")
  env.rl_zh   = safe_rl("jpnin1_gloss_zh")
  env.rl_en   = safe_rl("jpnin1_gloss")
  env.rl_ja   = safe_rl("jpnin1_gloss_ja")
  env.rl_easy = safe_rl("easy_en_lcomment")
end


local function tags_match(seg, env)
  if seg:has_tag("easy_en") then
    env.seg_kind = 1  -- easy_en
    return true
  end
  if seg:has_tag("japan") or (env.is_jpnin1 and seg:has_tag("abc")) then
    env.seg_kind = 2  -- 日文段落
    return true
  end
  return false
end


local function filter(inp, env)
  if env.seg_kind == 1 then
    ---- easy_en：單一英文釋義來源，語言切換不影響
    local rl = env.rl_easy
    for cand in inp:iter() do
      if cand.type == "simp_en" then  -- convert_english_filter 轉換候選：保留原標籤
        yield(cand)
      else
        local gloss = rl and format_gloss(rl:lookup(cand.text)) or nil
        yield(change_comment(cand, gloss or ""))
      end
    end
  else
    ---- japan / jpnin1-abc：依 radio 選項決定語言，查無依 zh→en→ja fallback
    local context = env.engine.context
    local order
    if context:get_option("gloss_en") then
      order = { env.rl_en, env.rl_zh, env.rl_ja }
    elseif context:get_option("gloss_ja") then
      order = { env.rl_ja, env.rl_zh, env.rl_en }
    else  -- gloss_zh 或皆未設：預設中文
      order = { env.rl_zh, env.rl_en, env.rl_ja }
    end
    for cand in inp:iter() do
      if cand.type == "simp_jp" then  -- convert_japan_filter 轉換候選：查得到才覆寫
        local gloss = lookup_jp(env, order, cand.text)
        yield(gloss and change_comment(cand, gloss) or cand)
      else
        yield(change_comment(cand, lookup_jp(env, order, cand.text) or ""))
      end
    end
  end
end


return { init = init, func = filter, tags_match = tags_match }
