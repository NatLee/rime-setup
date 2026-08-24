----------------------------------------------------------------------------------------
--- Unicode 等各種字符編碼轉換

local utf8_sub = require("f_components/f_utf8_sub")

local utf8_out = require("f_components/f_utf8_out")

local url_encode = require("f_components/f_url_encode")

local url_decode = require("f_components/f_url_decode")

----------------------------------------------------------------------------------------
--- 內碼／URL encode 前導提示（原 translate() 內容純搬移）

local function tips(input, seg, env, ctx)
  local yield_c = ctx.yield_c
    if (input == env.prefix .. "x") then
      local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "  ~ [0-9a-f]+〔內碼十六進制 Hex〕(Unicode)")
      cand2.preedit = input .. "\t【內碼十六進制】▶"
      yield(cand2)
      return true
    end

    if (input == env.prefix .. "u") then
      local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "  ~ [0-9a-f]+〔內碼十六進制 Hex〕(Unicode)")
      cand2.preedit = input .. "\t【內碼十六進制】▶"
      yield(cand2)
      return true
    end

    if (input == env.prefix .. "c") then
      local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "  ~ [0-9]+〔內碼十進制 Dec〕")
      cand2.preedit = input .. "\t【內碼十進制】▶"
      yield(cand2)
      return true
    end

    if (input == env.prefix .. "o") then
      local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "  ~ [0-7]+〔內碼八進制 Oct〕")
      cand2.preedit = input .. "\t【內碼八進制】▶"
      yield(cand2)
      return true
    end

    if (input == env.prefix .. "i") then
      local cand2 = Candidate("simp_mf_tips", seg.start, seg._end, "", "  ~ [0-9a-f]+〔Percent/URL encoding〕")
      cand2.preedit = input .. "\t【Percent/URL encoding】▶"
      yield(cand2)
      return true
    end
  return false
end

----------------------------------------------------------------------------------------
--- u/x/c/o 內碼與 i URL encode/decode 分支（原 translate() 內容純搬移）

