# install.ps1 — 注音Na+ 一行安裝／重新設定（Windows 小狼毫）
#
#   irm https://raw.githubusercontent.com/NatLee/rime-setup/main/install.ps1 | iex
#
# 第一次跑＝安裝；之後再跑同一行＝更新到最新版＋重新選一次選項。
# 已經裝好的人也可以不連網重選：雙擊 RIME 使用者資料夾裡的 na-setup.cmd
#
# 不想被問（自動化／固定選項）：先設環境變數再跑，或直接帶參數
#   $env:NA_THEME='light'; $env:NA_EMOJI='off'; $env:NA_YES='1'; irm <網址> | iex
#   & ([scriptblock]::Create((irm <網址>))) -Theme light -Emoji off -Langs ja,en -Yes
#
# 這支腳本會：
#   確認 git／小狼毫 → 把設定 repo 下載到 %USERPROFILE%\.na-plus（已有就更新）
#   → 第一次：備份既有的 RIME 使用者資料夾，並還原你的打字詞頻與個人短語
#   → 問選項 → 把檔案套用到使用者資料夾 → 部署並重啟小狼毫
#
# 其他環境變數：NA_HOME（repo 放哪）、NA_RIME_DIR（使用者資料夾）、NA_REPO／NA_BRANCH（來源）、
#   NA_LOCAL=1（用 NA_HOME 那份、不連網）、NA_NO_DEPLOY=1（只複製檔案，不動輸入法；測試用）
#
# ⚠ 寫給維護者：
#   ‧ 要同時能在 Windows PowerShell 5.1 與 pwsh 7 跑：不用三元運算子、??、&&。
#   ‧ 全部包在函式裡、最後一行才呼叫：`irm | iex` 下載到一半斷線時不會執行半支腳本。
#   ‧ 不可以用 exit —— 在 iex 底下會把使用者的整個 PowerShell 視窗關掉。用 return。
#   ‧ 本檔必須是「UTF-8 不含 BOM」，跟其他 .ps1 相反：irm 不會去掉 BOM，字串開頭多一個
#     U+FEFF 會讓第一行變成「找不到指令」、param 區塊失效（實測 5.1 與 7 都一樣，
#     而且 param 失效時 -NoDeploy 之類的參數會被悄悄忽略）。
#     代價：Windows PowerShell 5.1「直接執行本機這個檔」會把它當 ANSI 讀，語法錯。
#     所以本機重跑一律走 scripts\rime-setup.cmd（它明確用 UTF-8 讀進來再執行），
#     pwsh 7 則可以直接 pwsh -File install.ps1。

param(
    [string]$Theme,      # matcha | light | dark | auto | classic
    [string]$Layout,     # vertical | horizontal
    [string]$Emoji,      # on | off
    [string]$Langs,      # ja,ko,en,extra 任意組合；none＝只留注音
    [string]$Gloss,      # zh | en | ja
    [switch]$Yes,        # 不詢問：沿用上次的選擇（第一次則用預設值）
    [switch]$NoDeploy,   # 只寫設定，不部署／不重啟（測試用）
    [string]$Repo,       # 設定來源 repo 網址（fork 的人改這個）
    [string]$Branch,
    [string]$RimeDir     # RIME 使用者資料夾（預設自動偵測）
)

