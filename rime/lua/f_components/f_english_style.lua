--[[
number_translator: 將 `'/` + 阿拉伯數字 和 英文字母 各種轉譯
--]]

------------------------------------

local projector = require("filter_cand/projector")

------------------------------------

local function english_s(en)
  if en == "" then return "" end
  return string.gsub(en, "%./", " ")
end

local function english_u2(en)
  if en == "" then return "" end
  -- if string.match(en, "^[/.'-][a-z]") then
  --   en = string.upper(string.sub(en,1,2)) .. string.sub(en,3)
  -- end
  en = string.gsub(en, "^['.]%l", string.upper)
  return string.gsub(en, "[/-]%l", string.upper)
end

local function english_u1(en)
  if en == "" then return "" end
  -- en = string.upper(string.sub(en,1,1)) .. string.sub(english_u2(english_s(en)),2)
  -- return en
  en = english_s(en)
  return string.gsub(en, "^%l", string.upper)
end

local function english_s2u(en)
  if en == "" then return "" end
  en = english_u1(en)
  en = english_u2(en)
  return string.gsub(en, " %l", string.upper)
end

------------------------------------
--- 以下新的寫法

local english_1 = projector(
  "xlit|ABCDEFGHIJKLMNOPQRSTUVWXYZ|𝔸𝔹ℂ𝔻𝔼𝔽𝔾ℍ𝕀𝕁𝕂𝕃𝕄ℕ𝕆ℙℚℝ𝕊𝕋𝕌𝕍𝕎𝕏𝕐ℤ|",
  "xform|[.]/| |"
)

local english_2 = projector(
  "xlit|abcdefghijklmnopqrstuvwxyz|𝕒𝕓𝕔𝕕𝕖𝕗𝕘𝕙𝕚𝕛𝕜𝕝𝕞𝕟𝕠𝕡𝕢𝕣𝕤𝕥𝕦𝕧𝕨𝕩𝕪𝕫|",
  "xform|[.]/| |"
)

local english_3 = projector(
  "xlit|ABCDEFGHIJKLMNOPQRSTUVWXYZ |ⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏ　|",
  "xform|[.]/|　|"
)

local english_4 = projector(
  "xlit|abcdefghijklmnopqrstuvwxyz |ⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩ　|",
  "xform|[.]/|　|"
)

local english_5 = projector(
  "xlit|ABCDEFGHIJKLMNOPQRSTUVWXYZ |🄐🄑🄒🄓🄔🄕🄖🄗🄘🄙🄚🄛🄜🄝🄞🄟🄠🄡🄢🄣🄤🄥🄦🄧🄨🄩　|",
  "xform|[.]/|　|"
)

local english_6 = projector(
  "xlit|abcdefghijklmnopqrstuvwxyz |⒜⒝⒞⒟⒠⒡⒢⒣⒤⒥⒦⒧⒨⒩⒪⒫⒬⒭⒮⒯⒰⒱⒲⒳⒴⒵　|",
  "xform|[.]/|　|"
)

local english_7 = projector(
  "xlit|ABCDEFGHIJKLMNOPQRSTUVWXYZ|🄰🄱🄲🄳🄴🄵🄶🄷🄸🄹🄺🄻🄼🄽🄾🄿🅀🅁🅂🅃🅄🅅🅆🅇🅈🅉|",
  "xform|[.]/|　|"
)

local english_8 = projector(
  "xlit|ABCDEFGHIJKLMNOPQRSTUVWXYZ|🅐🅑🅒🅓🅔🅕🅖🅗🅘🅙🅚🅛🅜🅝🅞🅟🅠🅡🅢🅣🅤🅥🅦🅧🅨🅩|",
  "xform|[.]/|　|"
)

local english_9 = projector(
  "xlit|ABCDEFGHIJKLMNOPQRSTUVWXYZ|🅰🅱🅲🅳🅴🅵🅶🅷🅸🅹🅺🅻🅼🅽🅾🅿🆀🆁🆂🆃🆄🆅🆆🆇🆈🆉|",
  "xform|[.]/|　|"
)

local english_f_u = projector(
  "xform|[.]/|　|",
  "xlit|ABCDEFGHIJKLMNOPQRSTUVWXYZ ,.-/'|ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ　，．－／＇|"
)

local english_f_l = projector(
  "xform|[.]/|　|",
  "xlit|abcdefghijklmnopqrstuvwxyz ,.-/'|ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ　，．－／＇|"
)

