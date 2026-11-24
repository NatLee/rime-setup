<#
.SYNOPSIS
  RIME 方案回歸測試工具（直接呼叫 librime C API，不需開啟輸入法視窗）

.DESCRIPTION
  在「沙盒副本」上執行，不會污染正式的使用者詞庫（*.userdb）。
  修改 lua/yaml 後，用 -Sync 同步到沙盒再測。

.EXAMPLE
  pwsh tools\rime-test.ps1 -Sync -Mode basic      # 黃金樣本回歸（最常用）
  pwsh tools\rime-test.ps1 -Sync -Mode gui        # 小狼毫設定對話框改的配色／方案清單留不留得住
  pwsh tools\rime-test.ps1 -Mode gloss            # 三語釋義檢查
  pwsh tools\rime-test.ps1 -Mode cycle            # 單按右 Shift 循環切換語言
  pwsh tools\rime-test.ps1 -Mode bench            # 量每個按鍵的處理時間
  pwsh tools\rime-test.ps1 -Mode load             # 量切換到某個方案要多久
  pwsh tools\rime-test.ps1 -Mode snapshot > a.txt # 全候選快照（重構前後 diff 用）
  pwsh tools\rime-test.ps1 -Mode cands -Input "6sakura"   # 列出某輸入的全部候選
  pwsh tools\rime-test.ps1 -Mode commit -Input "'/uuid "  # 看某按鍵序列上屏什麼
  pwsh tools\rime-test.ps1 -Mode labels -Input "su3"      # 看前端會拿到的選字鍵／標籤

.NOTES
  測試不會真的開檔案／跑腳本：沙盒裡有 na_test_open.log，lua 的 generic_open 看到它就只記錄、不執行
  （見 rime\lua\p_components\p_generic_open.lua）。所以「選中即執行」的列可以放心按，再用 Get-Opened 驗它開了什麼。

  ⚠ PowerShell 單引號字串裡「反引號」不是跳脫字元：'``1f' 送出的是【兩個】反引號。
    要送單一反引號請用：$g = [char]0x60; "${g}1f "
