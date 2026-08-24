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

.NOTES
  ⚠ PowerShell 單引號字串裡「反引號」不是跳脫字元：'``1f' 送出的是【兩個】反引號。
    要送單一反引號請用：$g = [char]0x60; "${g}1f "
#>
[CmdletBinding()]
param(
  [ValidateSet('basic', 'gloss', 'cands', 'commit', 'preedit')]
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
  robocopy $RimeDir $Sandbox /E /XD @xd /XF '*.zip' '*.bak' /NJH /NJS /NDL /NFL | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy 失敗 ($LASTEXITCODE)" }
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
      'T19 開啟 /j'         = @("'/j ", '*')
      'T20 devkit /uuid'    = @("'/uuid ", '????????-????-????-????-????????????')
      'T21 devkit /ts'      = @("'/ts ", '##########')
      'T22 切日文+sakura'   = @('{Control+Shift+F2}sakura ', 'さくら')
      'T23 切回注音+su3'    = @('{Control+Shift+F1}su3 ', '你')
    }
    $pass = 0; $fail = 0
    foreach ($k in $cases.Keys) {
      $seq, $want = $cases[$k]
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
}

[RimeT]::RimeDestroySession($session) | Out-Null
[RimeT]::RimeFinalize()