local english_s_u = projector(
  "xlit|ABCDEFGHIJKLMNOPQRSTUVWXYZ|ᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘǫʀsᴛᴜᴠᴡxʏᴢ|",
  "xform|[.]/|　|"
)


--- 以下參考：https://liblouis.io/translate/

local english_braille_c_u = projector(
  "xform|[.]/|⠀|",
  "xlit|ABCDEFGHIJKLMNOPQRSTUVWXYZ ,.-/'|⡁⡃⡉⡙⡑⡋⡛⡓⡊⡚⡅⡇⡍⡝⡕⡏⡟⡗⡎⡞⡥⡧⡺⡭⡽⡵⠀⠠⠨⠤⠌⠄|"
)

local english_braille_c_l = projector(
  "xform|[.]/|⠀|",
  "xlit|abcdefghijklmnopqrstuvwxyz ,.-/'|⠁⠃⠉⠙⠑⠋⠛⠓⠊⠚⠅⠇⠍⠝⠕⠏⠟⠗⠎⠞⠥⠧⠺⠭⠽⠵⠀⠠⠨⠤⠌⠄|"
)

local english_braille_u_u = projector(
  "xform|[.]/|⠀|",
  "xform|([A-Za-z]),([A-Za-z])|$1⠰⠂$2|",  -- "xform|([^.,/'-])[,]([^.,/'-])|$1⠰⠂$2|"
  "xform|([^A-Z])([A-Z]+)|$1⠠$2|",
  "xform|^([A-Z])|⠠$1|",
  "xform|(⠠)([A-Z][A-Z]+)|$1$1$2|",
  "xform|[/]|⠸⠌|",
  -- local format7 = "xform|([^.])[.]$|$1⠲|"
  -- local format8 = "xform|[']⠀|⠴⠄⠀|"
  "xlit|ABCDEFGHIJKLMNOPQRSTUVWXYZ ,.-'|⠁⠃⠉⠙⠑⠋⠛⠓⠊⠚⠅⠇⠍⠝⠕⠏⠟⠗⠎⠞⠥⠧⠺⠭⠽⠵⠀⠂⠲⠤⠄|"
)

local english_braille_u_l = projector(
  "xform|[.]/|⠀|",
  "xform|([A-Za-z]),([A-Za-z])|$1⠰⠂$2|",
  "xform|[/]|⠸⠌|",
  -- local format3 = "xform|([^.])[.]$|$1⠲|"
  -- local format3 = "xform|[']⠀|⠴⠄⠀|"
  "xlit|abcdefghijklmnopqrstuvwxyz ,.-/'|⠁⠃⠉⠙⠑⠋⠛⠓⠊⠚⠅⠇⠍⠝⠕⠏⠟⠗⠎⠞⠥⠧⠺⠭⠽⠵⠀⠂⠲⠤⠌⠄|"
)

------------------------------------

--- 「句首／詞首大寫」的混合樣式：先整理大小寫，大寫字母套 upper 字型；還有小寫才再套 lower 字型。
local function mixed(upper, lower)
  return function(en)
    if en == "" then return "" end
    en = english_s2u(en)
    en = upper(en)
    if string.match(en, "%l") then
      en = lower(en)
    end
    return en
  end
end

local english_1_2 = mixed(english_1, english_2)
local english_3_4 = mixed(english_3, english_4)
local english_5_6 = mixed(english_5, english_6)
local english_f_ul = mixed(english_f_u, english_f_l)
local english_braille_c_ul = mixed(english_braille_c_u, english_braille_c_l)
local english_braille_u_ul = mixed(english_braille_u_u, english_braille_u_l)

return {
        english_s = english_s,
        english_u1 = english_u1,
        -- english_u2 = english_u2,
        english_s2u = english_s2u,

        english_1 = english_1,
        english_2 = english_2,
        english_3 = english_3,
        english_4 = english_4,
        english_5 = english_5,
        english_6 = english_6,
        english_7 = english_7,
        english_8 = english_8,
        english_9 = english_9,
        english_f_u = english_f_u,
        english_f_l = english_f_l,
        english_s_u = english_s_u,
        english_1_2 = english_1_2,
        english_3_4 = english_3_4,
        english_5_6 = english_5_6,
        english_f_ul = english_f_ul,

        english_braille_c_u = english_braille_c_u,
        english_braille_c_l = english_braille_c_l,
        english_braille_c_ul = english_braille_c_ul,
        english_braille_u_u = english_braille_u_u,
        english_braille_u_l = english_braille_u_l,
        english_braille_u_ul = english_braille_u_ul,
        }