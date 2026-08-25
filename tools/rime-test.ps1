<#
.SYNOPSIS
  RIME 方案回歸測試工具（直接呼叫 librime C API，不需開啟輸入法視窗）

.DESCRIPTION
  在「沙盒副本」上執行，不會污染正式的使用者詞庫（*.userdb）。
  修改 C:\RIME 的 lua/yaml 後，用 -Sync 同步到沙盒再測。

.EXAMPLE
  pwsh tools\rime-test.ps1 -Sync -Mode basic      # 23 條基本回歸（最常用）
  pwsh tools\rime-test.ps1 -Mode gloss            # 三語釋義檢查
  pwsh tools\rime-test.ps1 -Mode cands -Input "6sakura"   # 列出某輸入的全部候選
  pwsh tools\rime-test.ps1 -Mode commit -Input "'/uuid "  # 看某按鍵序列上屏什麼
  pwsh tools\rime-test.ps1 -Mode labels -Input "su3"      # 看前端會拿到的選字鍵／標籤

.NOTES
  ⚠ PowerShell 單引號字串裡「反引號」不是跳脫字元：'``1f' 送出的是【兩個】反引號。
    要送單一反引號請用：$g = [char]0x60; "${g}1f "
#>
[CmdletBinding()]
param(
  [ValidateSet('basic', 'gloss', 'cands', 'commit', 'preedit', 'labels', 'examples')]
  [string]$Mode = 'basic',
  [string]$InputSeq = '',
  [string]$Schema = 'bopomo_onionplus',
  [string[]]$Option = @(),            # 測試前開啟的開關，如 -Option en_sort,gloss_en
  [switch]$Sync,                      # 先把 C:\RIME 同步到沙盒
  [switch]$Rebuild,                   # 強制完整重編（改了 yaml 必用）
  [string]$RimeDir = 'C:\RIME',
  [string]$Sandbox = "$env:TEMP\rime_sandbox",
  [string]$WeaselRoot = ''
)

$ErrorActionPreference = 'Stop'

if (-not $WeaselRoot) {
  $reg = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Rime\Weasel' -ErrorAction SilentlyContinue
  if (-not $reg) { $reg = Get-ItemProperty 'HKLM:\SOFTWARE\Rime\Weasel' }
  $WeaselRoot = $reg.WeaselRoot
}

# ---------------------------------------------------------------- 同步沙盒
if ($Sync -or -not (Test-Path "$Sandbox\build")) {
  Write-Host "同步 $RimeDir -> $Sandbox ..." -ForegroundColor Cyan
  New-Item -ItemType Directory -Force $Sandbox | Out-Null
  # 排除使用者詞庫與 git，避免污染正式資料
  $xd = @('.git', 'sync', 'tools', '_cleanup*') + (Get-ChildItem $RimeDir -Directory -Filter '*.userdb*' | ForEach-Object { $_.Name })
  # ⚠ 一定要 /PURGE：只有 /E 的話，來源已刪除的檔案會**留在沙盒**，測試對著幽靈檔跑。
  #   踩過一次 —— p_run_menu.lua 已從 repo 刪掉、translator 卻還 require 它，
  #   沙盒因為留著舊檔所以 53 條全綠，正式環境一部署就會整個 lua 掛掉。
  robocopy $RimeDir $Sandbox /E /PURGE /XD @xd /XF '*.zip' '*.bak' /NJH /NJS /NDL /NFL | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy 失敗 ($LASTEXITCODE)" }
  # ⚠ 沙盒自己的 *.userdb 一定要清掉，否則測試不可重現：每次 Get-Commit 上屏都會
  #   被詞庫學習，把剛選的字往前推（測過 su3 → 你 變成 妳，看起來像選字鍵壞了）。
  #   清掉後每次都從方案內建詞典的原始順序開始。
  Get-ChildItem $Sandbox -Directory -Filter '*.userdb*' -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -Confirm:$false
}

