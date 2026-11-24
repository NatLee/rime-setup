# mf_components — 多功能翻譯器（mf_translator）架構說明

多功能翻譯器家族：以 `'/`（可由方案 `mf_translator/prefix` 設定）開頭，提供日期時間、
數字計算機、字母轉換、Unicode 內碼、快捷開啟、鍵位表、版本記憶體等功能。

本目錄採「**資料與邏輯分離**」架構：純輸出格式的分支寫成**規格表**（data），
含判斷/迴圈/特殊 Candidate 的分支保留為**邏輯模組**（logic），兩者統一向
**registry** 註冊，由主檔一行 `dispatch` 調度。

## 模組圖

```
translator_multifunction_translator.lua   主檔：init ＋ yield_c ＋ registry.dispatch()
│（載入時依「原始 if 鏈順序」完成註冊）
│
├─ core/registry.lua   註冊表＋調度器
│    register_exact(code, handler)   精確代碼 → O(1) 查表
│    register_matcher(handler)       pattern 型 → 依註冊順序成鏈
│    register_specs(specs)           整份規格表逐碼註冊為精確代碼
│    dispatch(input, seg, env, ctx)  剝除 prefix → 先精確、後 matcher 鏈
│
├─ core/render.lua     規格表渲染器
│    render(specs, code, yield_c)：specs[code] 逐項 { text_fn, comment } yield
│
├─ core/fmt.lua        格式化原語庫
│    ‧ 再匯出 f_components / lunar_calendar 常用函數（fs、rq1/rq2、eng*_m/d…）
│    ‧ per-dispatch 記憶化：t1/t2/tz/wk/lunar/jzl/jp/tdc/mg…同一次按鍵只算一次
│    ‧ 規格產生器：gen_f_sep / gen_fn_sep / gen_ft_sep / gen_md_sep / gen_ym_sep /
│      gen_minguo_h / gen_jp_era4 / gen_oct / gen_cn4 / gen_ampm_cn4
│
├─ 規格表（純資料，僅依賴 core/fmt）
│    dt_specs_misc.lua   p 程式格式、z 時區、l 月相、s 節氣
│    dt_specs_time.lua   t*（時:分:秒）、n*（時:分）
│    dt_specs_date.lua   f/y/m/d/w/md/ym/mdw/fn/ft/fw… 全部年月日組合
│
└─ 邏輯模組（內部邏輯保留，向 registry 註冊）
     mf_open_menu.lua        '' 功能總覽、k* 鍵位表、j 選單（exact）＋ j[a-z]+（matcher）
                             ＋ v/g/gc 版本記憶體（exact）
     mf_letters.lua          / ; ' 前導提示（exact）＋字母大小寫轉換（matcher）
     mf_unicode.lua          x u c o i 前導提示（exact）＋內碼/URL 轉換（matcher）
     mf_datetime_custom.lua  ○y○m○d 指定日期（matcher）
     mf_number_calc.lua      數字與計算機（matcher）
```

## 資料流（一次按鍵）

1. 主檔 `translate(input, seg, env)`：確認 `seg:has_tag("mf_translator")`，
   建立 `ctx = { yield_c, caret_pos }`，呼叫 `registry.dispatch`。
2. `dispatch` 先呼叫 `fmt.reset()` 清空記憶化快取（同一次按鍵內
   `time_out1()`／農曆轉換等只算一次）。
3. 剝除 `env.prefix` 後查精確表：命中（如 `f`、`kk`、`v`、`''`）即執行該 handler。
   規格表碼的 handler 由 `render` 逐項執行 `text_fn()` 並 `yield_c(text, comment)`。
4. 未命中則依序跑 matcher 鏈（順序＝原始 if 鏈順序，**不可變**）：
   `j[a-z]+` → 字母轉換 → u/x/c/o/i 內碼 → ○y○m○d → 數字計算機。

### 順序語義（遮蔽關係）

原始碼是一條大 if/elseif 鏈；registry 改為「先精確、後 matcher」。兩者等價的前提：
原鏈中位於精確代碼之前的 matcher 只有 `j[a-z]+`（要求 j 開頭後接字母），與任何
精確代碼（含 v/g/gc、全部日期時間碼）無交集。此性質已由全候選回歸測試逐條驗證。
**新增 matcher 時務必維持註冊順序**，並確認不會攔截既有精確代碼。

