--[[
「指令與快捷開啟」選單（'/j）的列表產生器。

輸出格式與 mf_components/mf_menu_data.lua 的選單列一致：
  key    這一列的代碼（不含前綴），同時是候選文字 —— 顯示成 '/jh、'/jgit 這樣，
         讓你看得到指令、下次可以直接打。
  label  說明文字
  run    有值就代表「選中即執行」，值為 p_run_pattern 裡的鍵

⚠ 候選文字（'/ + key）在同一份選單裡必須唯一：engine/filters 末端的 uniquifier
  會把文字相同的候選合併掉。舊版用 ⓿❶❷ 這種圈圈數字當文字就是為了閃這個，
  現在改用代碼本身，唯一而且有資訊量。

排序：先照 p_run_pattern 各條目的 s（自訂順序），s 相同再照代碼字母序。
--]]

local NS = "j"   -- 指令命名空間（join，上游沿用）。⚠ 別改成 c：'/c 已是「內碼十進制」
                 --   的代碼、'/cs 是 devkit 命名風格轉換，改 c 會被靜默遮蔽。

local function run_menu(pattern)
  local rows = {}
  for code, v in pairs(pattern) do
    rows[#rows + 1] = {
      key   = NS .. code,
      run   = code,
      label = v.name or code,
      _s    = v.s or 100,
    }
  end

  -- 兩個方案內建檔案的編輯捷徑（動作寫在 processor 裡，不在 p_run_pattern）。
  -- 沒有 run，選中會先把輸入變成 '/jt、'/jc，再按一次空白才執行。
  -- ⚠ Windows 端 p_run_pattern 有自己的 "c"（指定用 Notepad++ 開），
  --   那時上面的迴圈已經產生 '/jc 這一列，這裡就不能再加，否則兩列文字相同會被 uniquifier 併掉。
  -- _s 跟 p_run_pattern 的 s 共用同一個刻度，且在排序「之前」就補進去 ——
  -- 這樣 Mac（走這裡補 '/jc）與 Windows（走 p_run_pattern 的 c）列序才會一致。
  if pattern["c"] == nil then
    rows[#rows + 1] = { key = NS .. "c", _s = 2, label = "編輯 自訂短語（打 email 出信箱那種）" }
  end
  if pattern["t"] == nil then
    rows[#rows + 1] = { key = NS .. "t", _s = 90, label = "編輯 指令清單（p_run_pattern.lua）" }
  end

  -- 排序：先照 s（自訂順序），s 相同再照代碼字母序
  table.sort(rows, function(a, b)
    if a._s == b._s then return a.key < b.key end
    return a._s < b._s
  end)

  return rows
end

return run_menu