local function codes(input, seg, env, ctx)
  local yield_c = ctx.yield_c
    local utf_prefix = env.prefix
    local utf_input = string.match(input, utf_prefix .. "([xuco][0-9a-f]+)$")
    if utf_input then
      -- if (string.sub(input, 1, 2) ~= utf_prefix) then return end
      local dict = { c=10, x=16, u=16, o=8 } --{ u=16 } --{ d=10, u=16, e=8 }
      local snd = string.sub(utf_input, 1, 1)
      local n_bit = dict[snd]
      if n_bit == nil then return true end
      local str = string.sub(utf_input, 2)
      local c = tonumber(str, n_bit)
      if c == nil then return true end
      local utf_x = string.match(utf_input, "^x")
      local utf_u = string.match(utf_input, "^u")
      local utf_o = string.match(utf_input, "^o")
      local utf_c = string.match(utf_input, "^c")
      local fmt  -- 補 local，避免污染共用 lua state
      if utf_x then
        -- local fmt = "U"..snd.."%"..(n_bit==16 and "X" or snd)
        fmt = "  U+".."%X"
      elseif utf_u then
        fmt = "  U+".."%X"
      elseif utf_o then
        fmt = "  0o".."%o"
      else
        fmt = "  &#".."%d"..";"
      end
      -- 單獨查找(改用下面迴圈執行)
      -- local cand_ui_s = Candidate("simp_mf_utf", seg.start, seg._end, utf8_out(c), string.format(fmt, c) .. "  ( " .. url_encode(utf8_out(c)) .. " ）" )
      -- 排除數字太大超出範圍。正常範圍輸出已 string_char，故 0 直接可以限定。
      if (utf8_out(c) == 0) then
        local cand_ui_s = Candidate("simp_mf_utf", seg.start, seg._end, "", "〈超出範圍〉" )  --字符過濾可能會過濾掉""整個選項。
        cand_ui_s.preedit = utf_prefix .. snd .. " " .. string.upper(string.sub(utf_input, 2))
        yield(cand_ui_s)
        return true
      end
      -- 區間查找
      -- if (c*n_bit+n_bit-1 < 1048575) then  -- 補下一位，如：x8d70 為「走」，補 x8d70[0-f]。
      --   for i = c*n_bit, c*n_bit+n_bit-1 do
      if (c+16 <= 1048575) then  -- 補後面 16 碼，如：x8d70 為「走」，補 x8d7[0+16] 到 x8d80。
        for i = c, c+16 do
        -- for i = c+1, c+16 do
          local cand_ui_m = Candidate("simp_mf_utf", seg.start, seg._end, utf8_out(i), string.format(fmt, i) .. "  ( " .. url_encode(utf8_out(i)) .. " ）" )
          cand_ui_m.preedit = utf_prefix .. snd .. " " .. string.upper(string.sub(utf_input, 2))
          yield(cand_ui_m)
        end
        return true
      -- elseif c <= 1048575 and c+16 > 1048575 then  -- Unicode 編碼末尾。
      elseif (c <= 1048575) then  -- Unicode 編碼末尾。
        for i = c, 1048575 do
          local cand_ui_m = Candidate("simp_mf_utf", seg.start, seg._end, utf8_out(i), string.format(fmt, i) .. "  ( " .. url_encode(utf8_out(i)) .. " ）" )
          cand_ui_m.preedit = utf_prefix .. snd .. " " .. string.upper(string.sub(utf_input, 2))
          yield(cand_ui_m)
        end
        return true
      end
    end


    local urlencode_prefix = env.prefix .. "i"
    local urlencode_input = string.match(input, urlencode_prefix .. "([0-9a-z][0-9a-f]*)$")
    if urlencode_input then
      local preedit_urlencode = string.gsub(urlencode_input, "(..)", "%1 ")
      local urlencode_code = string.gsub(urlencode_input, "(%x%x)", "%%%1")
      local urlencode_code = string.gsub(urlencode_code, "(%x%x)(%x)$", "%1%%%2")
      local urlencode_code = string.gsub(urlencode_code, "^(%x)$", "%%%1")
      local urlencode_cand = url_decode(urlencode_input)

      local unfinished = string.match(urlencode_cand, "… $")
      local judge_unfinished  -- 補 local，避免污染共用 lua state
      if unfinished then
        judge_unfinished = "〈輸入未完〉"
      else
        judge_unfinished = ""
      end

      local cand_urlencode_error = Candidate("simp_mf_urlencode", seg.start, seg._end, "", urlencode_cand)  --字符過濾可能會過濾掉""整個選項。
      cand_urlencode_error.preedit = urlencode_prefix .. " " .. string.upper(preedit_urlencode)  --string.upper(urlencode_code)

      local cand_urlencode_sentence = Candidate("simp_mf_urlencode", seg.start, seg._end, urlencode_cand, judge_unfinished)
      cand_urlencode_sentence.preedit = urlencode_prefix .. " " .. string.upper(preedit_urlencode)  --string.upper(urlencode_code)

      local url_first_word = utf8_sub(urlencode_cand,1,1)
      local url_first_word_dec = utf8.codepoint(url_first_word)
      local cand_urlencode_single = Candidate("simp_mf_urlencode", seg.start, seg._end, url_first_word, string.format("  U+".."%X" ,url_first_word_dec) .. judge_unfinished)
      cand_urlencode_single.preedit = urlencode_prefix .. " " .. string.upper(preedit_urlencode)  --string.upper(urlencode_code)

      local cand_urlencode_code = Candidate("simp_mf_urlencode", seg.start, seg._end, string.upper(urlencode_code), "〔URL編碼〕")
      cand_urlencode_code.preedit = urlencode_prefix .. " " .. string.upper(preedit_urlencode)  --string.upper(urlencode_code)

      local is_error = string.match(urlencode_cand, "^〈輸入錯誤〉")
      if is_error then
      -- if (urlencode_cand == "〈輸入錯誤〉") then
        yield(cand_urlencode_error)
      elseif (urlencode_cand == url_first_word) then
        yield(cand_urlencode_single)
      -- elseif string.match(urlencode_cand, "^ …") then
      --   yield(cand_urlencode_sentence)
      else
        yield(cand_urlencode_sentence)
        -- yield(cand_urlencode_single)
      end
      yield(cand_urlencode_code)
      return true
    end

    -- local url_c_input = string.match(input, env.prefix .. "e([0-9a-z][0-9a-f]*)$")
    -- if url_c_input~=nil then
    --   local u_1 = string.match(url_c_input,"^([0-9a-f][0-9a-f][0-9a-f])$")
    --   local u_2 = string.match(url_c_input,"^([0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])$")
    --   local u_3 = string.match(url_c_input,"^([0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])$")
    --   local u_4 = string.match(url_c_input,"^([0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])$")
    --   if u_1 ~= nil or u_2 ~= nil or u_3 ~= nil or u_4 ~= nil then
    --     url_c_input = url_c_input .. "0"
    --   end
    --   local url_10 = url_decode(url_c_input)
    --   local uc_i = string.upper(string.sub(input, 4, 5)) .. " " .. string.upper(string.sub(input, 6, 7)) .. " " .. string.upper(string.sub(input, 8, 9)) .. " " .. string.upper(string.sub(input, 10, 11)) .. " " .. string.upper(string.sub(input, 12, 13)) .. " " .. string.upper(string.sub(input, 14, 15))
    --   local uc_i = string.gsub(uc_i, " +$", "" )
    --   if string.match(url_10, "無此編碼") ~= nil then
    --     yield_c( url_10, "" )
    --   elseif string.match(url_c_input, "^[0-9a-z]$") ~= nil then
    --     local cand_uci_a = Candidate("simp_mf_urlencode", seg.start, seg._end, url_10, url_10 )
    --     cand_uci_a.preedit = env.prefix .. "e " .. uc_i
    --     yield(cand_uci_a)
    --   else
    --     -- local u_c = string.upper(url_c_input)
    --     -- local u_c = string.gsub(u_c, '^', '%%')
    --     -- local u_c = string.gsub(u_c, '^(%%..)(..)', '%1%%%2')
    --     -- local u_c = string.gsub(u_c, '^(%%..%%..)(.+)', '%1%%%2')
    --     -- local u_c = string.gsub(u_c, '^(%%..%%..%%..)(.+)', '%1%%%2')
    --     -- local u_c = string.gsub(u_c, '^(%%..%%..%%..%%..)(.+)', '%1%%%2')
    --     -- local u_c = string.gsub(u_c, '^(%%..%%..%%..%%..%%..)(.+)', '%1%%%2')
    --     -- local u_c = string.gsub(u_c, '^(..)(.?.?)(.?.?)(.?.?)(.?.?)(.?.?)$', '%%%1%%%2%%%3%%%4%%%5%%%6')
    --     -- local u_c = string.gsub(u_c, '[%%]+$', '')
    --     -- yield_c( utf8_out(url_10), u_c )
    --     local cand_uci_s = Candidate("simp_mf_urlencode", seg.start, seg._end, utf8_out(url_10), url_encode(utf8_out(url_10)) )
    --     cand_uci_s.preedit = env.prefix .. "e " .. uc_i
    --     yield(cand_uci_s)
    --   end
    --   -- if url_10*10+10-1 < 1048575 then
    --   --   for i = url_10*10, url_10*10+10-1 do
    --   if tonumber(url_10)+16 < 1048575 then
    --     for i = tonumber(url_10)+1, tonumber(url_10)+16 do
    --       local cand_uci_m = Candidate("simp_mf_urlencode", seg.start, seg._end, utf8_out(i), url_encode(utf8_out(i)) )
    --       cand_uci_m.preedit = env.prefix .. "e " .. uc_i
    --       yield(cand_uci_m)
    --     end
    --   end
    --   return
    -- end
  return false
end

return { tips = tips, codes = codes }
