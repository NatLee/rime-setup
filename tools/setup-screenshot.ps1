<#
.SYNOPSIS
  重產 README 裡「'/setup 選項畫面」的截圖（docs/setup/*.png）。

.DESCRIPTION
  選項畫面是畫在終端機上的，長相取決於終端機的字型與配色，所以沒辦法像主題預覽圖那樣用算的畫出來
  （tools\theme-preview.ps1）——只能開一個真的終端機視窗、把那個視窗截下來。

  做法：把 rime\ 套用到一個臨時資料夾，對它跑安裝腳本的選項畫面（不部署、不連網），用按鍵腳本
  （NA_TUI_KEYS）把畫面帶到想要的狀態並停住，截下那個視窗，然後直接結束那個行程。
  選項畫面後面的步驟（寫選項、套用）完全不會執行，使用者真正的 RIME 資料夾與輸入法都不會被碰到。

  ⚠ 會在桌面上開視窗，每張約五秒。截的只有那個視窗的範圍；截圖當下別把其他視窗蓋到它上面。
  ⚠ 截出來的字型、視窗大小、是否深色，就是這台電腦終端機的設定。改了選項畫面的版面之後重跑一次，
    並且打開圖看一眼（這同時也是「它在真實終端機上有沒有歪掉」的檢查）。

.EXAMPLE
  pwsh tools\setup-screenshot.ps1                 # 全部重產
  pwsh tools\setup-screenshot.ps1 -Only theme     # 只重產檔名含 theme 的那張
#>
[CmdletBinding()]
param(
  [string]$Repo = (Split-Path $PSScriptRoot -Parent),
  [string]$OutDir,
  [string]$Only = ''
)
$ErrorActionPreference = 'Stop'
if (-not $OutDir) { $OutDir = Join-Path $Repo 'docs\setup' }
New-Item -ItemType Directory -Force $OutDir | Out-Null

# 每張圖：檔名、按鍵腳本（最後的 Wait＝停在這一格等截圖）。畫面上的順序見 install.ps1 的 Show-OptionsScreen。
$shots = @(
  @{ name = 'setup-theme';  keys = 'Right,Right,Right,Wait' },                                  # 換主題，右邊即時預覽
  @{ name = 'setup-layout'; keys = 'Left,Left,Left,Down,Down,Right,Wait' },                     # 深色主題＋橫排
  @{ name = 'setup-langs';  keys = 'Down,Down,Down,Down,Down,Down,Right,Space,Wait' }           # 語言的勾選
)

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public static class NaShot {
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);
  // 終端機視窗：Windows Terminal 或傳統主控台
  public static List<long> Terminals() {
    var r = new List<long>();
    EnumWindows((h, l) => { var c = new StringBuilder(256); GetClassName(h, c, 256); string s = c.ToString();
      if ((s == "CASCADIA_HOSTING_WINDOW_CLASS" || s == "ConsoleWindowClass") && IsWindowVisible(h)) r.Add(h.ToInt64()); return true; }, IntPtr.Zero);
    return r;
  }
  // 視窗真正看得到的範圍（不含陰影）
  public static int[] Bounds(long h) { RECT r; DwmGetWindowAttribute(new IntPtr(h), 9, out r, 16); return new int[] { r.L, r.T, r.R - r.L, r.B - r.T }; }
}
"@
[void][NaShot]::SetProcessDPIAware()    # 不設的話，螢幕縮放不是 100% 時座標會被系統換算過，截到的範圍是錯的

# 臨時的使用者資料夾：跟正式安裝同一支 rime-apply.ps1 攤平出來的
$tmp = Join-Path $env:TEMP 'na_setup_shot'
& (Join-Path $Repo 'scripts\rime-apply.ps1') -RimeDir $tmp -NoLaunchers -AllowDowngrade -Quiet | Out-Null

$ps = 'powershell'; if (Get-Command pwsh -ErrorAction SilentlyContinue) { $ps = 'pwsh' }
$names = 'NA_HOME', 'NA_LOCAL', 'NA_NO_DEPLOY', 'NA_RIME_DIR', 'NA_FORCE_INTERACTIVE', 'NA_TUI_KEYS', 'NA_INSTALL'
$old = @{}; foreach ($n in $names) { $old[$n] = [Environment]::GetEnvironmentVariable($n) }
try {
  $env:NA_HOME = $Repo; $env:NA_LOCAL = '1'; $env:NA_NO_DEPLOY = '1'; $env:NA_RIME_DIR = $tmp; $env:NA_FORCE_INTERACTIVE = '1'
  $env:NA_INSTALL = Join-Path $Repo 'install.ps1'
  foreach ($s in $shots) {
    if ($Only -and $s.name -notlike "*$Only*") { continue }
    # 每張都從預設值開始：拿掉上一輪可能留下的個人選項檔
    Get-ChildItem $tmp -Filter 'na_*.custom.yaml' -ErrorAction SilentlyContinue | Remove-Item -Force
    $env:NA_TUI_KEYS = $s.keys
    $before = @{}; foreach ($h in [NaShot]::Terminals()) { $before[$h] = 1 }
    # 跟 scripts\rime-setup.cmd 同樣的跑法（明確用 UTF-8 讀進來當 script block）；標題也設成一樣
    $p = Start-Process $ps -PassThru -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command "$Host.UI.RawUI.WindowTitle = ''Na+ setup''; & ([scriptblock]::Create([IO.File]::ReadAllText($env:NA_INSTALL, [Text.Encoding]::UTF8)))"'
    try {
      $win = 0; $sw = [Diagnostics.Stopwatch]::StartNew()
      while (-not $win -and $sw.Elapsed.TotalSeconds -lt 15) {
        foreach ($h in [NaShot]::Terminals()) { if (-not $before.ContainsKey($h)) { $win = $h } }
        Start-Sleep -Milliseconds 50
      }
      if (-not $win) { throw "等不到 $($s.name) 的終端機視窗" }
      Start-Sleep -Milliseconds 2600        # 選單約一秒出來、按鍵瞬間跑完，之後停四秒；取中間
      $b = [NaShot]::Bounds($win)
      $bmp = New-Object Drawing.Bitmap $b[2], $b[3]
      $g = [Drawing.Graphics]::FromImage($bmp)
      $g.CopyFromScreen($b[0], $b[1], 0, 0, (New-Object Drawing.Size $b[2], $b[3]))
      $out = Join-Path $OutDir ($s.name + '.png')
      $bmp.Save($out, [Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
      Write-Host ("{0,-14} → {1}（{2}×{3}）" -f $s.name, $out, $b[2], $b[3])
    } finally {
      # 截完就把那個行程（連同它開出來的）結束：選項畫面後面的步驟不需要跑
      & taskkill /T /F /PID $p.Id 2>$null | Out-Null
    }
    Start-Sleep -Milliseconds 800
  }
} finally { foreach ($n in $names) { [Environment]::SetEnvironmentVariable($n, $old[$n]) } }
