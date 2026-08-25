# 鍵位與代碼總表（自動產生）

> ⚠ **這份檔案由 `tools/keymap-dump.ps1` 產生，不要手改** —— 下次重跑會被覆蓋。
> 要改行為請改對應的來源檔（每一節都標了來源），改完重新部署再跑一次這支腳本。
>
> 產生時間：2026-08-26 00:33　方案：`bopomo_onionplus`

這份表要回答的問題：**「這個鍵／這個代碼，現在是誰在用？」**
資料直接取自部署後的 `build/`（patch 與 `__include` 都已合併）與 lua 原始碼，
所以看到的就是實際生效的值，不是「應該要是」的值。

## 1. processor 鏈（按鍵的攔截順序）

排在前面的先看到按鍵，`return kAccepted` 之後就輪不到後面的。
「某個鍵沒反應」或「按了跑出別的東西」，九成是這條鏈的順序問題。

1. `lua_processor@p_run_files`
2. `lua_processor@mix_apc_s2rm_ltk`
3. `ascii_composer`
4. `recognizer`
5. `key_binder`
6. `lua_processor@p_select_keys`
7. `speller`
8. `selector`
9. `punctuator`
10. `navigator`
11. `express_editor`

來源：`bopomo_onionplus.custom.yaml` 的 `engine/processors`。
⚠ `lua_processor@x` 需要 `rime.lua` 有 `x = require(...)`，否則靜默失效。

## 2. 選字鍵與翻頁鍵

| 項目 | 值 | 定義在 |
|---|---|---|
| 選字鍵（lua） | `!@#$%^` | `bopomo_onionplus.custom.yaml` → `p_select_keys/keys`，行為在 `lua/processor_p_select_keys.lua` |
| 選字鍵（librime 內建） | **刻意留空** | `menu/alternative_select_keys`（設了 macOS 標籤會壞，見 GOTCHAS） |
| 候選標籤 | `⇧1` `⇧2` `⇧3` `⇧4` `⇧5` `⇧6` | `menu/alternative_select_labels` |
| 每頁列數 | `6` | `menu/page_size`（`element_bopomo.yaml`） |

## 3. 快捷鍵（key_binder）

合併後的完整清單。`accept` 是實際按的鍵，`send`/`toggle`/`select` 是動作。