## 規格表項格式

```lua
specs["碼"] = {
  { text_fn, comment },   -- text_fn: 零參閉包回傳候選文字；comment: 字串或零參閉包
  ...
}
-- 特例：候選數量不定時，可直接給 function(yield_c) ... end（見 dt_specs_misc 的 "s"）
-- 別名碼：specs["fo"] = specs["fd"]（同一份規格、兩個鍵）
```

## 如何新增一個日期格式（最小範例）

例：想讓 `'/f` 多一個「ISO 週數」候選 —— 在 `dt_specs_date.lua` 的 `specs["f"]`
陣列中加入一項：

```lua
  { function() return os.date("%G-W%V") end, "〔ISO 週〕 ~w" },
```

候選順序＝陣列順序。常用格式化函數請優先取自 `fmt`（全形 `fmt.fs`、去零
`fmt.s0nd/s0bd/s0lead`、農曆 `fmt.lunar()`、干支 `fmt.jzl()`、元号 `fmt.jp()`…），
同來源在一次按鍵內自動只算一次。

## 如何新增一個新代碼

1. **純輸出格式** → 在對應 `dt_specs_*.lua` 加 `specs["新碼"] = { ... }` 即可
   （`register_specs` 會自動註冊；別名碼直接指向同一份表）。
2. **需要邏輯**（pattern 比對、preedit 改寫、特殊 Candidate type）→ 在邏輯模組實作
   handler，於該模組 `register(reg)` 中以 `reg.register_exact("碼", handler)` 或
   `reg.register_matcher(handler)` 註冊；matcher 請注意插入位置（主檔註冊順序
   ＝matcher 鏈順序）。
3. handler 簽名一律 `(input, seg, env, ctx)`，處理到就回 `true`。

## 回歸測試怎麼跑（沙盒，勿碰真實詞庫、勿動 WeaselServer）

測試腳本位於 scratchpad（`...\scratchpad\`），沙盒為其中的 `rime_regress\`：

```powershell
# 1) 部署：把 repo 的 rime\lua 鏡像到沙盒；-Freeze <epoch> 會在沙盒 rime.lua 注入
#    凍結時鐘 shim（僅沙盒副本），使輸出完全 deterministic 可 byte 級比對
.\deploy_sandbox.ps1 -Freeze 1785884649

# 2) 全候選回歸：對 ~230 組輸入抓取「每一條候選」(text+comment)
.\rime_allcands.ps1 after_ac1.txt
.\compare_ac.ps1 golden_ac1.txt after_ac1.txt    # 期望 FAIL: 0（僅 g/gc 記憶體數字正規化）

# 3) 換第二個凍結時間再跑一輪（覆蓋進位/去零等不同分支）
.\deploy_sandbox.ps1 -Freeze 1767196737
.\rime_allcands.ps1 after_ac2.txt
.\compare_ac.ps1 golden_ac2.txt after_ac2.txt

# 4) 實時鐘上屏回歸（194 條，取第一候選 commit，數字/時辰正規化比對）
.\deploy_sandbox.ps1
.\rime_regress_full.ps1 after_full.txt
.\compare_regress.ps1
```

golden 檔（`golden_ac1/ac2/full.txt`）由重構前程式碼產生；重構期間每個階段
（core 接線 → misc → time → date 批次 → 刪舊檔）都需全數 0 FAIL 才進下一階段。

## 重構對照（原始 → 現行）

| 原始檔 | 去向 |
|---|---|
| translator_multifunction_translator.lua（if 鏈） | 主檔（init＋dispatch）＋各模組 register |
| mf_datetime.lua（調度殼） | 刪除（registry 取代） |
| mf_datetime_misc.lua | dt_specs_misc.lua |
| mf_datetime_time.lua | dt_specs_time.lua |
| mf_datetime_date.lua（1033 行手寫） | dt_specs_date.lua（規格表＋fmt 產生器） |
| mf_datetime_custom.lua / mf_number_calc.lua / mf_letters.lua / mf_unicode.lua / mf_open_menu.lua | 邏輯保留，改為向 registry 註冊 |

原始碼中被註解掉的歷史程式碼，凡無法原位保留者，均集中於對應 specs 檔案末尾的
區塊註解（標明出處），未刪除。