# ---------------------------------------------------------------- P/Invoke
if (-not ([System.Management.Automation.PSTypeName]'RimeT').Type) {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential)]
public struct RimeTraitsT {
    public int data_size;
    [MarshalAs(UnmanagedType.LPUTF8Str)] public string shared_data_dir;
    [MarshalAs(UnmanagedType.LPUTF8Str)] public string user_data_dir;
    [MarshalAs(UnmanagedType.LPUTF8Str)] public string distribution_name;
    [MarshalAs(UnmanagedType.LPUTF8Str)] public string distribution_code_name;
    [MarshalAs(UnmanagedType.LPUTF8Str)] public string distribution_version;
    [MarshalAs(UnmanagedType.LPUTF8Str)] public string app_name;
    public IntPtr modules;
    public int min_log_level;
    [MarshalAs(UnmanagedType.LPUTF8Str)] public string log_dir;
    [MarshalAs(UnmanagedType.LPUTF8Str)] public string prebuilt_data_dir;
    [MarshalAs(UnmanagedType.LPUTF8Str)] public string staging_dir;
}
[StructLayout(LayoutKind.Sequential)]
public struct RimeCommitT { public int data_size; public IntPtr text; }
[StructLayout(LayoutKind.Sequential)]
public struct RimeCandidateT { public IntPtr text; public IntPtr comment; public IntPtr reserved; }
[StructLayout(LayoutKind.Sequential)]
public struct RimeCandListIterT { public IntPtr ptr; public int index; public RimeCandidateT candidate; }
[StructLayout(LayoutKind.Sequential)]
public struct RimeCompositionT { public int length; public int cursor_pos; public int sel_start; public int sel_end; public IntPtr preedit; }
[StructLayout(LayoutKind.Sequential)]
public struct RimeMenuT {
    public int page_size; public int page_no; public int is_last_page;
    public int highlighted_candidate_index; public int num_candidates;
    public IntPtr candidates; public IntPtr select_keys;
}
[StructLayout(LayoutKind.Sequential)]
public struct RimeContextT {
    public int data_size; public RimeCompositionT composition; public RimeMenuT menu;
    public IntPtr commit_text_preview; public IntPtr select_labels;
}
public static class RimeT {
    [DllImport("rime.dll")] public static extern void RimeSetup(ref RimeTraitsT t);
    [DllImport("rime.dll")] public static extern void RimeInitialize(ref RimeTraitsT t);
    [DllImport("rime.dll")] public static extern void RimeFinalize();
    [DllImport("rime.dll")] public static extern bool RimeStartMaintenance(bool full_check);
    [DllImport("rime.dll")] public static extern void RimeJoinMaintenanceThread();
    [DllImport("rime.dll")] public static extern ulong RimeCreateSession();
    [DllImport("rime.dll")] public static extern bool RimeDestroySession(ulong s);
    [DllImport("rime.dll")] public static extern bool RimeSelectSchema(ulong s, [MarshalAs(UnmanagedType.LPUTF8Str)] string id);
    [DllImport("rime.dll")] public static extern bool RimeSimulateKeySequence(ulong s, [MarshalAs(UnmanagedType.LPUTF8Str)] string keys);
    [DllImport("rime.dll")] public static extern bool RimeGetCommit(ulong s, ref RimeCommitT c);
    [DllImport("rime.dll")] public static extern bool RimeFreeCommit(ref RimeCommitT c);
    [DllImport("rime.dll")] public static extern bool RimeClearComposition(ulong s);
    [DllImport("rime.dll")] public static extern bool RimeSetOption(ulong s, [MarshalAs(UnmanagedType.LPUTF8Str)] string opt, bool val);
    [DllImport("rime.dll")] public static extern bool RimeGetContext(ulong s, ref RimeContextT c);
    [DllImport("rime.dll")] public static extern bool RimeFreeContext(ref RimeContextT c);
    [DllImport("rime.dll")] public static extern bool RimeCandidateListBegin(ulong s, ref RimeCandListIterT it);
    [DllImport("rime.dll")] public static extern bool RimeCandidateListNext(ref RimeCandListIterT it);
    [DllImport("rime.dll")] public static extern void RimeCandidateListEnd(ref RimeCandListIterT it);
}
"@ -CompilerOptions "/unsafe"
}

