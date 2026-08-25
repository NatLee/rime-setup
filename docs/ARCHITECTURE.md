# 架構

## 全景

```
C:\RIME\  ← RIME 使用者資料夾 ＝ git repo
│
├─ CLAUDE.md              AI 助手操作指南（每次載入）
├─ cheatsheet.html        使用者速查表（'/jh 或 Ctrl+Alt+H）
│
├─ *.custom.yaml          ★ 我們的所有設定改動都在這裡（patch 上游）
├─ *.schema.yaml          上游方案定義（盡量不改）
├─ *.dict.yaml            詞典（大檔）
├─ element_bopomo.yaml    主方案的選單／按鍵／編輯器設定（被 schema include）
├─ punct_bopomo.yaml      標點定義
│
├─ lua/                   見下方
├─ opencc/                簡繁／emoji／標註轉換表
├─ tools/rime-test.ps1    ★ 回歸測試框架（librime C API 直測）
├─ scripts/               雙機同步與 macOS 安裝腳本
└─ docs/                  本資料夾
```

## 方案分層

| 層 | 內容 |
|---|---|
| **注音Na+**（`bopomo_onionplus`） | 主力。中文注音 ＋ 前綴掛載其他語言 |
| 前綴掛載 | `3`英 `4`拉丁 `6`日 `66`俄 `7`韓 `77`希 `=`倉頡反查 `` ` ``emoji `';`注音文 `'/`多功能 |
| 獨立方案 | 日文／韓文／英文／注音文／全形（`Ctrl+Shift+F1~F4` 直達，長文用） |

**兩層設計的理由**：短句用前綴不必切換方案；長文切原生方案才有該語言的標點與數字選字。

## lua 目錄

```
lua/
├─ rime.lua                        元件註冊表（global = require(...)）
│
├─ translator_multifunction_translator.lua   '/ 家族主檔（154 行薄調度器）
├─ mf_components/                  ★ 資料驅動架構，見該資料夾 README
│   ├─ core/registry.lua           精確碼 O(1) 查表 ＋ 保序 matcher 鏈
│   ├─ core/render.lua             規格表 → 候選
│   ├─ core/fmt.lua                格式化原語 ＋ 每鍵記憶化
│   ├─ dt_specs_{date,time,misc}.lua   純資料：代碼 → 格式清單
│   └─ mf_{number_calc,letters,unicode,open_menu,datetime_custom}.lua
│
├─ translator_devkit.lua           '/ts '/uuid '/pw '/rgb '/cs
├─ filter_gloss.lua                候選釋義（中／英／日可切換）
├─ processor_mix_apc_s2rm_ltk.lua  主方案處理器（標點轉換、上屏修正、快捷開啟）
├─ processor_p_run_files.lua       '/ 選單的「選中即執行」（⚠ 須排在 processor 鏈首）
├─ processor_p_select_keys.lua     ⇧1~6 選字（⚠ 取代 menu/alternative_select_keys，
│                                   否則 macOS 標籤會變 !@#$%^；排 recognizer 之後）
├─ f_components/                   格式化元件（日期樣式、中文數字、農曆…）
├─ filter_cand/                    候選操作小工具（改註解、去重…）
└─ p_components/p_run_pattern.lua  '/j 快捷開啟清單（可自訂）
```

## 一次按鍵的資料流

```
按鍵
 └→ processors（依序，第一個 return kAccepted 就停）
     └→ speller → 組字 → segmentors 切段（affix_segmentor 依前綴打標籤）
         └→ translators 產生候選（punct / table / script / lua）
             └→ filters 依序加工（簡繁、emoji、註解、排序、釋義…）
                 └→ 候選選單 → 前端繪製
```

**關鍵**：`tags` 決定哪個 translator/filter 作用於哪個段落。例如 `filter_gloss` 只吃
`japan`（注音方案的 `6` 前綴段）與 `abc`（日文原生方案）。

## 釋義子系統

```
jpnin1_gloss.dict.yaml      日→英  6.3 萬條（JMdict）
jpnin1_gloss_zh.dict.yaml   日→中  5.5 萬條（日本語 WordNet ＋ 中研院 CWN）
jpnin1_gloss_ja.dict.yaml   日→日  9.2 萬條（WordNet 定義句）
        │
        ├─ 各配一個 stub schema，並列入 schema/dependencies 才會被編譯
        └─ lua/filter_gloss.lua 透過 ReverseLookup 查詢
             radio 開關 gloss_zh / gloss_en / gloss_ja（預設 zh，查無 zh→en→ja 遞補）
             排版：最多 2 義、每義依顯示寬度截斷、以「\n　」換行
```

## 新增功能的最小路徑

**加一個 `'/` 日期格式** → 在 `mf_components/dt_specs_date.lua` 的表加一行：
```lua
specs["fq"] = { { function() return os.date("%Y!%m!%d") end, "〔自訂〕" } }
```

**加一個 `'/` 新功能** → 在 `lua/translator_devkit.lua` 加分支（或新建模組後在 `rime.lua` 註冊、在 `*.custom.yaml` 的 `engine/translators` 掛載）。

**加一個自訂詞** → `bopomo_onionplus_phrase.txt` 加「文字 <TAB> 編碼 <TAB> 權重」→ 部署。

改完一律跑 `pwsh tools\rime-test.ps1 -Sync -Mode basic`。
