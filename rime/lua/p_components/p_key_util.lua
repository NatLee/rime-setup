--[[
processor 共用的按鍵判斷小工具。

幾個 processor（p_run_files、p_select_keys、mix_apc_s2rm_ltk）都要回答同樣的問題：
「這是不是該略過的鍵？」「這是不是確認鍵？」「這個鍵是第幾個選字鍵？」「目前這一頁從第幾列開始？」
原本各寫各的，條件只要有一處改了另一處沒改，行為就會悄悄分岔。集中在這裡。
--]]

local M = {}

--- 是不是「單純按下一個鍵」：放開鍵的事件、帶 Ctrl／Alt／Super 的組合鍵都不算。
--- （Shift 不排除 —— ⇧1~⇧6 選字、Shift+, 這些正是要處理的。）
function M.is_plain_press(key)
  return not (key:release() or key:ctrl() or key:alt() or key:super())
end

--- 是不是確認鍵（空白、Enter、小鍵盤 Enter）。傳入 key:repr() 的結果。
function M.is_confirm(repr)
  return repr == "space" or repr == "Return" or repr == "KP_Enter"
end

--- 這個鍵是選字鍵字串 keys（例如 "!@#$%^"）的第幾個；不是選字鍵則回 nil。
--- 用 plain find：選字鍵裡的 $ ^ 等字元不可以被當成樣式符號。
function M.select_index(key, keys)
  if not keys or keys == "" then return nil end
  local kc = key.keycode
  if not kc or kc < 0x20 or kc >= 0x7f then return nil end
  return string.find(keys, string.char(kc), 1, true)
end

--- 目前高亮那一頁的第一列是整份候選的第幾個（0 起算）。
--- 選字鍵給的是「當頁第幾個」，換算成絕對序號要加上這個。
function M.page_base(seg, page_size)
  return page_size * math.floor((seg.selected_index or 0) / page_size)
end

return M