#>
[CmdletBinding()]
param(
  [ValidateSet('basic', 'gloss', 'cands', 'commit', 'preedit', 'labels', 'examples', 'cycle', 'bench', 'load', 'snapshot', 'gui')]
  [string]$Mode = 'basic',
  [string]$InputSeq = '',
  [string]$Schema = 'bopomo_onionplus',
  [string[]]$Option = @(),            # 測試前開啟的開關，如 -Option en_sort,gloss_en
  [switch]$Sync,                      # 先把 repo 的 rime\ 套用到沙盒
  [switch]$Rebuild,                   # 強制完整重編（改了 yaml 必用）
  [string]$Repo = (Split-Path $PSScriptRoot -Parent),      # 設定 repo（來源是它的 rime\）
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
  Write-Host "套用 $Repo\rime -> $Sandbox ..." -ForegroundColor Cyan
  # 用跟正式安裝同一支 rime-apply.ps1 把 rime\ 攤平到沙盒 —— 測到的就是使用者會拿到的檔案配置。
  # ⚠ 它會依 na_manifest.txt 清掉「repo 已刪除」的舊檔。這一步不能省：
  #   踩過一次 —— p_run_menu.lua 已從 repo 刪掉、translator 卻還 require 它，
  #   沙盒因為留著舊檔所以 53 條全綠，正式環境一部署就會整個 lua 掛掉。
  # -AllowDowngrade：沙盒會被不同分支輪流套用，裡面的版面比這份 repo 新是正常的，不必擋。
  & (Join-Path $Repo 'scripts\rime-apply.ps1') -RimeDir $Sandbox -NoLaunchers -AllowDowngrade -Quiet | Out-Null
  # ⚠ 沙盒自己的 *.userdb 一定要清掉，否則測試不可重現：每次 Get-Commit 上屏都會
  #   被詞庫學習，把剛選的字往前推（測過 su3 → 你 變成 妳，看起來像選字鍵壞了）。
  #   清掉後每次都從方案內建詞典的原始順序開始。
  Get-ChildItem $Sandbox -Directory -Filter '*.userdb*' -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -Confirm:$false
}
# ---------------------------------------------------------------- 動作一律空轉
# 沙盒裡有 na_test_open.log，lua 的 generic_open 就只把「本來要開的東西」記進去、不真的開。
# 每次測試都重建這個檔。以前沒有這道保險：T19 選到主選單第一列（速查表），每跑一次測試就開一次瀏覽器。
$OpenLog = Join-Path $Sandbox 'na_test_open.log'
[IO.File]::WriteAllText($OpenLog, '')
$openGuard = Join-Path $Sandbox 'lua\p_components\p_generic_open.lua'
if (-not ((Test-Path $openGuard) -and (Select-String -LiteralPath $openGuard -SimpleMatch 'na_test_open.log' -Quiet))) {
  throw "沙盒裡的 p_generic_open.lua 沒有空轉保險（找不到 na_test_open.log 的判斷），測試會真的開檔案／跑更新，先停下來。加 -Sync 重新套用後再試。"
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
    [DllImport("rime.dll")] public static extern bool RimeGetCurrentSchema(ulong s, byte[] buf, UIntPtr size);
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

    // ── 以下給 -Mode gui 用：編譯單一設定檔、讀編譯結果、模擬小狼毫的設定對話框 ──
    [DllImport("rime.dll")] public static extern void RimeDeployerInitialize(ref RimeTraitsT t);
    [DllImport("rime.dll")] public static extern bool RimeDeployConfigFile([MarshalAs(UnmanagedType.LPUTF8Str)] string file, [MarshalAs(UnmanagedType.LPUTF8Str)] string versionKey);
    [DllImport("rime.dll")] public static extern bool RimeConfigOpen([MarshalAs(UnmanagedType.LPUTF8Str)] string id, ref IntPtr config);
    [DllImport("rime.dll")] public static extern bool RimeConfigClose(ref IntPtr config);
    [DllImport("rime.dll")] public static extern bool RimeConfigGetString(ref IntPtr config, [MarshalAs(UnmanagedType.LPUTF8Str)] string key, byte[] buf, UIntPtr size);
    [DllImport("rime.dll")] public static extern IntPtr RimeFindModule([MarshalAs(UnmanagedType.LPUTF8Str)] string name);

    public static string ConfigString(string id, string key) {
        IntPtr c = IntPtr.Zero;                     // RimeConfig 只有一個指標欄位
        if (!RimeConfigOpen(id, ref c)) return "(open failed)";
        byte[] buf = new byte[512];
        bool ok = RimeConfigGetString(ref c, key, buf, (UIntPtr)buf.Length);
        RimeConfigClose(ref c);
        if (!ok) return "(none)";
        return System.Text.Encoding.UTF8.GetString(buf, 0, Array.IndexOf(buf, (byte)0));
    }

    // 小狼毫的設定對話框做的事，就是呼叫 librime「levers」模組的這幾個函式再存檔。
    // RimeModule.get_api 在位移 32；RimeLeversApi 是一排函式指標，第 n 個在位移 8*n（順序見 rime_levers_api.h）。
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr LvGetApi();
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr LvInit2([MarshalAs(UnmanagedType.LPUTF8Str)] string configId, [MarshalAs(UnmanagedType.LPUTF8Str)] string generatorId);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr LvInit0();
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int LvInt1(IntPtr settings);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void LvVoid1(IntPtr settings);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int LvStr(IntPtr settings, [MarshalAs(UnmanagedType.LPUTF8Str)] string key, [MarshalAs(UnmanagedType.LPUTF8Str)] string value);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int LvSel(IntPtr settings, IntPtr[] ids, int count);
    static T Lv<T>(int slot) {
        IntPtr module = RimeFindModule("levers");
        IntPtr api = Marshal.GetDelegateForFunctionPointer<LvGetApi>(Marshal.ReadIntPtr(module, 32))();
        return Marshal.GetDelegateForFunctionPointer<T>(Marshal.ReadIntPtr(api, 8 * slot));
    }
    // 「介面風格設定」按確定：UIStyleSettings::SelectColorScheme → customize_string("style/color_scheme")
    public static bool DialogPickColorScheme(string id) {
        IntPtr s = Lv<LvInit2>(1)("weasel", "Weasel::UIStyleSettings");   // custom_settings_init
        Lv<LvInt1>(3)(s);                                                 // load_settings
        Lv<LvStr>(8)(s, "style/color_scheme", id);                        // customize_string
        bool saved = Lv<LvInt1>(4)(s) != 0;                               // save_settings
        Lv<LvVoid1>(2)(s);                                                // custom_settings_destroy
        return saved;
    }
    // 「方案選單設定」按確定：select_schemas
    public static bool DialogSelectSchemas(string[] ids) {
        IntPtr s = Lv<LvInit0>(12)();                                     // switcher_settings_init
        Lv<LvInt1>(3)(s);
        IntPtr[] p = new IntPtr[ids.Length];
        for (int i = 0; i < ids.Length; i++) p[i] = Marshal.StringToCoTaskMemUTF8(ids[i]);
        Lv<LvSel>(22)(s, p, ids.Length);                                  // select_schemas
        bool saved = Lv<LvInt1>(4)(s) != 0;
        Lv<LvVoid1>(2)(s);
        foreach (IntPtr x in p) Marshal.FreeCoTaskMem(x);
        return saved;
    }
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
# -Mode gui 只編譯、讀設定檔，用不到 session（也省得 session 持有的設定物件跟重編後的結果攪在一起）
$session = [uint64]0
if ($Mode -ne 'gui') {
  $session = [RimeT]::RimeCreateSession()
  [RimeT]::RimeSelectSchema($session, $Schema) | Out-Null
  foreach ($o in $Option) { [RimeT]::RimeSetOption($session, $o, $true) | Out-Null }
}

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

# 按下一串按鍵，回傳 lua「本來要開」的東西（每行一筆）。沙盒裡只記錄、不會真的開（見檔頭）。
function Get-Opened([string]$seq) {
  [IO.File]::WriteAllText($OpenLog, '')
  $null = Get-Commit $seq
  return ([IO.File]::ReadAllText($OpenLog)).Trim()
}

# 取編碼列（含段落提示標籤，如《英》▶、【指令與快捷開啟】）。
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
      # T19 選到的是主選單第一列「速查表」（會執行動作）；沙盒裡動作只記錄不執行，A01 驗它開了什麼。
      'T19 選單空白選中'    = @("'/ ", '(no commit)')
      'T20 devkit /uuid'    = @("'/uuid ", '????????-????-????-????-????????????')
      'T21 devkit /ts'      = @("'/ts ", '##########')
      'T22 切日文+sakura'   = @('{Control+Shift+F2}sakura ', 'さくら')
      'T23 切回注音+su3'    = @('{Control+Shift+F1}su3 ', '你')
      # 主選單 ⇧3 是 '/dt（純跳轉到子選單）。
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

    # ── 選單／前綴搜尋：驗編碼列 ──
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

    # ── 選中即執行：按下去之後 lua 要開的是什麼 ──
    # 沙盒裡 generic_open 只記錄不執行（見檔頭），所以可以真的按下去，再比對它「本來要開」的東西。
    # 這幾條釘住：選單列的 run、一級指令代碼、p_run_pattern 的 open 三者有接起來。
    $acases = [ordered]@{
      'A01 主選單空白＝速查表' = @("'/ ",                 'start "" "*cheatsheet.html"')
      'A02 /h 直接開速查表'    = @("'/h ",                'start "" "*cheatsheet.html"')
      # 批次檔用 start "" cmd /c ""路徑""：路徑包兩層引號、斜線換成反斜線，跑完視窗會自己關
      # （為什麼長這樣、為什麼是 popen 不是 os.execute，見 p_generic_open.lua）。
      'A03 /set ⇧1＝選項畫面'  = @("'/set{Shift+exclam}", 'start "" cmd /c ""*\na-setup.cmd""')
      'A04 /setup 直接開'      = @("'/setup ",            'start "" cmd /c ""*\na-setup.cmd""')
      'A05 /git 直接跑更新'    = @("'/git ",              'start "" cmd /c ""*\na-update.cmd""')
      'A06 純跳轉不開東西'     = @("'/dt ",               '')
    }
    foreach ($k in $acases.Keys) {
      $seq, $want = $acases[$k]
      $got = Get-Opened $seq
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

  'cycle' {
    # 單按右 Shift 循環切換語言（lua_processor@schema_cycle）。
    # 預期：照 build\default.yaml 的 schema_list 順序一個一個換，最後繞回第一個；
    # 右 Shift 當修飾鍵用（中間按了別的鍵）或正在組字時不切。
    function Cur { $b = New-Object byte[] 128; [RimeT]::RimeGetCurrentSchema($session, $b, [UIntPtr]128) | Out-Null
                   [Text.Encoding]::UTF8.GetString($b).TrimEnd([char]0) }
    function Tap { [RimeT]::RimeSimulateKeySequence($session, '{Shift_R}{Release+Shift_R}') | Out-Null }
    $all = @(); $skip = @(); $sec = ''
    foreach ($ln in (Get-Content "$Sandbox\build\default.yaml")) {
      if ($ln -match '^([\w]+):') { $sec = $Matches[1] }
      elseif ($sec -eq 'schema_list' -and $ln -match '^\s+-\s*\{?\s*schema:\s*([\w\.\-]+)') { $all += $Matches[1] }
      elseif ($sec -eq 'schema_cycle' -and $ln -match '^\s+-\s*([\w\.\-]+)\s*$') { $skip += $Matches[1] }
    }
    $list = @($all | Where-Object { $skip -notcontains $_ })
    Write-Host ("  循環清單：{0}（跳過 {1} 個）" -f ($list -join ' → '), $skip.Count)
    $pass = 0; $fail = 0
    function Check($name, $got, $want) {
      if ($got -eq $want) { $script:pass++; Write-Host ("  PASS {0,-34} [{1}]" -f $name, $got) -ForegroundColor Green }
      else { $script:fail++; Write-Host ("  FAIL {0,-34} got [{1}] want [{2}]" -f $name, $got, $want) -ForegroundColor Red }
    }
    Check '起點' (Cur) $list[0]
    for ($i = 1; $i -le $list.Count; $i++) { Tap; Check ("單按右 Shift 第 $i 次") (Cur) $list[$i % $list.Count] }
    # 右 Shift 當修飾鍵（Shift_R 按住 + a）：不可以切
    [RimeT]::RimeSimulateKeySequence($session, '{Shift_R}{Shift+A}{Release+Shift_R}') | Out-Null
    [RimeT]::RimeClearComposition($session) | Out-Null
    Check '右 Shift 當修飾鍵不切' (Cur) $list[0]
    # 組字中：不可以切
    [RimeT]::RimeSimulateKeySequence($session, 'su3{Shift_R}{Release+Shift_R}') | Out-Null
    Check '組字中不切' (Cur) $list[0]
    [RimeT]::RimeClearComposition($session) | Out-Null
    # 左 Shift 單按：不切方案（它是中英切換）
    [RimeT]::RimeSimulateKeySequence($session, '{Shift_L}{Release+Shift_L}') | Out-Null
    Check '左 Shift 不切方案' (Cur) $list[0]
    [RimeT]::RimeSimulateKeySequence($session, '{Shift_L}{Release+Shift_L}') | Out-Null
    # 切到別的方案後還打得出字（新方案的元件有正常載入）
    Tap; $c2 = @(Get-Cands 'sakura' 3)
    Check '切到第 2 個方案後仍可輸入' ($c2.Count -gt 0) $true
    Write-Host ''
    Write-Host ("  {0} PASS / {1} FAIL" -f $pass, $fail) -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
  }

  'bench' {
    # 量「每按一鍵引擎要花多久」：逐鍵送出一段注音長句，每鍵之後都把第一頁候選取回來
    # （前端每次按鍵都會這麼做，lua filter 的成本就是花在這裡）。
    # 用法：pwsh tools\rime-test.ps1 -Mode bench            # 預設句子
    #       pwsh tools\rime-test.ps1 -Mode bench -InputSeq "su3cl3"
    $seq = if ($InputSeq) { $InputSeq } else { 'su3cl3ji3g4vu;6j04rup wu0 2k7au4a83' }   # 你好我是學生今天天氣很好…一類的連打
    $rounds = 15
    function One-Pass {
      [RimeT]::RimeClearComposition($session) | Out-Null
      foreach ($ch in $seq.ToCharArray()) {
        $k = if ($ch -eq ' ') { '{space}' } else { [string]$ch }
        [RimeT]::RimeSimulateKeySequence($session, $k) | Out-Null
        $it = New-Object RimeCandListIterT; $n = 0
        if ([RimeT]::RimeCandidateListBegin($session, [ref]$it)) {
          while ($n -lt 6 -and [RimeT]::RimeCandidateListNext([ref]$it)) { $n++ }
          [RimeT]::RimeCandidateListEnd([ref]$it)
        }
      }
      [RimeT]::RimeClearComposition($session) | Out-Null
    }
    One-Pass; One-Pass   # 暖機（第一次會載入詞典與 lua 模組）
    $times = @()
    for ($r = 0; $r -lt $rounds; $r++) {
      $sw = [Diagnostics.Stopwatch]::StartNew(); One-Pass; $sw.Stop()
      $times += $sw.Elapsed.TotalMilliseconds / $seq.Length
    }
    $sorted = $times | Sort-Object
    "{0} 鍵 × {1} 輪｜每鍵 中位數 {2:N2} ms｜最快 {3:N2}｜最慢 {4:N2}" -f $seq.Length, $rounds, $sorted[[int]($rounds / 2)], $sorted[0], $sorted[-1]
  }

  'snapshot' {
    # 重構護欄：把一批輸入的「全部候選（文字＋註解）」與一批按鍵序列的「上屏結果」倒出來。
    # 重構前後各跑一次、存檔後 diff，應該一個字都不差：
    #   pwsh tools\rime-test.ps1 -Sync -Mode snapshot > before.txt
    #   （改程式）
    #   pwsh tools\rime-test.ps1 -Sync -Mode snapshot > after.txt ; git diff --no-index before.txt after.txt
    # 會隨時間變的輸出（日期時間、uuid、隨機密碼、記憶體用量）不放進來。
    $g = [char]0x60
    $candSeqs = @(
      "'/", "'//", "'/;", "'/'", "'/x", "'/u", "'/c", "'/o", "'/i",
      "'//hello", "'//hello.world", "'//hello/world-x", "'/;hello", "'/;hello.world", "'/'hello", "'/'hello.world",
      "'/1", "'/12345", "'/123.45", "'/-12.5", "'/0", "'/1234567890",
      "'/123a45x2", "'/q1a2wx3", "'/1.5v0.5", "'/2s10",
      "'/u4e2d", "'/x4e2d", "'/c20013", "'/o47055", "'/ie4bda0",
      "'/dev", "'/code", "'/set", "'/case", "'/k", "'/kk", "'/ko", "'/gi", "'/ph", "'/j", "'/jh",
      "'/rgb1a73e8", "'/cshello.world",
      '3hello', '3hello;', '3hello;;', '3app', '3hello.world;', '4cafe', '66privet', '77alpha',
      '6sakura', '6arigatou', '6sakura;', '6sakura;;', '7gksrmf',
      'al ', 'vul4', 'g0 ', 'u ', 'ul4', 'xu4', '5j/ ', 'e04', 'm,4', 'su3wj/ ',   # emoji 聯想、罕用字過濾、標註（opencc 字典）
      'su3', 'su3cl3', 'ji3g4', '=oiar', "';su3", "${g}1f", 'email', 'abc@def.com', 'www.abc.com'
    )
    $commitSeqs = @(
      'su3 ', 'su3cl3 ', 'su3{Return}', '3hello ', '3hello; ', '3hello;; ', '6sakura ', '4cafe ', '7gksrmf ',
      "'/12345 ", "'/123a45x2 ", "'/12{KP_3}{KP_Add}{KP_4} ", "'//hello ", "'/u4e2d ", "'/jzz ",
      'su3{Shift+exclam}', "'/12345{Shift+at}", 'su3cl3{Left}{Left}{Left} ', '3hello{Left}{Left} ', '6sakura{Left}{Left} ',
      '{Shift+less}', '{Shift+greater}', 'su3{Shift+less}', 'email{Shift+exclam}'
    )
    '##### candidates'
    foreach ($s in $candSeqs) {
      "## [$s]"
      foreach ($c in (Get-Cands $s 80)) { "{0}`t{1}`t{2}" -f $c.i, $c.text, ($c.comment -replace "`r?`n", '\n') }
      "   preedit: " + (Get-Preedit $s)
    }
    '##### commits'
    foreach ($s in $commitSeqs) { "## [$s] => " + ((Get-Commit $s) -replace "`r?`n", '\n') }
    '##### commits with ascii_punct'
    [RimeT]::RimeSetOption($session, 'ascii_punct', $true) | Out-Null
    foreach ($s in @('{Shift+less}', '{Shift+greater}', 'su3{Shift+less}', 'su3{Shift+greater}', 'su3 ')) { "## [$s] => " + ((Get-Commit $s) -replace "`r?`n", '\n') }
    [RimeT]::RimeSetOption($session, 'ascii_punct', $false) | Out-Null
  }

  'load' {
    # 量「切到某個方案要多久」：切換方案時引擎要重建整條元件鏈（開詞典、開使用者詞庫、
    # 初始化 opencc、跑各 lua 元件的 init）。每鍵延遲看 -Mode bench，這個看的是
    # 「按右 Shift 繞回注音那一下」和「在新視窗第一次用輸入法」的停頓。
    # 用法：pwsh tools\rime-test.ps1 -Mode load                  # 量 -Schema（預設注音主方案）
    #       pwsh tools\rime-test.ps1 -Mode load -Schema jpnin1
    $other = if ($Schema -eq 'easy_en_lower') { 'fullshape' } else { 'easy_en_lower' }
    $rounds = 12; $times = @()
    for ($r = 0; $r -lt $rounds + 2; $r++) {
      [RimeT]::RimeSelectSchema($session, $other) | Out-Null     # 先切走，讓目標方案的元件全部釋放
      $sw = [Diagnostics.Stopwatch]::StartNew()
      [RimeT]::RimeSelectSchema($session, $Schema) | Out-Null
      $sw.Stop()
      if ($r -ge 2) { $times += $sw.Elapsed.TotalMilliseconds }   # 前兩輪暖機（檔案快取）
    }
    $sorted = $times | Sort-Object
    "載入 {0} × {1} 次｜中位數 {2:N0} ms｜最快 {3:N0}｜最慢 {4:N0}" -f $Schema, $rounds, $sorted[[int]($rounds / 2)], $sorted[0], $sorted[-1]
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

  'gui' {
    # 小狼毫「輸入法設定」對話框改的東西（配色、方案清單）留不留得住、跟 '/setup 會不會打架。
    # 對話框做的事就是呼叫 librime 的 levers API 再存檔；這裡用同一支 rime.dll 的同一組 API 照做一次，
    # 寫出來的檔跟真的在對話框按確定一模一樣。驗三件事：
    #   ① 對話框選的會生效  ② 之後再套用（＝更新）不會被蓋掉  ③ 在 '/setup 重選會取代它
    # 這條路以前壞過兩次（選了沒反應、更新後被蓋掉），而且沙盒的其他模式完全測不到。
    $owned = 'weasel.custom.yaml', 'default.custom.yaml'
    $extra = 'na_style.custom.yaml', 'na_input.custom.yaml', 'na_menu.custom.yaml', 'na-update.cmd', 'na-setup.cmd',
             'weasel.custom.yaml.bak', 'default.custom.yaml.bak'
    $saved = @{}
    foreach ($n in $owned + $extra) {
      $p = Join-Path $Sandbox $n
      if (Test-Path -LiteralPath $p) { $saved[$n] = @{ bytes = [IO.File]::ReadAllBytes($p); time = (Get-Item -LiteralPath $p).LastWriteTimeUtc } }
    }
    $pass = 0; $fail = 0
    function Check($name, $got, $want) {
      if ($got -eq $want) { $script:pass++; Write-Host ("  PASS {0,-40} [{1}]" -f $name, $got) -ForegroundColor DarkGray }
      else { $script:fail++; Write-Host ("  FAIL {0,-40} got [{1}] want [{2}]" -f $name, $got, $want) -ForegroundColor Red }
    }
    # librime 判斷「要不要重編」是比檔案時間，而且只比到秒。測試在同一秒內改檔、編譯、再改檔，
    # 它會以為沒變。所以每次編譯前把這幾個檔的時間往後推（真實操作不會一秒內改兩次，沒有這個問題）。
    $tick = [datetime]::UtcNow.Date.AddSeconds([math]::Floor([datetime]::UtcNow.TimeOfDay.TotalSeconds) + 0.5)
    function Compile([switch]$Raw) {
      if (-not $Raw) {
        $script:tick = $script:tick.AddSeconds(2)
        foreach ($n in $owned + $extra) { $p = Join-Path $Sandbox $n; if (Test-Path -LiteralPath $p) { (Get-Item -LiteralPath $p).LastWriteTimeUtc = $script:tick } }
      }
      foreach ($f in 'default.yaml', 'weasel.yaml') {
        if (-not [RimeT]::RimeDeployConfigFile($f, 'config_version')) { throw "編譯 $f 失敗（部署模組沒載入？）" }
      }
    }
    # ⚠ RimeInitialize 不會載入部署用的模組（levers）；不先做這一步，RimeDeployConfigFile 會安靜地
    #   回 false、什麼都沒編譯，後面讀到的全是上次留下的舊結果（寫這個模式時就被它騙過一輪）。
    [RimeT]::RimeDeployerInitialize([ref]$traits)
    function Color { Compile; [RimeT]::ConfigString('weasel', 'style/color_scheme') }
    function Schemas { Compile; (0..3 | ForEach-Object { [RimeT]::ConfigString('default', "schema_list/@$_/schema") } | Where-Object { $_ -ne '(none)' }) -join ',' }
    function Text($n) { [IO.File]::ReadAllText((Join-Path $Sandbox $n)) }
    function Reapply { (& (Join-Path $Repo 'scripts\rime-apply.ps1') -RimeDir $Sandbox -NoLaunchers -AllowDowngrade -Quiet | Select-Object -Last 1).Build }
    # 跟 scripts\rime-setup.cmd 同樣的跑法（明確用 UTF-8 讀進來當 script block）：目標指到沙盒、不問、不部署。
    # -Font system：別在測試裡下載安裝字型。
    function Setup([string]$extraArgs) {
      $names = 'NA_HOME', 'NA_LOCAL', 'NA_NO_DEPLOY', 'NA_RIME_DIR', 'NA_YES', 'NA_INSTALL'
      $old = @{}; foreach ($n in $names) { $old[$n] = [Environment]::GetEnvironmentVariable($n) }
      $env:NA_HOME = $Repo; $env:NA_LOCAL = '1'; $env:NA_NO_DEPLOY = '1'; $env:NA_RIME_DIR = $Sandbox; $env:NA_YES = '1'
      $env:NA_INSTALL = Join-Path $Repo 'install.ps1'
      try {
        $out = & pwsh -NoProfile -ExecutionPolicy Bypass -Command "`$global:NaSetupOk = `$false; & ([scriptblock]::Create([IO.File]::ReadAllText(`$env:NA_INSTALL, [Text.Encoding]::UTF8))) -Font system $extraArgs; if (-not `$global:NaSetupOk) { exit 1 }" 2>&1
        if ($LASTEXITCODE -ne 0) { Write-Host ($out -join "`n") -ForegroundColor Yellow }
        return ($LASTEXITCODE -eq 0)
      } finally { foreach ($n in $names) { [Environment]::SetEnvironmentVariable($n, $old[$n]) } }
    }
    try {
      # 起點：兩個使用者檔回到剛裝好的樣子（只有一行 __include）、沒有個人選項檔
      foreach ($n in $owned + $extra) { Remove-Item -LiteralPath (Join-Path $Sandbox $n) -Force -ErrorAction SilentlyContinue }
      [void](Reapply)
      $base = ''
      foreach ($ln in (Get-Content (Join-Path $Repo 'rime\core\na_style.yaml') -Encoding UTF8)) { if ($ln -match '^theme:\s*(\S+)') { $base = $Matches[1] } }
      $pick = 'NatSakura'; if ($base -eq $pick) { $pick = 'NatOcean' }

      Check 'G01 起點＝預設主題'                 (Color) $base
      Check 'G02 repo 的配色定義有接上'          ([RimeT]::ConfigString('weasel', "preset_color_schemes/$pick/name") -ne '(none)') $true
      Check 'G03 repo 的全域設定有接上'          ([RimeT]::ConfigString('default', 'schema_cycle/skip/@0') -ne '(none)') $true
      $allSchemas = Schemas

      # ── 配色 ──
      Check 'G04 對話框存檔成功'                 ([RimeT]::DialogPickColorScheme($pick)) $true
      Check 'G05 對話框選的配色會生效'           (Color) $pick
      Check 'G06 存檔後仍接著 repo 的設定'       ((Text 'weasel.custom.yaml') -match 'na_weasel:/patch') $true
      $before = Text 'weasel.custom.yaml'
      Check 'G07 再套用（＝更新）沒有檔案變動'   (Reapply) 0
      Check 'G08 再套用不動使用者的檔'           ((Text 'weasel.custom.yaml') -ceq $before) $true
      Check 'G09 更新後配色還在'                 (Color) $pick

      # ── 方案清單 ──
      Check 'G10 對話框存檔成功'                 ([RimeT]::DialogSelectSchemas(@('bopomo_onionplus', 'easy_en_lower'))) $true
      Check 'G11 對話框勾的方案會生效'           (Schemas) 'bopomo_onionplus,easy_en_lower'
      Check 'G12 再套用（＝更新）沒有檔案變動'   (Reapply) 0
      Check 'G13 更新後方案清單還在'             (Schemas) 'bopomo_onionplus,easy_en_lower'

      # ── '/setup 直接按 Enter：對話框選的主題收進選項檔；自訂的方案清單不動 ──
      Check 'G14 setup（不改任何項目）'          (Setup '') $true
      Check 'G15 主題沒變'                       (Color) $pick
      Check 'G16 主題已收進選項檔'               ((Text 'na_style.custom.yaml') -match "(?m)^  theme: $pick\s*$") $true
      Check 'G17 對話框那一筆配色已拿掉'         ((Text 'weasel.custom.yaml') -match 'style/color_scheme') $false
      Check 'G18 沒重選語言，方案清單不動'       (Schemas) 'bopomo_onionplus,easy_en_lower'
      $optBefore = (Text 'na_style.custom.yaml') + (Text 'weasel.custom.yaml') + (Text 'default.custom.yaml')
      $optTime = (Get-Item -LiteralPath (Join-Path $Sandbox 'na_style.custom.yaml')).LastWriteTimeUtc
      Check 'G19 再跑一次 setup 沒有任何變動'    ((Setup '') -and ((Reapply) -eq 0) -and
                                                 (((Text 'na_style.custom.yaml') + (Text 'weasel.custom.yaml') + (Text 'default.custom.yaml')) -ceq $optBefore) -and
                                                 ((Get-Item -LiteralPath (Join-Path $Sandbox 'na_style.custom.yaml')).LastWriteTimeUtc -eq $optTime)) $true

      # ── '/setup 重選：取代對話框選的 ──
      Check 'G20 setup 重選主題與語言'           (Setup '-Theme ocean -Langs ja') $true
      Check 'G21 主題換成 setup 選的'            (Color) 'NatOcean'
      Check 'G22 方案清單換成 setup 選的'        (Schemas) 'bopomo_onionplus,jpnin1'
      Check 'G23 對話框那一筆方案已拿掉'         ((Text 'default.custom.yaml') -match '(?m)^  "?schema_list') $false
      Check 'G24 兩個使用者檔仍接著 repo'        (((Text 'default.custom.yaml') -match 'na_default:/patch') -and ((Text 'weasel.custom.yaml') -match 'na_weasel:/patch')) $true

      # ── setup 之後再用對話框：對話框贏（誰最後動手就聽誰的）──
      [void][RimeT]::DialogPickColorScheme($pick)
      Check 'G25 setup 之後對話框再選仍生效'     (Color) $pick

      # ── 對話框選了「不是這套」的配色（使用者自己加的）：setup 沒重選主題就不動它 ──
      [void][RimeT]::DialogPickColorScheme('my_own_scheme')
      Check 'G26 setup（不改主題）'              (Setup '') $true
      Check 'G27 自訂配色原樣留著'               (Color) 'my_own_scheme'
      Check 'G28 setup 重選主題'                 (Setup '-Theme light') $true
      Check 'G29 自訂配色被 setup 取代'          (Color) 'NatLight'

      # ── 舊版面升級：weasel.custom.yaml 整個是 repo 的內容＋檔尾有對話框選的配色 ──
      [IO.File]::WriteAllText((Join-Path $Sandbox 'weasel.custom.yaml'), "patch:`n  style:`n    color_scheme: { __include: `"na_options:/theme`" }`n`n  `"style/color_scheme`": $pick`n")
      Remove-Item -LiteralPath (Join-Path $Sandbox 'na_style.custom.yaml') -Force
      Check 'G30 舊版面的檔會被換成新格式'       ((Reapply) -gt 0) $true
      Check 'G31 舊版面裡對話框選的配色帶過來'   (Color) $pick
      Check 'G33 換掉之前原檔留了一份 .bak'      ((Text 'weasel.custom.yaml.bak') -match 'na_options:/theme') $true
      Check 'G32 換完之後再套用沒有變動'         (Reapply) 0
    } finally {
      # 沙盒回到測試前的樣子（連檔案時間一起還原，其他模式才不必為此重編）
      foreach ($n in $owned + $extra) {
        $p = Join-Path $Sandbox $n
        if ($saved.ContainsKey($n)) { [IO.File]::WriteAllBytes($p, $saved[$n].bytes); (Get-Item -LiteralPath $p).LastWriteTimeUtc = $saved[$n].time }
        else { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
      }
      Compile -Raw
    }
    Write-Host ''
    Write-Host ("  {0} PASS / {1} FAIL" -f $pass, $fail) -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
  }
}

if ($session) { [RimeT]::RimeDestroySession($session) | Out-Null }
[RimeT]::RimeFinalize()