$env:PATH = "$WeaselRoot;$env:PATH"
[System.IO.Directory]::SetCurrentDirectory($WeaselRoot)

$traits = New-Object RimeTraitsT
$traits.shared_data_dir = Join-Path $WeaselRoot 'data'
$traits.user_data_dir = $Sandbox
$traits.distribution_name = 'Weasel'
$traits.distribution_code_name = 'Weasel'
$traits.distribution_version = '0.17.4'
$traits.app_name = 'rime.test'
$traits.min_log_level = 3
$traits.log_dir = "$Sandbox\log"
$traits.staging_dir = "$Sandbox\build"
$traits.data_size = [Runtime.InteropServices.Marshal]::SizeOf([type][RimeTraitsT]) - 4
New-Item -ItemType Directory -Force "$Sandbox\log" | Out-Null

[RimeT]::RimeSetup([ref]$traits)
[RimeT]::RimeInitialize([ref]$traits)
if ($Rebuild -or $Sync) {
  [RimeT]::RimeStartMaintenance($true) | Out-Null
  [RimeT]::RimeJoinMaintenanceThread()
}
Start-Sleep -Milliseconds 800
$session = [RimeT]::RimeCreateSession()
[RimeT]::RimeSelectSchema($session, $Schema) | Out-Null
foreach ($o in $Option) { [RimeT]::RimeSetOption($session, $o, $true) | Out-Null }

# ---------------------------------------------------------------- 輔助函式
function Get-Commit([string]$seq) {
  [RimeT]::RimeClearComposition($session) | Out-Null
  [RimeT]::RimeSimulateKeySequence($session, $seq) | Out-Null
  $c = New-Object RimeCommitT
  $c.data_size = [Runtime.InteropServices.Marshal]::SizeOf([type][RimeCommitT]) - 4
  $got = [RimeT]::RimeGetCommit($session, [ref]$c)
  $t = if ($got -and $c.text -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::PtrToStringUTF8($c.text) } else { '(no commit)' }
  [RimeT]::RimeFreeCommit([ref]$c) | Out-Null
  [RimeT]::RimeClearComposition($session) | Out-Null
  return $t
}

function Get-Cands([string]$seq, [int]$max = 16) {
  [RimeT]::RimeClearComposition($session) | Out-Null
  [RimeT]::RimeSimulateKeySequence($session, $seq) | Out-Null
  $rows = @()
  $it = New-Object RimeCandListIterT
  $n = 0
  if ([RimeT]::RimeCandidateListBegin($session, [ref]$it)) {
    while ($n -lt $max -and [RimeT]::RimeCandidateListNext([ref]$it)) {
      $t = if ($it.candidate.text -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::PtrToStringUTF8($it.candidate.text) } else { '' }
      $m = if ($it.candidate.comment -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::PtrToStringUTF8($it.candidate.comment) } else { '' }
      $rows += [pscustomobject]@{ i = $n; text = $t; comment = $m }
      $n++
    }
    [RimeT]::RimeCandidateListEnd([ref]$it)
  }
  [RimeT]::RimeClearComposition($session) | Out-Null
  return $rows
}

# 取編碼列（含段落提示標籤，如《英》▶、【指令與快捷開啟】）。
# 選單類的驗證要用這個，不能用 Get-Commit —— 指令選單每一列選中都會真的
# 開檔案／跑腳本（'/jgit 會 git pull ＋部署＋重啟服務）。
function Get-Preedit([string]$seq) {
  [RimeT]::RimeClearComposition($session) | Out-Null
  [RimeT]::RimeSimulateKeySequence($session, $seq) | Out-Null
  $c = New-Object RimeContextT
  $c.data_size = [Runtime.InteropServices.Marshal]::SizeOf([type][RimeContextT]) - 4
  $pre = ''
  if ([RimeT]::RimeGetContext($session, [ref]$c)) {
    if ($c.composition.preedit -ne [IntPtr]::Zero) {
      $pre = [Runtime.InteropServices.Marshal]::PtrToStringUTF8($c.composition.preedit)
    }
    [RimeT]::RimeFreeContext([ref]$c) | Out-Null
  }
  [RimeT]::RimeClearComposition($session) | Out-Null
  return $pre
}