function Install-NaPlus {
    param($Theme, $Layout, $Emoji, $Langs, $Gloss, [bool]$Yes, [bool]$NoDeploy, $Repo, $Branch, $RimeDir)

    $ErrorActionPreference = 'Stop'

    # ── 小工具 ────────────────────────────────────────────────────────
    function Say  ([string]$m) { Write-Host $m }
    function Step ([string]$m) { Write-Host ''; Write-Host "→ $m" -ForegroundColor Cyan }
    function Warn ([string]$m) { Write-Host "  ⚠ $m" -ForegroundColor Yellow }
    function Ok   ([string]$m) { Write-Host "  ✓ $m" -ForegroundColor Green }
    function Die  ([string]$m) { throw "NAPLUS: $m" }

    # 參數 > 環境變數 > （之後）上次的選擇 > 預設值
    function Pick ([string]$a, [string]$envName) {
        if ($a) { return $a }
        $v = [Environment]::GetEnvironmentVariable($envName)
        if ($v) { return $v }
        return ''
    }

    # 跑 git：5.1 在 ErrorActionPreference=Stop 時，原生程式寫 stderr（git 的進度
    # 訊息就是寫 stderr）有機會被當成例外，所以這裡暫時放寬，只看 exit code。
    function Run-Git {
        $old = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { & git.exe @args } finally { $ErrorActionPreference = $old }
    }

    # 兩個 remote 是不是同一個 repo：只比最後兩段（owner/repo），
    # 這樣 https://github.com/a/b.git 與 git@github.com:a/b.git 會被視為相同。
    function Repo-Key ([string]$url) {
        $u = ($url.Trim() -replace '\.git$', '').TrimEnd('/', '\')
        $parts = @($u -split '[/\\:]' | Where-Object { $_ })
        if ($parts.Count -ge 2) { return ($parts[-2] + '/' + $parts[-1]).ToLower() }
        return $u.ToLower()
    }

    function Ask-One ([string]$title, [object[]]$items, [string]$current) {
        # $items：@( @('值','顯示文字'), ... )；回傳選到的「值」
        Write-Host ''
        Write-Host $title -ForegroundColor Cyan
        $cur = 1
        for ($i = 0; $i -lt $items.Count; $i++) {
            $mark = ' '
            if ($items[$i][0] -eq $current) { $mark = '*'; $cur = $i + 1 }
            Write-Host ("  {0} {1}) {2}" -f $mark, ($i + 1), $items[$i][1])
        }
        while ($true) {
            $ans = (Read-Host ("  選擇 1-{0}（直接按 Enter＝{1}）" -f $items.Count, $cur)).Trim()
            if (-not $ans) { return $items[$cur - 1][0] }
            $n = 0
            if ([int]::TryParse($ans, [ref]$n) -and $n -ge 1 -and $n -le $items.Count) { return $items[$n - 1][0] }
            Write-Host '  請輸入清單上的數字。' -ForegroundColor Yellow
        }
    }

    function Ask-Many ([string]$title, [object[]]$items, [string[]]$current) {
        Write-Host ''
        Write-Host $title -ForegroundColor Cyan
        $curNums = @()
        for ($i = 0; $i -lt $items.Count; $i++) {
            $mark = ' '
            if ($current -contains $items[$i][0]) { $mark = '*'; $curNums += ($i + 1) }
            Write-Host ("  {0} {1}) {2}" -f $mark, ($i + 1), $items[$i][1])
        }
        $curText = '都不要'
        if ($curNums.Count) { $curText = ($curNums -join ' ') }
        while ($true) {
            $ans = (Read-Host ("  可複選，用空白隔開，例如 1 3；0＝都不要（直接按 Enter＝{0}）" -f $curText)).Trim()
            if (-not $ans) { return , @($current) }
            if ($ans -eq '0') { return , @() }
            $picked = @(); $bad = $false
            foreach ($tok in ($ans -split '[\s,]+' | Where-Object { $_ })) {
                $n = 0
                if ([int]::TryParse($tok, [ref]$n) -and $n -ge 1 -and $n -le $items.Count) {
                    if ($picked -notcontains $items[$n - 1][0]) { $picked += $items[$n - 1][0] }
                } else { $bad = $true }
            }
            if (-not $bad) { return , @($picked) }
            Write-Host '  請輸入清單上的數字。' -ForegroundColor Yellow
        }
    }

    # ── 選項定義（值, 顯示文字）────────────────────────────────────────
    $themeItems = @(
        @('matcha',  'Nat Matcha   抹茶奶油色（預設）'),
        @('light',   'Nat Light    明亮白底'),
        @('dark',    'Nat Dark     深色'),
        @('auto',    '跟隨系統     淺色模式 Nat Light／深色模式 Nat Dark'),
        @('classic', 'Nat Classic  經典黃綠')
    )
    $themeMap = @{   # 值 → (color_scheme, color_scheme_dark)
        matcha  = @('NatMatcha', 'NatMatcha')
        light   = @('NatLight',  'NatLight')
        dark    = @('NatDark',   'NatDark')
        auto    = @('NatLight',  'NatDark')
        classic = @('NatLee',    'NatLee')
    }
    $layoutItems = @( @('vertical', '直排（預設）'), @('horizontal', '橫排') )
    $emojiItems  = @( @('on', '開：候選裡附帶對應的 emoji（預設）'), @('off', '關') )
    $langItems   = @(
        @('ja',    '日文'),
        @('ko',    '韓文'),
        @('en',    '英文'),
        @('extra', '其他：注音文、全形、英文大寫、英文附釋義、符號')
    )
    # ⚠ 只有一個元素的「陣列的陣列」前面要加逗號，否則 PowerShell 會把它攤平
    $langSchemas = [ordered]@{   # 值 → 方案 id 與選單上的名字
        ja    = @( , @('jpnin1', '日文') )
        ko    = @( , @('hangeul_hnc', '韓文') )
        en    = @( , @('easy_en_lower', '英文') )
        extra = @( @('allbpm', '注音文'), @('fullshape', '全形'), @('easy_en_upper', '英文（大寫）'),
                   @('easy_en_lcomment', '英文（附釋義）'), @('symbols_bpmf', '符號') )
    }
    $glossItems = @( @('zh', '中文（預設）'), @('en', '英文'), @('ja', '日文') )
    $glossMap   = @{ zh = 0; en = 1; ja = 2 }

    $defaults = @{ theme = 'matcha'; layout = 'vertical'; emoji = 'on'; langs = 'ja,ko,en,extra'; gloss = 'zh' }

    # ── 開始 ──────────────────────────────────────────────────────────
    Say ''
    Say '════════ 注音Na+ 安裝／設定（Windows 小狼毫）════════'

    if (-not $Repo)   { $Repo   = Pick '' 'NA_REPO' }
    if (-not $Repo)   { $Repo   = 'https://github.com/NatLee/rime-setup.git' }
    if (-not $Branch) { $Branch = Pick '' 'NA_BRANCH' }
    if (-not $Branch) { $Branch = 'main' }
    if (-not $Yes -and (Pick '' 'NA_YES')) { $Yes = $true }
    if (-not $NoDeploy -and (Pick '' 'NA_NO_DEPLOY')) { $NoDeploy = $true }
    $interactive = (-not $Yes) -and [Environment]::UserInteractive
    try { if ([Console]::IsInputRedirected) { $interactive = $false } } catch { }
    if (Pick '' 'NA_FORCE_INTERACTIVE') { $interactive = $true }   # 測試用：從 stdin 餵答案

    # ── [1] git ───────────────────────────────────────────────────────
    Step '檢查 git'
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $gitCmd = Join-Path $env:ProgramFiles 'Git\cmd'
        if (Test-Path (Join-Path $gitCmd 'git.exe')) {
            $env:PATH = "$gitCmd;$env:PATH"   # 裝了但這個視窗的 PATH 還沒更新
        } elseif ((Get-Command winget -ErrorAction SilentlyContinue) -and $interactive -and
                  ((Read-Host '  找不到 git。要用 winget 安裝嗎？[Y/n]').Trim() -notmatch '^[nN]')) {
            winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
            if (Test-Path (Join-Path $gitCmd 'git.exe')) { $env:PATH = "$gitCmd;$env:PATH" }
        }
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Die '需要 git。請先安裝 https://git-scm.com/download/win （或 winget install Git.Git），開新的 PowerShell 視窗後再跑一次。'
        }
    }
    Ok ((Run-Git --version) -join ' ')

    # ── [2] 小狼毫 ────────────────────────────────────────────────────
    Step '檢查小狼毫（Weasel）'
    function Find-Weasel {
        foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Rime\Weasel', 'HKLM:\SOFTWARE\Rime\Weasel') {
            $r = Get-ItemProperty $k -ErrorAction SilentlyContinue
            if ($r -and $r.WeaselRoot -and (Test-Path (Join-Path $r.WeaselRoot 'WeaselServer.exe'))) { return $r.WeaselRoot }
        }
        $d = Get-ChildItem (Join-Path $env:ProgramFiles 'Rime') -Directory -Filter 'weasel-*' -ErrorAction SilentlyContinue |
             Sort-Object Name -Descending | Select-Object -First 1
        if ($d -and (Test-Path (Join-Path $d.FullName 'WeaselServer.exe'))) { return $d.FullName }
        return $null
    }
    $weaselRoot = Find-Weasel
    if (-not $weaselRoot -and -not $NoDeploy) {
        if ((Get-Command winget -ErrorAction SilentlyContinue) -and $interactive -and
            ((Read-Host '  找不到小狼毫。要用 winget 安裝嗎？[Y/n]').Trim() -notmatch '^[nN]')) {
            winget install --id Rime.Weasel -e --source winget --accept-source-agreements --accept-package-agreements
            $weaselRoot = Find-Weasel
        }
        if (-not $weaselRoot) {
            Die '找不到小狼毫。請先安裝 https://rime.im/download/ （安裝時語言選「繁體中文」），再跑一次這行指令。'
        }
    }
    if ($weaselRoot) { Ok $weaselRoot } else { Warn '找不到小狼毫（-NoDeploy，略過）' }
    $server = $null
    if ($weaselRoot) { $server = Join-Path $weaselRoot 'WeaselServer.exe' }

    # ── [3] 使用者資料夾 ──────────────────────────────────────────────
    if (-not $RimeDir) { $RimeDir = Pick '' 'NA_RIME_DIR' }
    if (-not $RimeDir) {
        $r = Get-ItemProperty 'HKCU:\Software\Rime\Weasel' -ErrorAction SilentlyContinue
        if ($r -and $r.RimeUserDir) { $RimeDir = $r.RimeUserDir } else { $RimeDir = Join-Path $env:APPDATA 'Rime' }
    }
    $RimeDir = [IO.Path]::GetFullPath($RimeDir).TrimEnd('\')
    Step "RIME 使用者資料夾：$RimeDir"

    function Stop-Weasel {
        # -NoDeploy＝完全不碰輸入法服務（不然停了卻沒有人把它叫回來）
        if ($NoDeploy -or -not $server) { return }
        if (-not (Get-Process WeaselServer -ErrorAction SilentlyContinue)) { return }
        # 用官方的 /quit，不強殺：強殺會讓正在打字的視窗卡在具名管線上（見 scripts\rime-update.ps1）
        foreach ($attempt in 1..3) {
            & $server /quit
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ((Get-Process WeaselServer -ErrorAction SilentlyContinue) -and $sw.Elapsed.TotalSeconds -lt 5) { Start-Sleep -Milliseconds 100 }
            if (-not (Get-Process WeaselServer -ErrorAction SilentlyContinue)) { return }
        }
        Stop-Process -Name WeaselServer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    }

    # ── [4] 設定來源（repo）──────────────────────────────────────────
    # repo 與使用者資料夾是分開的：repo 裡的 rime\ 按功能分類，使用者資料夾必須是攤平的
    # （RIME 只認根目錄的方案檔），中間靠 scripts\rime-apply.ps1 複製。
    $SrcDir = Pick '' 'NA_HOME'
    if (-not $SrcDir) { $SrcDir = Join-Path $env:USERPROFILE '.na-plus' }
    $SrcDir = [IO.Path]::GetFullPath($SrcDir).TrimEnd('\')
    $useLocal = [bool](Pick '' 'NA_LOCAL')   # rime-setup.cmd 會設：直接用本機那份，不連網
    $srcHasGit = Test-Path (Join-Path $SrcDir '.git')
    $srcNonEmpty = (Test-Path $SrcDir) -and (@(Get-ChildItem $SrcDir -Force -ErrorAction SilentlyContinue).Count -gt 0)

    if ($useLocal) {
        if (-not (Test-Path (Join-Path $SrcDir 'rime'))) { Die "$SrcDir 裡找不到 rime\ 資料夾。" }
        Step "使用本機的設定（不連網）：$SrcDir"
    } elseif ($srcHasGit) {
        $origin = (Run-Git -C $SrcDir remote get-url origin 2>$null | Select-Object -First 1)
        if (-not $origin -or ((Repo-Key $origin) -ne (Repo-Key $Repo))) {
            Die "$SrcDir 已經是另一個 git repo（$origin）。請把它移走，或用 NA_HOME 指定別的位置。"
        }
        Step "更新設定到最新版：$SrcDir"
        Run-Git -C $SrcDir pull --ff-only
        if ($LASTEXITCODE -ne 0) {
            Warn 'git pull 失敗（改過裡面的檔案，或上游重寫過歷史），沿用目前的版本繼續。'
            Warn "想強制對齊上游：刪掉 $SrcDir 後重跑這行指令。"
        }
    } elseif ($srcNonEmpty) {
        Die "$SrcDir 已經存在而且不是這份設定的 repo。請把它移走，或用 NA_HOME 指定別的位置。"
    } else {
        Step "下載設定到 $SrcDir（約 100 MB，視網速需要一點時間）"
        if (Test-Path $SrcDir) { Remove-Item -LiteralPath $SrcDir -Force }
        Run-Git clone --depth 1 --branch $Branch $Repo $SrcDir
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $SrcDir 'rime'))) { Die 'git clone 失敗。請檢查網路後再試（還沒有動到你的輸入法設定）。' }
    }

    # ── [5] 使用者資料夾：裝過就直接更新，否則先備份 ──────────────────
    # 判斷「裝過」看 na_manifest.txt（rime-apply.ps1 留下的清單）。
    # 沒有清單但有東西＝別的方案，或舊版安裝（資料夾本身是 git clone）→ 整個搬去備份，
    # 再把屬於「你」的東西搬回來。
    $backup = $null
    $ours = Test-Path (Join-Path $RimeDir 'na_manifest.txt')
    $hasOld = (Test-Path $RimeDir) -and (@(Get-ChildItem $RimeDir -Force -ErrorAction SilentlyContinue).Count -gt 0)
    if ($ours) {
        Step '這台已經裝過 → 更新檔案並重新設定選項'
    } elseif ($hasOld) {
        $backup = "$RimeDir.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Step "備份既有設定 → $backup"
        Stop-Weasel   # 服務開著時詞頻資料庫被鎖住，搬不動
        try { Move-Item -LiteralPath $RimeDir -Destination $backup }
        catch {
            if ($server -and -not $NoDeploy) { Start-Process $server }
            Die "搬不動 $RimeDir（有程式開著裡面的檔案？）。關掉相關視窗後再試。原始錯誤：$($_.Exception.Message)"
        }
    }
    New-Item -ItemType Directory -Force $RimeDir | Out-Null

    if ($backup) {
        # 詞頻資料庫（*.userdb）、同步資料、機器識別檔、個人短語、上次的選項 —— 這些是
        # 「你的」東西，不在 repo 裡，要從備份搬回來，否則等於把打字習慣歸零。
        $n = 0
        foreach ($db in @(Get-ChildItem $backup -Directory -Filter '*.userdb' -ErrorAction SilentlyContinue)) {
            Copy-Item -LiteralPath $db.FullName -Destination $RimeDir -Recurse -Force; $n++
        }
        if (Test-Path (Join-Path $backup 'sync')) { Copy-Item -LiteralPath (Join-Path $backup 'sync') -Destination $RimeDir -Recurse -Force }
        foreach ($f in 'installation.yaml', 'user.yaml', 'bopomo_onionplus_phrase.txt', 'na_options.custom.yaml') {
            $src = Join-Path $backup $f
            if (Test-Path $src) { Copy-Item -LiteralPath $src -Destination $RimeDir -Force }
        }
        Ok "已從備份還原 $n 個詞頻資料庫與個人檔案"
        Say "    備份留在 $backup，確認一切正常後可自行刪除。"
    }

    # ── [5b] 選項 ─────────────────────────────────────────────────────
    $optFile = Join-Path $RimeDir 'na_options.custom.yaml'
    $prev = @{}
    if (Test-Path $optFile) {
        # 上次的選擇記在檔頭那行「# na-options: k=v k=v」
        $line = Get-Content -LiteralPath $optFile -Encoding UTF8 | Where-Object { $_ -match '^#\s*na-options:' } | Select-Object -First 1
        if ($line) {
            foreach ($kv in (($line -replace '^#\s*na-options:', '').Trim() -split '\s+')) {
                $p = $kv -split '=', 2
                if ($p.Count -eq 2) { $prev[$p[0]] = $p[1] }
            }
        }
    }
    $opt = @{}
    $given = @{ theme = (Pick $Theme 'NA_THEME'); layout = (Pick $Layout 'NA_LAYOUT'); emoji = (Pick $Emoji 'NA_EMOJI')
                langs = (Pick $Langs 'NA_LANGS'); gloss = (Pick $Gloss 'NA_GLOSS') }
    foreach ($k in $defaults.Keys) {
        if ($given[$k])     { $opt[$k] = $given[$k].ToLower() }
        elseif ($prev[$k])  { $opt[$k] = $prev[$k] }
        else                { $opt[$k] = $defaults[$k] }
    }

    if ($interactive) {
        Step '選項（之後想改，重跑同一行安裝指令即可）'
        if (-not $given.theme)  { $opt.theme  = Ask-One '[1/5] 主題（候選窗配色）' $themeItems $opt.theme }
        if (-not $given.layout) { $opt.layout = Ask-One '[2/5] 候選排列' $layoutItems $opt.layout }
        if (-not $given.emoji)  { $opt.emoji  = Ask-One '[3/5] 打字時候選附帶 emoji（之後仍可在方案選單臨時切換）' $emojiItems $opt.emoji }
        if (-not $given.langs) {
            $curLangs = @($opt.langs -split ',' | Where-Object { $_ -and $_ -ne 'none' })
            $sel = Ask-Many '[4/5] 方案選單要放哪些語言（注音一定有）' $langItems $curLangs
            if ($sel.Count) { $opt.langs = ($sel -join ',') } else { $opt.langs = 'none' }
        }
        if (-not $given.gloss)  { $opt.gloss  = Ask-One '[5/5] 日文／英文候選的釋義要用哪種語言顯示' $glossItems $opt.gloss }
    }

    # 檢查（參數／環境變數／手改的檔頭都可能給出不認得的值）
    if (-not $themeMap.ContainsKey($opt.theme)) { Die "不認得的主題：$($opt.theme)（可用：matcha light dark auto classic）" }
    if ('vertical', 'horizontal' -notcontains $opt.layout) { Die "不認得的排列：$($opt.layout)（可用：vertical horizontal）" }
    if ('on', 'off' -notcontains $opt.emoji) { Die "不認得的 emoji 設定：$($opt.emoji)（可用：on off）" }
    if (-not $glossMap.ContainsKey($opt.gloss)) { Die "不認得的釋義語言：$($opt.gloss)（可用：zh en ja）" }
    $langs = @($opt.langs -split '[,\s]+' | Where-Object { $_ -and $_ -ne 'none' })
    foreach ($l in $langs) { if (-not $langSchemas.Contains($l)) { Die "不認得的語言：$l（可用：ja ko en extra none）" } }
    if ($langs.Count) { $opt.langs = ($langs -join ',') } else { $opt.langs = 'none' }

    $horizontal = 'false'; $mac = 'stacked'
    if ($opt.layout -eq 'horizontal') { $horizontal = 'true'; $mac = 'linear' }
    $emojiNum = 1
    if ($opt.emoji -eq 'off') { $emojiNum = 0 }

    $y = New-Object System.Collections.Generic.List[string]
    $y.Add('# na_options.custom.yaml — 個人安裝選項（由 install 腳本產生，不進版控）')
    $y.Add('# 想換選項：重跑安裝指令；或手動改下面的值後重新部署。各鍵說明見 na_options.yaml。')
    $y.Add('# ↓ 這行是給安裝腳本讀「上次選了什麼」用的，手動改值時請一起改，或整行刪掉。')
    $y.Add("# na-options: theme=$($opt.theme) layout=$($opt.layout) emoji=$($opt.emoji) langs=$($opt.langs) gloss=$($opt.gloss)")
    $y.Add('patch:')
    $y.Add("  theme: $($themeMap[$opt.theme][0])")
    $y.Add("  theme_dark: $($themeMap[$opt.theme][1])")
    $y.Add("  horizontal: $horizontal")
    $y.Add("  candidate_list_layout: $mac")
    $y.Add("  emoji: $emojiNum")
    $y.Add("  gloss: $($glossMap[$opt.gloss])")
    $y.Add('  schema_list:')
    $y.Add('    - { schema: bopomo_onionplus } # 注音Na+')
    foreach ($l in $langSchemas.Keys) {
        if ($langs -contains $l) { foreach ($s in $langSchemas[$l]) { $y.Add("    - { schema: $($s[0]) } # $($s[1])") } }
    }
    # 不帶 BOM、LF：這個檔是給 librime 讀的
    [IO.File]::WriteAllText($optFile, (($y -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))
    Step '已寫入選項'
    Say "    主題 $($opt.theme)｜排列 $($opt.layout)｜emoji $($opt.emoji)｜語言 $($opt.langs)｜釋義 $($opt.gloss)"

    # ── [6] 套用檔案＋部署＋重啟 ──────────────────────────────────────
    # 交給 repo 裡的 rime-update.ps1：它會把 rime\ 攤平複製到使用者資料夾、部署、重啟。
    # 另開一個行程並帶 -ExecutionPolicy Bypass：Windows 預設政策不准直接執行 .ps1 檔。
    if ($NoDeploy) { Step '套用檔案（-NoDeploy：不部署、不動輸入法服務）' }
    else { Step '套用檔案、部署並重啟小狼毫（第一次要編譯詞典，約 2～5 分鐘，請等它跑完）' }
    $psExe = (Get-Process -Id $PID).Path
    $upArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $SrcDir 'scripts\rime-update.ps1'),
                '-Force', '-SkipPull', '-NoPause', '-CloseAfter', '0', '-RimeDir', $RimeDir)
    if ($NoDeploy) { $upArgs += '-NoDeploy' }
    & $psExe @upArgs
    if ($LASTEXITCODE -ne 0) { Die '套用／部署沒有成功，請看上面的訊息。' }

    Say ''
    Write-Host '✓ 完成。' -ForegroundColor Green
    Say '  ‧ 切到小狼毫後按 Ctrl+` 開方案選單；打 ''/h 再按空白鍵可開速查表'
    Say "  ‧ 想重選主題／語言／emoji：再跑一次同一行安裝指令（或雙擊 $RimeDir\na-setup.cmd）"
    Say "  ‧ 之後更新：輸入法內打 '/git 再按空白鍵"
    Say "  ‧ 設定來源放在 $SrcDir（更新靠它，請不要刪）"
    Say ''
}

try {
    Install-NaPlus -Theme $Theme -Layout $Layout -Emoji $Emoji -Langs $Langs -Gloss $Gloss `
        -Yes ([bool]$Yes) -NoDeploy ([bool]$NoDeploy) -Repo $Repo -Branch $Branch -RimeDir $RimeDir
} catch {
    Write-Host ''
    $msg = $_.Exception.Message
    if ($msg -like 'NAPLUS: *') { Write-Host ('✗ ' + $msg.Substring(8)) -ForegroundColor Red }
    else { Write-Host ('✗ 安裝中斷：' + $msg) -ForegroundColor Red; Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray }
    Write-Host ''
}
