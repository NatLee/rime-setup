----------------------------------------------------------------------------------------
--- 代碼註冊表與調度器（core/registry）
---
--- register_exact(code, handler)：註冊精確代碼（code 不含 prefix；"" 表 prefix 單獨）。
--- register_matcher(handler)：註冊 pattern 型 handler，依註冊順序組成 matcher 鏈
---（順序＝原始大 if 鏈順序，順序語義不可變）。
--- dispatch(input, seg, env, ctx)：剝除 env.prefix 後先查精確表（O(1)），
--- 未命中再依序跑 matcher 鏈。handler 簽名皆為 (input, seg, env, ctx)，
--- 有處理到（原程式碼該處為 return）就回 true，調度即結束。
---
--- 遮蔽關係說明：原 if 鏈中位於精確代碼之前的 matcher 只有「j[a-z]+」，
--- 它要求 j 開頭且後接字母，與任何精確代碼（含 v/g/gc、日期時間各碼）無交集，
--- 故「先精確後 matcher」與原順序語義等價（以回歸測試逐條驗證）。

local fmt = require("mf_components/core/fmt")

local M = {}

local exact = {}
local matchers = {}

function M.register_exact(code, handler)
  exact[code] = handler
end

--- 某個精確代碼是否已經有人註冊。給 mf_menu_data 的「裸代碼前綴搜尋」判斷用：
--- 代碼本身有 handler（'/f、'/de 這些日期碼）就不能改成選單，否則功能會被吃掉。
function M.has_exact(code)
  return exact[code] ~= nil
end

function M.register_matcher(handler)
  matchers[#matchers + 1] = handler
end

--- 將整份規格表逐碼註冊為精確代碼（別名碼＝同一規格的多個鍵）
local render = require("mf_components/core/render")
function M.register_specs(specs)
  for code in pairs(specs) do
    M.register_exact(code, render.make_handler(specs, code))
  end
end

function M.dispatch(input, seg, env, ctx)
  fmt.reset()  -- per-dispatch 記憶化：每次按鍵重算一次
  local prefix = env.prefix
  if prefix and string.sub(input, 1, #prefix) == prefix then
    local h = exact[string.sub(input, #prefix + 1)]
    if h and h(input, seg, env, ctx) then return true end
  end
  for i = 1, #matchers do
    if matchers[i](input, seg, env, ctx) then return true end
  end
  return false
end

return M
