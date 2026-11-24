----------------------------------------------------------------------------------------
--- 規格表渲染器（core/render）
---
--- specs[code] 為候選規格陣列，每項 { text_fn, comment }：
---   text_fn  零參閉包，回傳候選文字（呼叫時機＝該次按鍵渲染時）
---   comment  註釋字串；也可為零參閉包（動態註釋，如月相）
--- 特例：specs[code] 亦可為 function(yield_c)，供候選數量不定的分支
---（如節氣表）自行逐條 yield。
---
--- 候選一律以 ctx.yield_c 產生（type "simp_mf"，無 preedit 改寫）；
--- 需要 preedit／特殊 Candidate 的分支不進規格表，留在邏輯模組。

local function render(specs, code, yield_c)
  local items = specs[code]
  if items == nil then return false end
  if type(items) == "function" then
    items(yield_c)
    return true
  end
  for i = 1, #items do
    local it = items[i]
    local text = it[1]()          -- 截為單值（text_fn 內含 gsub 時會回傳兩值）
    local comment = it[2]
    if type(comment) == "function" then comment = comment() end
    yield_c(text, comment)
  end
  return true
end

--- 將 specs[code] 包成 registry 精確代碼 handler
local function make_handler(specs, code)
  return function(input, seg, env, ctx)
    return render(specs, code, ctx.yield_c)
  end
end

return { render = render, make_handler = make_handler }
