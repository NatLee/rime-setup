--[[
number_translator: 將 `'/` + 阿拉伯數字 和 英文字母 各種轉譯
--]]

------------------------------------

local projector = require("filter_cand/projector")

------------------------------------

local function formatnumberthousands(n3)
  local r3 = string.sub(n3, -3, -1)  -- 從後向前取三位
  local n3 = string.sub(n3, 1, -4)  -- 剩下的數字
  -- 每次循環從後向前取三位，拼接到結果前面
  -- 直到剩下數字為空
  while string.len(n3) > 0 do
    r3 = string.sub(n3, -3, -1) .. "," .. r3
    n3 = string.sub(n3, 1, -4)
  end
  -- 返回結果
  return r3
end

------------------------------------

local fullshape_number = projector(
  "xlit|0123456789|０１２３４５６７８９|"
)

local math1_number = projector(
  "xlit|0123456789|𝟎𝟏𝟐𝟑𝟒𝟓𝟔𝟕𝟖𝟗|"
)

local math2_number = projector(
  "xlit|0123456789|𝟘𝟙𝟚𝟛𝟜𝟝𝟞𝟟𝟠𝟡|"
)

local circled1_number = projector(
  "xlit|0123456789|⓪①②③④⑤⑥⑦⑧⑨|"
)

local circled2_number = projector(
  "xlit|0123456789|🄋➀➁➂➃➄➅➆➇➈|"
)

local circled3_number = projector(
  "xlit|0123456789|⓿❶❷❸❹❺❻❼❽❾|"
)

local circled4_number = projector(
  "xlit|0123456789|🄌➊➋➌➍➎➏➐➑➒|"
)

local circled5_number = projector(
  "xlit|0123456789|Ⓞ㊀㊁㊂㊃㊄㊅㊆㊇㊈|"
)

local purech_number = projector(
  "xlit|0123456789.|〇一二三四五六七八九點|"
)

local purebigch_number = projector(
  "xlit|0123456789.|零壹貳參肆伍陸柒捌玖點|"
)

local military_number = projector(
  "xlit|0123456789.|洞么兩三四五六拐八勾點|"
)

local little1_number = projector(
  "xlit|0123456789.|⁰¹²³⁴⁵⁶⁷⁸⁹⋅|"
)

local little2_number = projector(
  "xlit|0123456789.|₀₁₂₃₄₅₆₇₈₉.|"
)

local braille_c_number = projector(
  "xlit|0123456789.|⠴⠂⠆⠒⠲⠢⠖⠶⠦⠔⠨|"
)

local braille_u_number = projector(
  "xlit|0123456789.|⠚⠁⠃⠉⠙⠑⠋⠛⠓⠊⠲|"
)

------------------------------------

local function keycap_number(dn)
  if dn == "" then return "" end
  return (string.gsub(dn, "%d", "%0️⃣"))  -- 每個數字後面接鍵帽後綴；外層括號丟掉 gsub 的第二個回傳值
end

------------------------------------

return {
        formatnumberthousands = formatnumberthousands,
        fullshape_number = fullshape_number,
        math1_number = math1_number,
        math2_number = math2_number,
        circled1_number = circled1_number,
        circled2_number = circled2_number,
        circled3_number = circled3_number,
        circled4_number = circled4_number,
        circled5_number = circled5_number,
        purech_number = purech_number,
        purebigch_number = purebigch_number,
        military_number = military_number,
        little1_number = little1_number,
        little2_number = little2_number,
        braille_c_number = braille_c_number,
        braille_u_number = braille_u_number,
        keycap_number = keycap_number,
        }