# ---------------------------------------------------------------- 測試模式
switch ($Mode) {

  'basic' {
    # 23 條黃金樣本：涵蓋注音、計算機、Unicode、日期、選單、devkit、方案切換
    $cases = [ordered]@{
      'T01 注音 su3'        = @('su3 ', '你')
      'T02 日期 /f'         = @("'/f ", (Get-Date -Format 'yyyyMMdd'))
      'T03 年月 /ym'        = @("'/ym ", (Get-Date -Format 'yyyyMM'))
      'T04 指定日 /3y5m2d'  = @("'/3y5m2d ", '3年5月2日')
      'T05 數字 /12345'     = @("'/12345 ", '12345')
      'T06 計算 /123a45x2'  = @("'/123a45x2 ", '213')
      'T07 括號 /q123a45wx2'= @("'/q123a45wx2 ", '336')
      'T08 除法 /1.5v0.5'   = @("'/1.5v0.5 ", '3')
      'T09 小寫 //hello'    = @("'//hello ", 'hello')
      'T10 大寫 /;hello'    = @("'/;hello ", 'HELLO')
      'T11 首大 /''hello'   = @("'/'hello ", 'Hello')
      'T12 內碼 /u4e2d'     = @("'/u4e2d ", '中')
      'T13 內碼 /x4e2d'     = @("'/x4e2d ", '中')
      'T14 內碼 /c20013'    = @("'/c20013 ", '中')
      'T15 內碼 /o47055'    = @("'/o47055 ", '中')
      'T16 URL  /ie4bda0'   = @("'/ie4bda0 ", '你')
      'T17 版本 /v'         = @("'/v ", '*Weasel*')
      'T18 鍵表 /kk'        = @("'/kk ", '*')
      # T19／T24／T25 釘住「選單選中會上屏字面代碼」這個回歸：
      # p_run_files 沒在 rime.lua bind、或排在 mix_apc_s2rm_ltk／selector 之後時，
      # 空白與 ⇧1~6 會先被別人吃掉，畫面上就是吐出 '/dt、'/jh 這種字面字串。
      # 正確行為是「跳到子選單」或「執行動作」，兩者都不上屏。
      # ⚠ 別拿 '/j 那一頁的列當樣本：它每一列選中都會真的開檔案／瀏覽器。
      'T19 選單空白選中'    = @("'/ ", '(no commit)')
      'T20 devkit /uuid'    = @("'/uuid ", '????????-????-????-????-????????????')
      'T21 devkit /ts'      = @("'/ts ", '##########')
      'T22 切日文+sakura'   = @('{Control+Shift+F2}sakura ', 'さくら')
      'T23 切回注音+su3'    = @('{Control+Shift+F1}su3 ', '你')
      # ⚠ 主選單 ⇧1 是 '/j（進子選單，安全）、⇧2 是「更新設定」——後者選中會**真的**
      #   跑 scripts/rime-update.ps1（git pull → 部署 → 重啟）。測試一律避開 ⇧2，
      #   改用 ⇧3（'/dt，純跳轉無副作用）。
      'T24 選單⇧3 選中'     = @("'/{Shift+numbersign}", '(no commit)')
      'T25 子選單⇧1 選中'   = @("'/dt{Shift+exclam}", '(no commit)')
      # T26~T29 釘住「⇧1~6 選字」這條鏈。本方案**不設** menu/alternative_select_keys
      # （設了 macOS 標籤就變 !@#$%^），選字是 lua_processor@p_select_keys 做的，
      # 所以這幾條同時在測：yaml 有掛、rime.lua 有 bind、鏈上位置沒被搶。
      # T26 走完整兩層：'/ ⇧3 → '/dt，再 ⇧1 → '/f，空白上屏日期。
      'T26 兩層選單⇧n 貫通' = @("'/{Shift+numbersign}{Shift+exclam} ", (Get-Date -Format 'yyyyMMdd'))
      # ⚠ 不可以寫死「你」「妳」：沙盒詞庫會學習，每上屏一次就把那個字往前推，
      #   候選順序跟著漂移，測起來時綠時紅（查過一輪，不是選字鍵壞掉）。
      #   (cand:N) ＝ 當場問引擎「現在第 N 個候選是什麼」再比。
      'T27 選字鍵⇧1'        = @('su3{Shift+exclam}', '(cand:0)')
      # ⇧2 拿計算機來測，不用注音：注音輸入按 ⇧2 會被 email 樣式接走（見
      # docs/GOTCHAS.md「⇧2 在注音輸入時選不到字」），那是上游設計不是回歸。
      # 這一條同時釘住「別用 key_binder 轉 KP_2」——那樣 '/12345 按 ⇧2 會變成
      # 把「2」打進算式（'/123452），拿不到「12,345」。
      'T28 選字鍵⇧2（計算機）' = @("'/12345{Shift+at}", '12,345')
      # 數字鍵是注音編碼，絕不能變成選字鍵（select_keys 留空後 selector 的
      # 數字分支會活過來，靠 speller 排在 selector 之前擋住）
      'T29 數字不選字'      = @('su31 ', '(no commit)')
    }
    $pass = 0; $fail = 0
    foreach ($k in $cases.Keys) {
      $seq, $want = $cases[$k]
      # (cand:N) 必須在「上屏之前」就換算成實際候選：上屏本身會把該字往前推，
      # 事後再問順序就已經變了（查過一輪，別再改回事後比對）。
      if ($want -match '^\(cand:(\d+)\)$') {
        $i = [int]$Matches[1]
        $base = $seq -replace '\{.*$', ''
        $want = (Get-Cands $base ($i + 1))[$i].text
      }
      $got = Get-Commit $seq
      $ok = switch -Regex ($want) {
        '^\*'  { $got -like $want }
        '\?\?' { $got -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' }
        '^#+$' { $got -match "^\d{$($want.Length)}$" }
        default { $got -eq $want }
      }
      if ($ok) { $pass++; Write-Host ("  PASS {0,-22} [{1}]" -f $k, $got) -ForegroundColor DarkGray }
      else { $fail++; Write-Host ("  FAIL {0,-22} want=[{1}] got=[{2}]" -f $k, $want, $got) -ForegroundColor Red }
    }

    # ── 選單／前綴搜尋：只驗編碼列，不按下去 ──
    # 指令選單每一列選中都會真的執行動作，所以這幾條一律用 preedit 驗證。
    $pcases = [ordered]@{
      'P01 功能總覽'        = @("'/",     '*《功能總覽》*')
      # 一級指令代碼（'/j 命名空間已移除）：打得出提示＝掛上了
      # preedit 的標籤是【指令】；提示文字（速查表／更新…）在候選的 comment，
      # 這裡只驗「這個代碼有被掛上」，掛上與否才是會壞的地方。
      'P02 速查表指令 /h'   = @("'/h",       '*【指令】*')
      'P03 更新指令 /git'   = @("'/git",     '*【指令】*')
      'P04 自訂短語 /phrase' = @("'/phrase",  '*【指令】*')
      'P05 指令清單 /cmd'   = @("'/cmd",     '*【指令】*')
      # 前綴補完：打一半就列出候選
      'P06 gi → git 補完'   = @("'/gi",   "*【代碼 '/gi*")
      'P12 ph → phrase 補完' = @("'/ph",  "*【代碼 '/ph*")
      # '/j 已移除，不該再有任何反應（有的話代表殘留）
      'P17 j 已移除'        = @("'/j",    "'/j")
      'P07 開發小工具'      = @("'/dev",  '*【開發小工具】*')
      'P08 編碼與字母'      = @("'/code", '*【編碼與字母】*')
      # 第三層：以前只能背代碼才找得到的功能，現在每個都有入口
      'P13 日期單項'        = @("'/dty",  '*【日期：單項】*')
      'P14 日期其他'        = @("'/dts",  '*【日期：其他】*')
      'P15 設定與維護'      = @("'/set",  '*【設定與維護】*')
      'P16 字母大小寫'      = @("'/case", '*【字母大小寫】*')
      'P09 ⇧6 到編碼選單'   = @("'/{Shift+asciicircum}", '*【編碼與字母】*')
      'P10 內碼十進制沒被蓋' = @("'/c",   '*【內碼十進制】*')
    }
    foreach ($k in $pcases.Keys) {
      $seq, $want = $pcases[$k]
      $got = Get-Preedit $seq
      if ($got -like $want) { $pass++; Write-Host ("  PASS {0,-22} [{1}]" -f $k, $got) -ForegroundColor DarkGray }
      else { $fail++; Write-Host ("  FAIL {0,-22} want=[{1}] got=[{2}]" -f $k, $want, $got) -ForegroundColor Red }
    }

    # ── 裸代碼前綴搜尋（'/gi → '/git）與它的三道護欄 ──
    # 比對「第一個候選的文字」。C04~C07 是護欄：前綴搜尋若判斷放寬，
    # 這幾個既有功能會被選單蓋掉而靜默消失，而且不會有任何錯誤訊息。
    $ccases = [ordered]@{
      'C01 gi → git'       = @("'/gi",   "'/git")
      'C02 co → code'      = @("'/co",   "'/code")
      'C03 uu → uuid'      = @("'/uu",   "'/uuid")
      'C04 csh 仍是 devkit' = @("'/csh",  'h')          # 蓋掉的話會變成 '/cshello.world
      'C05 rgb1 仍是 devkit'= @("'/rgb1", '')           # 蓋掉的話會變成 '/rgb1a73e8
      'C06 f 仍是日期'      = @("'/f",    '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
      'C07 de 仍是日期'     = @("'/de",   '*th')
      'C08 ts 仍是時間戳'   = @("'/ts",   '[0-9]*')      # 相等不介入，否則蓋掉 devkit
    }
    foreach ($k in $ccases.Keys) {
      $seq, $want = $ccases[$k]
      $rows = Get-Cands $seq 1
      $got = if ($rows.Count) { $rows[0].text } else { '(no cand)' }
      if ($got -like $want) { $pass++; Write-Host ("  PASS {0,-22} [{1}]" -f $k, $got) -ForegroundColor DarkGray }
      else { $fail++; Write-Host ("  FAIL {0,-22} want=[{1}] got=[{2}]" -f $k, $want, $got) -ForegroundColor Red }
    }
    Write-Host "`n  $pass PASS / $fail FAIL" -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
  }

  'gloss' {
    foreach ($lang in @('gloss_zh', 'gloss_en', 'gloss_ja')) {
      [RimeT]::RimeSetOption($session, $lang, $true) | Out-Null
      Write-Host "`n== $lang ==" -ForegroundColor Cyan
      foreach ($w in @('6sakura', '6benkyou')) {
        Get-Cands $w 6 | Where-Object { $_.comment } |
          ForEach-Object { "  {0}  {1}" -f $_.text, $_.comment }
      }
    }
    [RimeT]::RimeSetOption($session, 'gloss_zh', $true) | Out-Null
  }

  'examples' {
    # 產生 cheatsheet.html 用的真實輸入→輸出範例（避免文件寫出憑空編造的例子）
    $g = [char]0x60   # 反引號：PowerShell 單引號內無法跳脫，必須這樣組
    $seqs = @(
      'su3 ', "su3 fu5 ", '3hello ', '3app ', '6sakura ', '6arigatou ',
      '4cafe ', '66privet ', '77alpha ', '=oiar ', "${g}1f ", "';su3 ",
      '][a ', 'email ', "'/f ", "'/t ", "'/fn ", "'/w ", "'/s ", "'/l ",
      "'/3y5m2d ", "'/123a45x2 ", "'/q1a2wx3 ", "'/1.5v0.5 ", "'/u4e2d ",
      "'/c20013 ", "'/ie4bda0 ", "'//hello ", "'/;hello ", "'/'hello ",
      "'/uuid ", "'/ts ", "'/pw ", "'/rgb1a73e8 ", "'/cshello.world ", "'/v "
    )
    foreach ($s in $seqs) { "{0,-18} => {1}" -f "[$s]", (Get-Commit $s) }
  }

  'cands'  { Get-Cands $InputSeq | Format-Table -AutoSize }
  'commit' { "[{0}] => [{1}]" -f $InputSeq, (Get-Commit $InputSeq) }

  'preedit' {
    # 顯示編碼列（含段落提示標籤，如《英》▶／《日》▶）
    [RimeT]::RimeClearComposition($session) | Out-Null
    [RimeT]::RimeSimulateKeySequence($session, $InputSeq) | Out-Null
    $c = New-Object RimeContextT
    $c.data_size = [Runtime.InteropServices.Marshal]::SizeOf([type][RimeContextT]) - 4
    if ([RimeT]::RimeGetContext($session, [ref]$c)) {
      $pre = if ($c.composition.preedit -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::PtrToStringUTF8($c.composition.preedit) } else { '' }
      "[{0}] preedit => [{1}]" -f $InputSeq, $pre
      [RimeT]::RimeFreeContext([ref]$c) | Out-Null
    }
    [RimeT]::RimeClearComposition($session) | Out-Null
  }

  'labels' {
    # 看候選標籤前端會拿到什麼 —— 這是唯一能在 Windows 上驗證「macOS 標籤」的方法：
    # librime 同時交出 menu.select_keys 與 select_labels 兩份資料，而
    #   ‧ 小狼毫 RimeWithWeasel.cpp        ：labels 優先
    #   ‧ 鼠鬚管 SquirrelInputController.swift：**select_keys 優先**，有值就不看 labels
    # 所以 select_keys 必須是 (null)、labels 必須是 ⇧1~⇧6，兩邊才會一致顯示 ⇧1.。
    $seq = if ($InputSeq) { $InputSeq } else { 'su3' }
    [RimeT]::RimeClearComposition($session) | Out-Null
    [RimeT]::RimeSimulateKeySequence($session, $seq) | Out-Null
    $c = New-Object RimeContextT
    $c.data_size = [Runtime.InteropServices.Marshal]::SizeOf([type][RimeContextT]) - 4
    if ([RimeT]::RimeGetContext($session, [ref]$c)) {
      $sk = if ($c.menu.select_keys -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::PtrToStringUTF8($c.menu.select_keys)
      } else { '(null)' }
      $lb = if ($c.select_labels -ne [IntPtr]::Zero) {
        (0..($c.menu.page_size - 1) | ForEach-Object {
          $p = [Runtime.InteropServices.Marshal]::ReadIntPtr($c.select_labels, $_ * [IntPtr]::Size)
          [Runtime.InteropServices.Marshal]::PtrToStringUTF8($p)
        }) -join ' '
      } else { '(null)' }
      "[{0}]  page_size={1}" -f $seq, $c.menu.page_size
      "  menu.select_keys = [{0}]   ← 鼠鬚管優先用這個，必須是 (null)" -f $sk
      "  select_labels    = [{0}]   ← 兩邊真正想顯示的標籤" -f $lb
      [RimeT]::RimeFreeContext([ref]$c) | Out-Null
    }
    [RimeT]::RimeClearComposition($session) | Out-Null
  }
}

[RimeT]::RimeDestroySession($session) | Out-Null
[RimeT]::RimeFinalize()
