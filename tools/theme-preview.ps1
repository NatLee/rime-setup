<#
.SYNOPSIS
  從 rime/theme/na_weasel.yaml 的配色產生每個主題的預覽圖（SVG），給 README 用。

.DESCRIPTION
  預覽圖是「照配色畫出來的示意圖」，不是螢幕截圖：圓角、間距、光棒形狀照小狼毫的設定畫，
  顏色直接讀 yaml，所以配色改了重跑這支，README 的圖就會跟上。
  字型用瀏覽器／GitHub 當下的系統字型，實際候選窗的字型以輸入法設定為準。

.EXAMPLE
  pwsh tools\theme-preview.ps1            # 寫到 docs\themes\<主題>.svg
#>
[CmdletBinding()]
param(
  [string]$Repo = (Split-Path $PSScriptRoot -Parent),
  [string]$OutDir = ''
)
$ErrorActionPreference = 'Stop'
if (-not $OutDir) { $OutDir = Join-Path $Repo 'docs\themes' }
New-Item -ItemType Directory -Force $OutDir | Out-Null

# ── 讀配色：preset_color_schemes 底下「四格縮排的名稱」→「六格縮排的 key: 0x……」──
$schemes = [ordered]@{}
$cur = $null; $inPreset = $false
foreach ($ln in (Get-Content (Join-Path $Repo 'rime\theme\na_weasel.yaml') -Encoding UTF8)) {
  if ($ln -match '^  preset_color_schemes:') { $inPreset = $true; continue }
  if (-not $inPreset) { continue }
  if ($ln -match '^    ([A-Za-z0-9_]+):\s*$') { $cur = $Matches[1]; $schemes[$cur] = @{}; continue }
  if ($cur -and $ln -match '^      ([a-z_]+):\s*(.+?)\s*(#.*)?$') { $schemes[$cur][$Matches[1]] = $Matches[2].Trim() }
}

# 小狼毫的顏色是 0xBBGGRR（含透明度時 0xAABBGGRR）→ CSS #RRGGBB 與不透明度
function Css([string]$v, [string]$fallback) {
  if (-not $v -or $v -notmatch '^0x([0-9A-Fa-f]+)$') { return $fallback }
  $h = $Matches[1].PadLeft(6, '0')
  $h = $h.Substring($h.Length - 6)
  '#' + $h.Substring(4, 2) + $h.Substring(2, 2) + $h.Substring(0, 2)
}
function Alpha([string]$v, [double]$fallback) {
  if ($v -match '^0x([0-9A-Fa-f]{2})[0-9A-Fa-f]{6}$') { return [Math]::Round([Convert]::ToInt32($Matches[1], 16) / 255, 2) }
  $fallback
}

# 示意用的候選：文字、註釋
$cands = @(
  @('你好', ''),
  @('妳好', ''),
  @('你', ''),
  @('擬好', ''),
  @('さくら', '櫻花；櫻樹'),
  @('hello', 'int. 喂；哈囉')
)
$font = "'Microsoft JhengHei','PingFang TC','Noto Sans CJK TC','Noto Sans TC',sans-serif"