| 按鍵 | 動作 | 生效條件 | 來源 |
|---|---|---|---|
| `Control+p` | send: Up | composing | 方案（element_bopomo ＋ custom） |
| `Control+n` | send: Down | composing | 方案（element_bopomo ＋ custom） |
| `Control+b` | send: Left | composing | 方案（element_bopomo ＋ custom） |
| `Control+f` | send: Right | composing | 方案（element_bopomo ＋ custom） |
| `Control+a` | send: Home | composing | 方案（element_bopomo ＋ custom） |
| `Control+e` | send: End | composing | 方案（element_bopomo ＋ custom） |
| `Control+d` | send: Delete | composing | 方案（element_bopomo ＋ custom） |
| `Control+k` | send: Shift+Delete | composing | 方案（element_bopomo ＋ custom） |
| `Control+h` | send: BackSpace | composing | 方案（element_bopomo ＋ custom） |
| `Control+g` | send: Escape | composing | 方案（element_bopomo ＋ custom） |
| `Alt+v` | send: Page_Up | composing | 方案（element_bopomo ＋ custom） |
| `Control+v` | send: Page_Down | composing | 方案（element_bopomo ＋ custom） |
| `ISO_Left_Tab` | send: Shift+Left | composing | 方案（element_bopomo ＋ custom） |
| `Shift+Tab` | send: Shift+Left | composing | 方案（element_bopomo ＋ custom） |
| `Tab` | send: Shift+Right | composing | 方案（element_bopomo ＋ custom） |
| `minus` | send: Page_Up | has_menu | 方案（element_bopomo ＋ custom） |
| `equal` | send: Page_Down | has_menu | 方案（element_bopomo ＋ custom） |
| `comma` | send: Page_Up | paging | 方案（element_bopomo ＋ custom） |
| `period` | send: Page_Down | has_menu | 方案（element_bopomo ＋ custom） |
| `Control+Shift+1` | select: .next | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+2` | toggle: ascii_mode | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+3` | toggle: full_shape | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+4` | toggle: ascii_punct | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+5` | toggle: simplification | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+6` | toggle: extended_charset | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+exclam` | select: .next | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+at` | toggle: ascii_mode | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+numbersign` | toggle: full_shape | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+dollar` | toggle: ascii_punct | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+percent` | toggle: simplification | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+asciicircum` | toggle: extended_charset | always | 方案（element_bopomo ＋ custom） |
| `Shift+space` | toggle: ascii_mode | always | 方案（element_bopomo ＋ custom） |
| `Control+comma` | toggle: ascii_mode | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+F1` | select: bopomo_onionplus | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+F2` | select: jpnin1 | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+F3` | select: hangeul_hnc | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+F4` | select: easy_en_lower | always | 方案（element_bopomo ＋ custom） |
| `Control+Alt+1` | select: bopomo_onionplus | always | 方案（element_bopomo ＋ custom） |
| `Control+Alt+2` | select: jpnin1 | always | 方案（element_bopomo ＋ custom） |
| `Control+Alt+3` | select: hangeul_hnc | always | 方案（element_bopomo ＋ custom） |
| `Control+Alt+4` | select: easy_en_lower | always | 方案（element_bopomo ＋ custom） |
| `Control+period` | toggle: full_shape | always | 方案（element_bopomo ＋ custom） |
| `Control+semicolon` | toggle: simplification | always | 方案（element_bopomo ＋ custom） |
| `Control+slash` | toggle: ascii_punct | always | 方案（element_bopomo ＋ custom） |
| `comma` | send: comma | has_menu | 方案（element_bopomo ＋ custom） |
| `comma` | send: comma | paging | 方案（element_bopomo ＋ custom） |
| `period` | send: period | has_menu | 方案（element_bopomo ＋ custom） |
| `period` | send: period | paging | 方案（element_bopomo ＋ custom） |
| `minus` | send: minus | has_menu | 方案（element_bopomo ＋ custom） |
| `minus` | send: minus | paging | 方案（element_bopomo ＋ custom） |
| `equal` | send: equal | has_menu | 方案（element_bopomo ＋ custom） |
| `equal` | send: equal | paging | 方案（element_bopomo ＋ custom） |
| `Tab` | send: Shift+Left | paging | 方案（element_bopomo ＋ custom） |
| `Up` | send: KP_Left | composing | 方案（element_bopomo ＋ custom） |
| `Up` | send: Up | paging | 方案（element_bopomo ＋ custom） |
| `Right` | send: Shift+Right | composing | 方案（element_bopomo ＋ custom） |
| `Shift+Right` | send: Right | composing | 方案（element_bopomo ＋ custom） |
| `Shift+Left` | send: KP_Left | composing | 方案（element_bopomo ＋ custom） |
| `Left` | send: Page_Up | paging | 方案（element_bopomo ＋ custom） |
| `Right` | send: Page_Down | paging | 方案（element_bopomo ＋ custom） |
| `Shift+Up` | send: Page_Up | paging | 方案（element_bopomo ＋ custom） |
| `Shift+Down` | send: Page_Down | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+C` | send: Page_Up | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+space` | send: Page_Down | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+I` | send: Page_Up | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+K` | send: Page_Down | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+Y` | send: Control+1 | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+H` | send: Control+2 | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+N` | send: Control+3 | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+U` | send: Control+4 | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+J` | send: Control+5 | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+M` | send: Control+6 | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+Q` | send: Control+1 | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+A` | send: Control+2 | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+Z` | send: Control+3 | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+W` | send: Control+4 | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+S` | send: Control+5 | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+X` | send: Control+6 | has_menu | 方案（element_bopomo ＋ custom） |
| `space` | send: Return | paging | 方案（element_bopomo ＋ custom） |
| `Shift+D` | send: space | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+L` | send: space | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+E` | send: Shift+Return | composing | 方案（element_bopomo ＋ custom） |
| `Shift+O` | send: Shift+Return | composing | 方案（element_bopomo ＋ custom） |
| `Shift+F` | send: Control+Return | has_menu | 方案（element_bopomo ＋ custom） |
| `BackSpace` | send: Control+BackSpace | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+BackSpace` | send: BackSpace | has_menu | 方案（element_bopomo ＋ custom） |
| `backslash` | send: BackSpace | has_menu | 方案（element_bopomo ＋ custom） |
| `Shift+R` | send: BackSpace | composing | 方案（element_bopomo ＋ custom） |
| `Shift+P` | send: BackSpace | composing | 方案（element_bopomo ＋ custom） |
| `Shift+T` | send: Delete | composing | 方案（element_bopomo ＋ custom） |
| `Shift+G` | send: Escape | composing | 方案（element_bopomo ＋ custom） |
| `Shift+V` | send: Home | composing | 方案（element_bopomo ＋ custom） |
| `Shift+B` | send: End | composing | 方案（element_bopomo ＋ custom） |
| `Control+Shift+6` | toggle: character_range_bhjm | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+7` | toggle: emoji_segestion | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+8` | toggle: back_mark | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+9` | toggle: unicode_comment | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+0` | toggle: en_sort | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+asciicircum` | toggle: character_range_bhjm | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+ampersand` | toggle: emoji_segestion | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+asterisk` | toggle: back_mark | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+parenleft` | toggle: unicode_comment | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+parenright` | toggle: en_sort | always | 方案（element_bopomo ＋ custom） |
| `Control+bracketleft` | unset_option: emoji_segestion | always | 方案（element_bopomo ＋ custom） |
| `Control+bracketright` | unset_option: back_mark | always | 方案（element_bopomo ＋ custom） |
| `Control+apostrophe` | unset_option: character_range_bhjm | always | 方案（element_bopomo ＋ custom） |
| `Control+minus` | set_option: unicode_comment | always | 方案（element_bopomo ＋ custom） |
| `Control+equal` | set_option: en_sort | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+bracketleft` | set_option: emoji_segestion | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+bracketright` | set_option: back_mark | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+apostrophe` | set_option: character_range_bhjm | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+minus` | unset_option: unicode_comment | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+equal` | unset_option: en_sort | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+braceleft` | set_option: emoji_segestion | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+braceright` | set_option: back_mark | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+quotedbl` | set_option: character_range_bhjm | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+underscore` | unset_option: unicode_comment | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+plus` | unset_option: en_sort | always | 方案（element_bopomo ＋ custom） |
| `Control+Shift+F5` | toggle: en_sort | always | 方案（element_bopomo ＋ custom） |
| `Control+p` | send: Up | composing | 全域（default.custom.yaml） |
| `Control+n` | send: Down | composing | 全域（default.custom.yaml） |
| `Control+b` | send: Left | composing | 全域（default.custom.yaml） |
| `Control+f` | send: Right | composing | 全域（default.custom.yaml） |
| `Control+a` | send: Home | composing | 全域（default.custom.yaml） |
| `Control+e` | send: End | composing | 全域（default.custom.yaml） |
| `Control+d` | send: Delete | composing | 全域（default.custom.yaml） |
| `Control+k` | send: Shift+Delete | composing | 全域（default.custom.yaml） |
| `Control+h` | send: BackSpace | composing | 全域（default.custom.yaml） |
| `Control+g` | send: Escape | composing | 全域（default.custom.yaml） |
| `Alt+v` | send: Page_Up | composing | 全域（default.custom.yaml） |
| `Control+v` | send: Page_Down | composing | 全域（default.custom.yaml） |
| `ISO_Left_Tab` | send: Shift+Left | composing | 全域（default.custom.yaml） |
| `Shift+Tab` | send: Shift+Left | composing | 全域（default.custom.yaml） |
| `Tab` | send: Shift+Right | composing | 全域（default.custom.yaml） |
| `minus` | send: Page_Up | has_menu | 全域（default.custom.yaml） |
| `equal` | send: Page_Down | has_menu | 全域（default.custom.yaml） |
| `comma` | send: Page_Up | paging | 全域（default.custom.yaml） |
| `period` | send: Page_Down | has_menu | 全域（default.custom.yaml） |
| `Control+Shift+1` | select: .next | always | 全域（default.custom.yaml） |
| `Control+Shift+2` | toggle: ascii_mode | always | 全域（default.custom.yaml） |
| `Control+Shift+3` | toggle: full_shape | always | 全域（default.custom.yaml） |
| `Control+Shift+4` | toggle: ascii_punct | always | 全域（default.custom.yaml） |
| `Control+Shift+5` | toggle: simplification | always | 全域（default.custom.yaml） |
| `Control+Shift+6` | toggle: extended_charset | always | 全域（default.custom.yaml） |
| `Control+Shift+exclam` | select: .next | always | 全域（default.custom.yaml） |
| `Control+Shift+at` | toggle: ascii_mode | always | 全域（default.custom.yaml） |
| `Control+Shift+numbersign` | toggle: full_shape | always | 全域（default.custom.yaml） |
| `Control+Shift+dollar` | toggle: ascii_punct | always | 全域（default.custom.yaml） |
| `Control+Shift+percent` | toggle: simplification | always | 全域（default.custom.yaml） |
| `Control+Shift+asciicircum` | toggle: extended_charset | always | 全域（default.custom.yaml） |
| `Shift+space` | toggle: ascii_mode | always | 全域（default.custom.yaml） |
| `Control+comma` | toggle: ascii_mode | always | 全域（default.custom.yaml） |
| `Control+Shift+F1` | select: bopomo_onionplus | always | 全域（default.custom.yaml） |
| `Control+Shift+F2` | select: jpnin1 | always | 全域（default.custom.yaml） |
| `Control+Shift+F3` | select: hangeul_hnc | always | 全域（default.custom.yaml） |
| `Control+Shift+F4` | select: easy_en_lower | always | 全域（default.custom.yaml） |
| `Control+Alt+1` | select: bopomo_onionplus | always | 全域（default.custom.yaml） |
| `Control+Alt+2` | select: jpnin1 | always | 全域（default.custom.yaml） |
| `Control+Alt+3` | select: hangeul_hnc | always | 全域（default.custom.yaml） |
| `Control+Alt+4` | select: easy_en_lower | always | 全域（default.custom.yaml） |
| `Control+period` | toggle: full_shape | always | 全域（default.custom.yaml） |
| `Control+semicolon` | toggle: simplification | always | 全域（default.custom.yaml） |
| `Control+slash` | toggle: ascii_punct | always | 全域（default.custom.yaml） |

來源：`default.custom.yaml`（全域）＋ `element_bopomo.yaml`（方案內建）＋
`bopomo_onionplus.custom.yaml` 的 `key_binder/bindings/+`。

## 4. 輸入前綴（打這幾個字元會切到別的語言／功能段落）

| 前綴 | 段落 | 定義在 |
|---|---|---|
| `3` | easy_en | `build/bopomo_onionplus.schema.yaml` → `easy_en/prefix` |
| `4` | european | `build/bopomo_onionplus.schema.yaml` → `european/prefix` |
| `6` | japan | `build/bopomo_onionplus.schema.yaml` → `japan/prefix` |
| `7` | korea | `build/bopomo_onionplus.schema.yaml` → `korea/prefix` |
| `][` | fs2 | `build/bopomo_onionplus.schema.yaml` → `fs2/prefix` |
| `77` | gr2 | `build/bopomo_onionplus.schema.yaml` → `gr2/prefix` |
| `66` | cyr2 | `build/bopomo_onionplus.schema.yaml` → `cyr2/prefix` |
| `=` | reverse2_lookup | `build/bopomo_onionplus.schema.yaml` → `reverse2_lookup/prefix` |
| `` ` `` | emoji_series | `build/bopomo_onionplus.schema.yaml` → `emoji_series/prefix` |
| `';` | all_bpm | `build/bopomo_onionplus.schema.yaml` → `all_bpm/prefix` |
| `'/` | mf_translator | `build/bopomo_onionplus.schema.yaml` → `mf_translator/prefix` |

## 5. `'/` 底下的代碼（誰註冊了什麼）

`registry` 是 `exact[code] = handler`，**沒有衝突檢查、後註冊覆蓋先註冊**。
註冊順序見 `lua/translator_multifunction_translator.lua`，越後面的模組贏。
新增代碼前先在這張表查一下，不然會靜默蓋掉別人的。

| 代碼 | 用途 | 註冊於 |
|---|---|---|
| `'//` | 【小寫字母】▶ | `lua/mf_components/mf_letters.lua` |
| `'/;` | 【大寫字母】▶ | `lua/mf_components/mf_letters.lua` |
| `'/\'` | 【開頭大寫字母】▶ | `lua/mf_components/mf_letters.lua` |
| `'/`（單獨） | '/ 功能總覽（分層選單） | `lua/mf_components/mf_open_menu.lua` |
| `'/dt` | '/dt 日期與時間 | `lua/mf_components/mf_open_menu.lua` |
| `'/num` | '/num 計算機用法 | `lua/mf_components/mf_open_menu.lua` |
| `'/dev` | '/dev 開發小工具＋版本 | `lua/mf_components/mf_open_menu.lua` |
| `'/code` | '/code 編碼與字母 | `lua/mf_components/mf_open_menu.lua` |
| `'/dty` | '/dty  日期：單項 | `lua/mf_components/mf_open_menu.lua` |
| `'/dts` | '/dts  日期：其他 | `lua/mf_components/mf_open_menu.lua` |
| `'/ver` | '/ver  版本與記憶體（'/v '/g '/gc） | `lua/mf_components/mf_open_menu.lua` |
| `'/case` | '/case 字母大小寫（'// '/; '/'） | `lua/mf_components/mf_open_menu.lua` |
| `'/k` | 【鍵位和編碼】▶ | `lua/mf_components/mf_open_menu.lua` |
| `'/ko` | 【操作鍵 說明】 | `lua/mf_components/mf_open_menu.lua` |
| `'/kk` | 【快捷鍵 說明】 | `lua/mf_components/mf_open_menu.lua` |
| `'/kh` | 【韓文 HNC 編碼】 | `lua/mf_components/mf_open_menu.lua` |
| `'/ks` | 【韓文 形碼 編碼】 | `lua/mf_components/mf_open_menu.lua` |
| `'/kj` | 【日文 羅馬字 編碼】 | `lua/mf_components/mf_open_menu.lua` |
| `'/ki` | 【拉丁 形碼 IPA國際音標 編碼】 | `lua/mf_components/mf_open_menu.lua` |
| `'/kp` | 【拉丁 形碼 KK/DJ/IPA音標 編碼】 | `lua/mf_components/mf_open_menu.lua` |
| `'/ky` | 【拉丁 形碼 中文拼音 編碼】 | `lua/mf_components/mf_open_menu.lua` |
| `'/kg` | 【希臘 形碼 編碼】 | `lua/mf_components/mf_open_menu.lua` |
| `'/kc` | 【西里爾 形碼 編碼】 | `lua/mf_components/mf_open_menu.lua` |
| `'/j` | 分層選單 | `lua/mf_components/mf_open_menu.lua` |
| `'/git` | '/git 更新設定並重新部署 | `lua/mf_components/mf_open_menu.lua` |
| `'/v` | handler: `ver` | `lua/mf_components/mf_open_menu.lua` |
| `'/g` | handler: `garbage` | `lua/mf_components/mf_open_menu.lua` |
| `'/gc` | handler: `garbage_collect` | `lua/mf_components/mf_open_menu.lua` |
| `'/x` | 【內碼十六進制】▶ | `lua/mf_components/mf_unicode.lua` |
| `'/u` | 【內碼十六進制】▶ | `lua/mf_components/mf_unicode.lua` |
| `'/c` | 【內碼十進制】▶ | `lua/mf_components/mf_unicode.lua` |
| `'/o` | 【內碼八進制】▶ | `lua/mf_components/mf_unicode.lua` |
| `'/i` | 【Percent/URL encoding】▶ | `lua/mf_components/mf_unicode.lua` |
| `'/` ＋ 日期時間碼（共 157 個，開頭字母：d f l m n p s t w y z） | 年月日週時分秒／節氣／月相／時區 | `lua/mf_components/dt_specs_*.lua` |
| `'/ts` … | 開發小工具 | `lua/translator_devkit.lua` |
| `'/pw` … | 開發小工具 | `lua/translator_devkit.lua` |
| `'/rgb` … | 開發小工具 | `lua/translator_devkit.lua` |
| `'/cs` … | 開發小工具 | `lua/translator_devkit.lua` |

### 命名空間

指令與快捷開啟固定用 `'/j`（lua/p_components/p_run_menu.lua 的 `NS`）。
⚠ **不要改成 `c`** —— `'/c` 是十進制內碼、`'/cs` 是 devkit 命名風格轉換，
改了會被靜默遮蔽（試過，見 `docs/GOTCHAS.md`）。

## 6. recognizer 樣式（會「搶走」按鍵的隱形規則）

`recognizer` 排在 `speller`／`selector` 之前，判斷方式是
**「把這個鍵接上去之後還符合樣式，就收下」**。
所以樣式裡出現的字元，在組字途中會被它接走 —— 這是最難查的一類衝突。

| 段落 | 樣式裡出現的可見字元 |
|---|---|
| all_bpm | （無特殊符號） |
| cyr2 | （無特殊符號） |
| easy_en | （無特殊符號） |
| email_url_translator | （無特殊符號） |
| emoji_series | （無特殊符號） |
| european | （無特殊符號） |
| fs2 | （無特殊符號） |
| gr2 | （無特殊符號） |
| japan | （無特殊符號） |
| korea | （無特殊符號） |
| mf_translator | （無特殊符號） |
| punct | （無特殊符號） |
| reverse2_lookup | （無特殊符號） |

已知因此產生的衝突：`@` 被 `email_url_translator` 的 `^[a-z][-_.0-9a-z]*@.*$` 接走，
所以「輸入以英文字母開頭時按 ⇧2 選不到字」。這是上游設計，刻意保留。

## 7. 被作業系統吃掉的鍵（傳不到輸入法）

| 鍵 | 誰吃掉的 | 對策 |
|---|---|---|
| `Ctrl+Alt+<字母>` | Windows 視為 AltGr，小狼毫不轉送 | 改用 `Ctrl+Shift+F1~F4` |
| `Ctrl+Shift+0` | Windows 系統熱鍵（登錄檔 `Input Method\Hot Keys` 的 `00000104`） | `en_sort` 改綁 `Ctrl+Shift+F5` |
| `Ctrl+Alt+G/K/L/V` | 同上，`00000200~0203` | 避開 |
| `F1~F4`（macOS） | 預設是亮度／調度中心等媒體鍵 | 開「標準功能鍵」或用 `Ctrl+Opt+1~4` |
| `Caps Lock`（macOS） | 系統的「用大寫鎖定鍵切換輸入法」 | 到系統設定手動關掉 |

查 Windows 註冊了哪些輸入法熱鍵：

```powershell
Get-ChildItem 'HKCU:\Control Panel\Input Method\Hot Keys' | ForEach-Object {
  $v = Get-ItemProperty $_.PSPath
  '{0} mod={1:X2} vk={2:X2}' -f $_.PSChildName, $v.'Key Modifiers'[0], $v.'Virtual Key'[0] }
```

