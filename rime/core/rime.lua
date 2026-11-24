--[[
rime.lua — lua 元件的掛接表（librime-lua 在輸入法服務啟動時載入一次）

方案檔裡寫的 `lua_processor@名稱`、`lua_translator@名稱`、`lua_filter@名稱`，
「名稱」必須是這裡的全域變數，否則 librime-lua 建不出元件，那一行等於沒寫、
而且完全不會報錯（踩過，見 docs/GOTCHAS.md）。

■ 只掛「有方案在用」的元件
  這裡每一行 require 都會在服務啟動時真的把模組讀進來，掛了沒人用的元件
  等於白付啟動時間與記憶體。新增元件時：模組放 lua/、在這裡加一行、
  到方案的 engine/* 掛上去，三件事缺一不可。

■ 掛接寫法
  模組最後 `return 函數` 或 `return { init=…, func=…, fini=… }`：
      名稱 = require("檔名")
  模組最後 return 一張「多個元件」的表：
      local m = require("檔名");  名稱 = m.其中一個

■ 改了這個檔或任何 lua：要重啟輸入法服務才生效，「重新部署」不會重讀 lua。
--]]

--------------------------------------------------------------------------
-- processor（順序即攔截優先權，由各方案的 engine/processors 決定）
--------------------------------------------------------------------------
-- '/ 指令選單「選中即執行」（'/h 速查表、'/git 更新、'/phrase…）
p_run_files = require("processor_p_run_files")
-- 注音主方案的按鍵調度（上游把英文標點切換、空白鍵、小鍵盤三個 processor 合併成一個）
mix_apc_s2rm_ltk = require("processor_mix_apc_s2rm_ltk")
-- ⇧1~⇧6 選字（不用 alternative_select_keys 的原因見該檔開頭）
p_select_keys = require("processor_p_select_keys")

--------------------------------------------------------------------------
-- translator
--------------------------------------------------------------------------
-- '/ 多功能：日期時間、計算機、Unicode、分層選單…
mf_translator = require("translator_multifunction_translator")
-- '/ts '/uuid '/pw '/rgb '/cs 開發者小工具
devkit_translator = require("translator_devkit")
-- 直接打 email、網址原樣上屏
email_url_translator = require("translator_email_url_translator")
-- ` 開頭 emoji／符號集的項目說明
instruction_grave_bpmf = require("translator_instruction_grave_bpmf")
-- 自訂短語（讀使用者資料夾的 bopomo_onionplus_phrase.txt）
lua_custom_phrase = require("translator_lua_custom_phrase")

--------------------------------------------------------------------------
-- filter（注意各方案 engine/filters 裡的順序，會影響效果）
--------------------------------------------------------------------------
-- 字集過濾＋缺字標註（上游把兩個 filter 合併成一個以省效能）
mix_cf2_miss_filter = require("filter_mix_cf2_miss_filter")
-- 英文候選排序切換（預設／字母序）
en_sort_filter = require("filter_en_sort_filter")
-- 英文候選尾綴「;」「;;」轉全大寫／首字大寫
convert_english_filter = require("filter_convert_english_filter")
-- 日文候選：假名、羅馬字、全半形轉換
convert_japan_filter = require("filter_convert_japan_filter")
-- 候選註解顯示 Unicode 編碼（開關 unicode_comment）
comment_filter_unicode = require("filter_comment_filter_unicode")
-- 日文／英文候選釋義（中／英／日三語）
gloss_filter = require("filter_gloss")
-- 韓文：只留一個候選的遮屏（開關 kr_1m）
kr_hnc_1m_filter = require("filter_kr_hnc_1m_filter")