foreach ($name in $schemes.Keys) {
  $c = $schemes[$name]
  $back    = Css $c.back_color '#FFFFFF'
  $border  = Css $c.border_color $back
  $text    = Css $c.text_color '#000000'
  $hText   = Css $c.hilited_text_color $text
  $hBack   = Css $c.hilited_back_color $back
  $label   = Css $c.label_color $text
  $cand    = Css $c.candidate_text_color $text
  $comment = Css $c.comment_text_color $label
  $hcBack  = Css $c.hilited_candidate_back_color $hBack
  $hcText  = Css $c.hilited_candidate_text_color $hText
  $hcLabel = Css $c.hilited_candidate_label_color $hcText
  $hcCmt   = Css $c.hilited_comment_text_color $hcText
  $shadowA = Alpha $c.shadow_color 0.16
  $title   = if ($c.name) { $c.name } else { $name }

  # 排版數字對應 na_weasel.yaml 的 layout：margin 8/6、視窗圓角 10、光棒圓角 6、
  # 光棒內距 8/4、候選列距 2、編碼列與候選間距 6、不設最小寬度。改了那邊記得回來對一下。
  $mark    = Css $c.hilited_mark_color ''
  $pageCol = Css $c.prevpage_color ''
  $W = 268; $pad = 8; $padY = 6; $rowH = 31; $gap = 2; $preH = 26
  $H = $padY + $preH + 6 + ($rowH + $gap) * $cands.Count - $gap + $padY
  $svgW = $W + 40; $svgH = $H + 44
  $sb = New-Object Text.StringBuilder
  [void]$sb.AppendLine("<svg xmlns=`"http://www.w3.org/2000/svg`" width=`"$svgW`" height=`"$svgH`" viewBox=`"0 0 $svgW $svgH`" role=`"img`" aria-label=`"$title 主題預覽`">")
  [void]$sb.AppendLine("  <title>$title</title>")
  [void]$sb.AppendLine("  <defs><filter id=`"s`" x=`"-25%`" y=`"-20%`" width=`"150%`" height=`"160%`"><feDropShadow dx=`"0`" dy=`"3`" stdDeviation=`"6`" flood-color=`"#000`" flood-opacity=`"$shadowA`"/></filter></defs>")
  [void]$sb.AppendLine("  <g transform=`"translate(20,16)`" font-family=`"$font`">")
  [void]$sb.AppendLine("    <rect width=`"$W`" height=`"$H`" rx=`"10`" fill=`"$back`" stroke=`"$border`" stroke-width=`"1`" filter=`"url(#s)`"/>")
  # 編碼列：已確定的部分＋高亮段；右側是翻頁箭頭（第一頁時 < 用一般文字色＝不能往前）
  $y = $padY
  [void]$sb.AppendLine("    <text x=`"$($pad + 8)`" y=`"$($y + 19)`" font-size=`"15`" fill=`"$text`">ㄋㄧˇ</text>")
  [void]$sb.AppendLine("    <rect x=`"$($pad + 50)`" y=`"$($y + 2)`" width=`"54`" height=`"23`" rx=`"5`" fill=`"$hBack`"/>")
  [void]$sb.AppendLine("    <text x=`"$($pad + 56)`" y=`"$($y + 19)`" font-size=`"15`" fill=`"$hText`">ㄏㄠˇ</text>")
  if ($pageCol) {
    [void]$sb.AppendLine("    <text x=`"$($W - $pad - 38)`" y=`"$($y + 19)`" font-size=`"15`" font-weight=`"600`" fill=`"$text`" opacity=`"0.55`">&lt;</text>")
    [void]$sb.AppendLine("    <text x=`"$($W - $pad - 18)`" y=`"$($y + 19)`" font-size=`"15`" font-weight=`"600`" fill=`"$pageCol`">&gt;</text>")
  }
  $y += $preH + 6
  for ($i = 0; $i -lt $cands.Count; $i++) {
    $isHi = ($i -eq 0)
    $lc = if ($isHi) { $hcLabel } else { $label }
    $tc = if ($isHi) { $hcText } else { $cand }
    $cc = if ($isHi) { $hcCmt } else { $comment }
    if ($isHi) {
      [void]$sb.AppendLine("    <rect x=`"$pad`" y=`"$y`" width=`"$($W - 2 * $pad)`" height=`"$rowH`" rx=`"6`" fill=`"$hcBack`"/>")
      # 高亮列左側的圓角色條（mark_text 留空時小狼毫畫的那一條）
      if ($mark) { [void]$sb.AppendLine("    <rect x=`"$($pad + 1)`" y=`"$($y + 8)`" width=`"4`" height=`"$($rowH - 16)`" rx=`"2`" fill=`"$mark`"/>") }
    }
    $by = $y + 21
    [void]$sb.AppendLine("    <text x=`"$($pad + 14)`" y=`"$by`" font-size=`"13`" font-weight=`"600`" fill=`"$lc`">⇧$($i + 1)</text>")
    [void]$sb.AppendLine("    <text x=`"$($pad + 46)`" y=`"$by`" font-size=`"17`" font-weight=`"700`" fill=`"$tc`">$($cands[$i][0])</text>")
    if ($cands[$i][1]) {
      [void]$sb.AppendLine("    <text x=`"$($pad + 128)`" y=`"$by`" font-size=`"13`" fill=`"$cc`">$($cands[$i][1])</text>")
    }
    $y += $rowH + $gap
  }
  [void]$sb.AppendLine('  </g>')
  [void]$sb.AppendLine('</svg>')
  $out = Join-Path $OutDir "$name.svg"
  [IO.File]::WriteAllText($out, ($sb.ToString() -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding $false))
  Write-Host ("{0,-14} → {1}" -f $name, $out)
}
