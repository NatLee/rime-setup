--[[
projector(格式1, 格式2, …) → function(字串) 回傳轉換後的字串

把一串 Rime 的拼寫運算（"xlit|abc|ＡＢＣ|"、"xform|[.]/| |" …）包成一個可以直接呼叫的轉換函式。
給「把一段文字換成另一套字型／符號」這類純轉換用（英文字母樣式、數字樣式…）。

■ 為什麼要有這一層
  原本每個樣式各寫一個函式，內容都是同一個樣板：
      if t == "" then return "" end
      local proj = convert_format(格式…)   -- ← 每呼叫一次就重建一個 Projection
      return proj:apply(t)
  三十幾個函式只差在格式字串，而且 Projection 每次呼叫都重建。
  這裡把樣板收成一個工廠，Projection 只在第一次用到時建一次、之後重複使用。

■ 為什麼是「第一次用到時」才建，不是 require 當下就建
  這些模組在輸入法服務啟動時就被 require，樣式有三十幾種，大多數人一輩子用不到幾種。
  延後到用的時候才建，啟動時不必付這筆成本。
--]]

local convert_format = require("filter_cand/convert_format")

local function projector(...)
  local formats = { ... }
  local proj
  return function(text)
    if text == "" then return "" end
    proj = proj or convert_format(table.unpack(formats))
    return proj:apply(text)
  end
end

return projector
