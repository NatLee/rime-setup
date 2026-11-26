# install.ps1 — 注音Na+ 一行安裝／重新設定（Windows 小狼毫）
#
#   irm https://raw.githubusercontent.com/NatLee/rime-setup/main/install.ps1 | iex
#
# 第一次跑＝安裝；之後再跑同一行＝更新到最新版＋重新選一次選項。
# 已經裝好的人也可以不連網重選：輸入法內打 '/setup（或雙擊 RIME 使用者資料夾裡的 na-setup.cmd）
#
# 不想被問（自動化／固定選項）：先設環境變數再跑，或直接帶參數
#   $env:NA_THEME='light'; $env:NA_EMOJI='off'; $env:NA_YES='1'; irm <網址> | iex
#   （-Yes＝全部用預設答案，所以缺 git／小狼毫時會直接安裝）
#   & ([scriptblock]::Create((irm <網址>))) -Theme light -Emoji off -Langs ja,en -Yes
#
# 這支腳本會：
#   確認 git／小狼毫（沒有就自動安裝）→ 把設定 repo 下載到 %USERPROFILE%\.na-plus（已有就更新）
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
    [string]$Theme,      # matcha | light | fluent | sakura | ocean | latte | dark | midnight | classic
    [string]$Dark,       # auto（系統深色模式時自動換成 Nat Dark）| off
    [string]$Layout,     # vertical | horizontal
    [string]$Size,       # small | medium | large（候選字級）
    [string]$Font,       # huninn（粉圓體，沒裝會自動下載）| system（系統內建）
    [string]$Paging,     # on | off（翻頁提示：編碼列右側可以點的 < >）
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
    param($Theme, $Dark, $Layout, $Size, $Font, $Paging, $Emoji, $Langs, $Gloss, [bool]$Yes, [bool]$NoDeploy, $Repo, $Branch, $RimeDir)

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
        @('fluent',   'Nat Fluent   低調淡灰＋藍色條'),
        @('sakura',   'Nat Sakura   櫻花粉'),
        @('ocean',    'Nat Ocean    海洋藍'),
        @('latte',    'Nat Latte    拿鐵棕'),
        @('dark',     'Nat Dark     深色'),
        @('midnight', 'Nat Midnight 午夜藍（深色）'),
        @('classic',  'Nat Classic  經典黃綠')
    )
    # 值 → color_scheme。各主題的長相見 README 的預覽圖（docs/themes/）。
    $themeMap = @{ matcha = 'NatMatcha'; light = 'NatLight'; fluent = 'NatFluent'; sakura = 'NatSakura'; ocean = 'NatOcean'; latte = 'NatLatte'
                   dark = 'NatDark'; midnight = 'NatMidnight'; classic = 'NatLee' }
    $darkThemes = 'dark', 'midnight'   # 本身就是深色的主題：系統深色模式時不必再換
    $darkItems = @(
        @('auto', '跟隨系統：系統切到深色模式時，候選窗自動換成 Nat Dark（預設）'),
        @('off',  '不跟隨：永遠用上面選的主題')
    )
    $sizeItems = @( @('small', '小'), @('medium', '中（預設）'), @('large', '大') )
    $sizeMap = @{   # 值 → (小狼毫候選字, 小狼毫標籤與註釋, 鼠鬚管候選字, 鼠鬚管標籤與註釋)，單位 pt
        small  = @(15, 12, 18, 13)
        medium = @(17, 13, 21, 15)
        large  = @(20, 15, 24, 17)
    }
    $layoutItems = @( @('vertical', '直排（預設）'), @('horizontal', '橫排') )
    $emojiItems  = @( @('on', '開：候選裡附帶對應的 emoji（預設）'), @('off', '關') )
    $pagingItems = @( @('on', '開：編碼列右側顯示可以點的 < >，還能往哪邊翻，那邊就是主題色（預設）'), @('off', '關') )
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
    $fontItems  = @( @('huninn', '粉圓體：圓潤的開源字型 jf open 粉圓（預設；沒裝會自動下載安裝，約 5 MB）'), @('system', '系統字型：微軟正黑體') )
    $glossMap   = @{ zh = 0; en = 1; ja = 2 }

    $defaults = @{ theme = 'matcha'; dark = 'auto'; size = 'medium'; font = 'huninn'; paging = 'on'; layout = 'vertical'; emoji = 'on'; langs = 'ja,ko,en,extra'; gloss = 'zh' }

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

    # ── 缺的程式自動裝 ────────────────────────────────────────────────
    # 安裝程式只把新路徑寫進登錄檔的 PATH，已經開著的視窗（包括正在跑這支腳本的這個）
    # 看不到 —— 以前裝完 git 要「開新視窗再跑一次」就是這個原因。這裡從登錄檔讀回來。
    function Update-SessionPath {
        $all = @()
        foreach ($scope in 'Machine', 'User') {
            $p = [Environment]::GetEnvironmentVariable('Path', $scope)
            if ($p) { $all += ($p -split ';') }
        }
        $all += ($env:PATH -split ';')   # 這個視窗自己加過的也留著
        $seen = @{}; $out = @()
        foreach ($d in $all) {
            $d = [Environment]::ExpandEnvironmentVariables($d.Trim())
            if ($d -and -not $seen.ContainsKey($d.ToLower())) { $seen[$d.ToLower()] = $true; $out += $d }
        }
        $env:PATH = $out -join ';'
    }

    function Find-Git {
        if (Get-Command git.exe -ErrorAction SilentlyContinue) { return $true }
        Update-SessionPath
        if (Get-Command git.exe -ErrorAction SilentlyContinue) { return $true }
        # 登錄檔也還沒有（少數安裝方式不寫 PATH）：直接找常見的安裝位置
        foreach ($base in $env:ProgramFiles, $env:ProgramW6432, (Join-Path $env:LOCALAPPDATA 'Programs')) {
            if (-not $base) { continue }
            $cmd = Join-Path $base 'Git\cmd'
            if (Test-Path (Join-Path $cmd 'git.exe')) { $env:PATH = "$cmd;$env:PATH"; return $true }
        }
        return $false
    }

    # 預設是「要裝」：-Yes 直接裝；能問就問；不能問（輸入被導向）就不裝。
    function Confirm-Install ([string]$what) {
        if ($Yes) { return $true }
        if (-not $interactive) { return $false }
        return ((Read-Host "  找不到${what}。要自動安裝嗎？[Y/n]").Trim() -notmatch '^[nN]')
    }

    # 先用 winget；沒有 winget（舊版 Windows 10、LTSC、Windows 沙箱）或它失敗，
    # 就從 GitHub 下載官方安裝檔靜默安裝。兩條路都會跳一次 UAC（都裝到 Program Files）。
    # $found：裝完用來確認「真的裝好了」的檢查，不看安裝程式的 exit code。
    function Install-App ([string]$name, [string]$wingetId, [string]$override,
                          [string]$ghRepo, [string]$assetPattern, [string]$silentArgs, [scriptblock]$found) {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Say "  用 winget 安裝${name}…"
            $wa = @('install', '--id', $wingetId, '-e', '--source', 'winget', '--accept-source-agreements', '--accept-package-agreements')
            if ($override) { $wa += @('--override', $override) }
            $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            try { & winget @wa } catch { } finally { $ErrorActionPreference = $old }
            if (& $found) { return $true }
            Warn 'winget 沒有裝成功，改從 GitHub 下載官方安裝檔。'
        }
        $tmp = $null
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$ghRepo/releases/latest" -UseBasicParsing -Headers @{ 'User-Agent' = 'na-plus-installer' }
            $asset = @($rel.assets | Where-Object { $_.name -match $assetPattern }) | Select-Object -First 1
            if (-not $asset) { throw "在 $ghRepo $($rel.tag_name) 找不到安裝檔" }
            $tmp = Join-Path ([IO.Path]::GetTempPath()) ('na-plus-' + [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Force $tmp | Out-Null
            $exe = Join-Path $tmp $asset.name
            Say ('  下載 {0}（{1:N0} MB）…' -f $asset.name, ($asset.size / 1MB))
            $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'   # 5.1 的進度條會讓下載慢十倍
            try { Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $exe -UseBasicParsing } finally { $ProgressPreference = $old }
            Say '  安裝中（跳出「是否允許變更」時請按「是」）…'
            Start-Process -FilePath $exe -ArgumentList $silentArgs -Verb RunAs -Wait | Out-Null
        } catch {
            Warn "自動安裝${name}失敗：$($_.Exception.Message)"
        } finally {
            if ($tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
        }
        return [bool](& $found)
    }
    $isArm = ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') -or ($env:PROCESSOR_ARCHITEW6432 -eq 'ARM64')

    # ── [1] git ───────────────────────────────────────────────────────
    Step '檢查 git'
    if (-not (Find-Git)) {
        $gitAsset = '^Git-[\d.]+-64-bit\.exe$'
        if ($isArm) { $gitAsset = '^Git-[\d.]+-arm64\.exe$' }
        if (Confirm-Install ' git') {
            [void](Install-App ' git' 'Git.Git' '' 'git-for-windows/git' $gitAsset '/VERYSILENT /NORESTART /NOCANCEL /SP- /SUPPRESSMSGBOXES' { Find-Git })
        }
        if (-not (Find-Git)) {
            Die '需要 git。請先安裝 https://git-scm.com/download/win （或 winget install Git.Git），再跑一次這行指令。'
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
        # /S＝靜默、/T＝註冊成「中文（台灣）」的輸入法。只給 /S 會註冊成簡體中文
        # （小狼毫安裝檔 install.nsi 的行為；winget 預設就只給 /S，所以要 --override）。
        if (Confirm-Install '小狼毫') {
            [void](Install-App '小狼毫' 'Rime.Weasel' '/S /T' 'rime/weasel' '^weasel-[\d.]+-installer\.exe$' '/S /T' { [bool](Find-Weasel) })
            $weaselRoot = Find-Weasel
            if ($weaselRoot) { Ok '小狼毫裝好了。之後在工作列的輸入法清單（Win＋空白鍵）選「小狼毫」就能用。' }
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
        foreach ($f in 'installation.yaml', 'user.yaml', 'bopomo_onionplus_phrase.txt',
                            'na_style.custom.yaml', 'na_input.custom.yaml', 'na_menu.custom.yaml', 'na_options.custom.yaml') {
            $src = Join-Path $backup $f
            if (Test-Path $src) { Copy-Item -LiteralPath $src -Destination $RimeDir -Force }
        }
        Ok "已從備份還原 $n 個詞頻資料庫與個人檔案"
        Say "    備份留在 $backup，確認一切正常後可自行刪除。"
    }

    # ── [5b] 選項 ─────────────────────────────────────────────────────
    # 選項分三個檔（原因見 rime\core\na_style.yaml 檔頭）：長相 na_style、輸入行為 na_input、方案清單 na_menu。
    # 上次的選擇記在各檔檔頭那行「# na-options: k=v k=v」。na_options.custom.yaml 是舊版的單一檔，
    # 先讀它、再讓新檔蓋過去（舊檔之後由 rime-apply.ps1 收掉）。
    $styleFile = Join-Path $RimeDir 'na_style.custom.yaml'
    $inputFile = Join-Path $RimeDir 'na_input.custom.yaml'
    $menuFile  = Join-Path $RimeDir 'na_menu.custom.yaml'
    $prev = @{}
    foreach ($pf in (Join-Path $RimeDir 'na_options.custom.yaml'), $styleFile, $inputFile, $menuFile) {
        if (-not (Test-Path -LiteralPath $pf)) { continue }
        $line = Get-Content -LiteralPath $pf -Encoding UTF8 | Where-Object { $_ -match '^#\s*na-options:' } | Select-Object -First 1
        if ($line) {
            foreach ($kv in (($line -replace '^#\s*na-options:', '').Trim() -split '\s+')) {
                $p = $kv -split '=', 2
                if ($p.Count -eq 2) { $prev[$p[0]] = $p[1] }
            }
        }
    }
    # ── 小狼毫自己的「輸入法設定」對話框選的東西 ──
    # 那個對話框把配色寫進 weasel.custom.yaml 的 "style/color_scheme"、把勾選的方案寫進
    # default.custom.yaml 的 schema_list。這兩個檔是使用者的（見 scripts\rime-apply.ps1），寫在裡面的鍵
    # 會蓋過這裡選的選項。所以：選項畫面要把它當成「目前的值」顯示；在這裡重選時把那一筆拿掉，
    # 之後以選項檔為準。誰最後動手就聽誰的，兩邊不會各說各話。
    $weaselUser  = Join-Path $RimeDir 'weasel.custom.yaml'
    $defaultUser = Join-Path $RimeDir 'default.custom.yaml'
    $reTheme  = '(?m)^  "?style/color_scheme"?:[ \t]*"?([^"\s#{]+)"?[ \t]*(#[^\r\n]*)?\r?$\n?'
    $reSchema = '(?m)^  "?schema_list"?:[^\r\n]*\r?\n?(?:(?:[ \t]{3,}|  -)[^\r\n]*\r?\n?)*'   # 那一行＋底下縮排更深的清單
    $guiTheme = ''; $guiThemeKnown = $false; $guiSchemas = 0
    if (Test-Path -LiteralPath $weaselUser) {
        $dm = [regex]::Match([IO.File]::ReadAllText($weaselUser), $reTheme)
        if ($dm.Success) { $guiTheme = $dm.Groups[1].Value }
    }
    if (Test-Path -LiteralPath $defaultUser) {
        $dt = [IO.File]::ReadAllText($defaultUser)
        # 只認新格式的檔（接上 na_default 的）；舊版面的 default.custom.yaml 整個是 repo 的內容，套用時會換掉
        if ($dt -match '(?m)^[^#\r\n]*na_default:/patch') {
            $sm = [regex]::Match($dt, $reSchema)
            if ($sm.Success) { $guiSchemas = [regex]::Matches($sm.Value, 'schema:').Count }
        }
    }
    # 對話框選的是這套的主題 → 當成上次的選擇；選的是別的配色（使用者自己加的）→ 原樣留著，除非這次重選
    foreach ($k in $themeMap.Keys) { if ($guiTheme -and $themeMap[$k] -eq $guiTheme) { $prev['theme'] = $k; $guiThemeKnown = $true } }

    $opt = @{}
    $given = @{ theme = (Pick $Theme 'NA_THEME'); dark = (Pick $Dark 'NA_DARK'); size = (Pick $Size 'NA_SIZE'); font = (Pick $Font 'NA_FONT'); paging = (Pick $Paging 'NA_PAGING'); layout = (Pick $Layout 'NA_LAYOUT'); emoji = (Pick $Emoji 'NA_EMOJI')
                langs = (Pick $Langs 'NA_LANGS'); gloss = (Pick $Gloss 'NA_GLOSS') }
    $edited = @{}   # 這次明確指定過的項目（參數／環境變數／在選項畫面改過）
    foreach ($k in $defaults.Keys) {
        if ($given[$k])     { $opt[$k] = $given[$k].ToLower(); $edited[$k] = $true }
        elseif ($prev[$k])  { $opt[$k] = $prev[$k] }
        else                { $opt[$k] = $defaults[$k] }
    }
    # 系統現在是不是深色模式（跟小狼毫看的是同一個登錄值）：選項畫面用來提示「為什麼換了主題沒變」
    $sysDark = $false
    try { $sysDark = ((Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -ErrorAction Stop).AppsUseLightTheme -eq 0) } catch { }

    # 舊值相容：以前「跟隨系統」是主題的一個選項（auto），現在拆成獨立的 dark 選項
    if ($opt.theme -eq 'auto') { $opt.theme = 'light'; if (-not $given.dark) { $opt.dark = 'auto' } }

    if ($interactive) {
        # 全部設定。這裡的順序是「輸入編號」版本的 1~9，跟 macOS 的 install.sh 一致，不要動；
        # 選項畫面會照 group 重新排成兩組：外觀（看得到的）與輸入（打字時的行為）。
        # ask 是「輸入編號」版本問的那句；hint 是選項畫面底下那行「這一項在做什麼」。
        $rows = @(
            @{ key = 'theme';  group = '外觀'; title = '主題　　　　'; items = $themeItems;  ask = '主題（候選窗配色，長相見 README 的預覽圖）'; hint = '候選窗的配色。用 ←→ 換，右邊就是它實際的顏色。' },
            @{ key = 'dark';   group = '外觀'; title = '系統深色模式'; items = $darkItems;   ask = '系統深色模式'; hint = '系統切到深色模式時，候選窗要不要跟著換成深色。' },
            @{ key = 'layout'; group = '外觀'; title = '候選排列　　'; items = $layoutItems; ask = '候選排列'; hint = '候選字直的排，還是橫的排成一列。' },
            @{ key = 'size';   group = '外觀'; title = '候選字級　　'; items = $sizeItems;   ask = '候選字級'; hint = '候選字的大小，標籤與註釋會跟著調整。' },
            @{ key = 'emoji';  group = '輸入'; title = '候選附 emoji'; items = $emojiItems;  ask = '打字時候選附帶 emoji（之後仍可在方案選單臨時切換）'; hint = '打字時候選裡要不要附上對應的 emoji。這是預設狀態，之後仍可在方案選單臨時切換。' },
            @{ key = 'langs';  group = '輸入'; title = '選單裡的語言'; items = $langItems;   ask = '方案選單要放哪些語言（注音一定有）'; multi = $true; hint = '方案選單與右 Shift 循環裡要放哪些語言（注音一定有）。←→ 移動，空白鍵勾選。' },
            @{ key = 'gloss';  group = '輸入'; title = '釋義語言　　'; items = $glossItems;  ask = '日文／英文候選的釋義要用哪種語言顯示'; hint = '日文、英文候選旁邊的釋義，用哪種語言顯示。' },
            @{ key = 'font';   group = '外觀'; title = '候選字型　　'; items = $fontItems;   ask = '候選字型'; hint = '候選字用哪一套字型。' },
            @{ key = 'paging'; group = '外觀'; title = '翻頁提示　　'; items = $pagingItems; ask = '翻頁提示（編碼列右側可以點的 < >）'; hint = '編碼列右側要不要顯示可以點的 < >，看得出前後還有沒有候選。' }
        )
        function Show-Value($row) {
            $v = $opt[$row.key]
            # 對話框那邊的自訂還在生效（這次沒在這裡重選）→ 照實顯示，不要假裝是選項檔的值
            if ($row.key -eq 'theme' -and $guiTheme -and -not $guiThemeKnown -and -not $edited.theme) {
                return "自訂配色 $guiTheme（在小狼毫「輸入法設定」選的；改這一項會取代它）"
            }
            if ($row.key -eq 'langs' -and $guiSchemas -and -not $edited.langs) {
                return "自訂的 $guiSchemas 個方案（在小狼毫「方案選單設定」勾的；改這一項會取代它）"
            }
            if ($row.multi) {
                $picked = @($row.items | Where-Object { ($v -split ',') -contains $_[0] } | ForEach-Object { ($_[1] -split '：')[0] })
                if ($picked.Count) { return ($picked -join '、') } else { return '只有注音' }
            }
            $hit = $row.items | Where-Object { $_[0] -eq $v } | Select-Object -First 1
            if ($hit) { return (($hit[1] -replace '（預設）', '') -replace '\s{2,}', ' ').Trim() }
            return $v
        }
        # 從輸入法打 '/setup 進來的話，lua 在啟動前留了一個時間戳（na_launch.stamp）。
        # 這裡算出「從按下到選單出現」花了多久。正常大約一秒，不吵人；超過兩秒才印在標題旁、
        # 並寫進 na_launch.log —— 啟動慢在哪，只有真的從輸入法啟動時量得到（從外面模擬，量到的是
        # 另一種行程的啟動時間；「os.execute 讓輸入法卡五秒」就是靠這幾個數字找到的，見 p_generic_open.lua）。
        # 分四段：輸入法服務卡在啟動指令多久（na_launch.ret）、到批次檔開始跑（rime-setup.cmd 把
        # 當時的 %time% 放在 NA_T_CMD）、到這個 PowerShell 行程起來、到選單列出來。
        # 想看每一次的數字：設環境變數 NA_LAUNCH_TIMING=1。
        $launchSlow = 2.0
        $launchNote = ''
        $stampFile = Join-Path $RimeDir 'na_launch.stamp'
        $retFile   = Join-Path $RimeDir 'na_launch.ret'
        if (Test-Path -LiteralPath $stampFile) {
            $now = Get-Date
            $t0 = (Get-Item -LiteralPath $stampFile).LastWriteTime
            $age = ($now - $t0).TotalSeconds
            if ($age -ge 0 -and $age -lt 60) {
                $parts = @()
                $tCmd = $null
                if ((Pick '' 'NA_T_CMD') -match '(\d+):(\d+):(\d+)[.,](\d+)') {
                    $tCmd = $t0.Date.AddHours([int]$Matches[1]).AddMinutes([int]$Matches[2]).AddSeconds([int]$Matches[3]).AddMilliseconds([int]$Matches[4] * 10)
                    $parts += ('到批次檔開始跑 {0:N1}' -f ($tCmd - $t0).TotalSeconds)
                }
                $tPs = (Get-Process -Id $PID).StartTime
                if ($tCmd) { $parts += ('到 PowerShell 啟動 {0:N1}' -f ($tPs - $tCmd).TotalSeconds) }
                $parts += ('腳本到選單 {0:N1}' -f ($now - $tPs).TotalSeconds)
                if (Test-Path -LiteralPath $retFile) {
                    $parts += ('輸入法卡住 {0:N1}' -f ((Get-Item -LiteralPath $retFile).LastWriteTime - $t0).TotalSeconds)
                }
                if ($age -ge $launchSlow -or (Pick '' 'NA_LAUNCH_TIMING')) {
                    $launchNote = '　（從按下到這裡 {0:N1} 秒：{1}）' -f $age, ($parts -join '｜')
                    try { Add-Content -LiteralPath (Join-Path $RimeDir 'na_launch.log') -Value ($now.ToString('yyyy-MM-dd HH:mm:ss') + $launchNote) -Encoding UTF8 } catch { }
                }
            }
            Remove-Item -LiteralPath $stampFile, $retFile -Force -ErrorAction SilentlyContinue
        }

        # ════ 選項畫面 ═══════════════════════════════════════════════════
        # 以前是「輸入編號 → Enter → 再輸入編號 → Enter → 再 Enter 套用」，換個主題要按五六下，而且主題
        # 只有名字、看不到長相。現在一個畫面、方向鍵操作：↑↓ 選項目、←→ 直接換值；右邊用主題真正的顏色
        # 畫一個候選窗，換到哪個就看到哪個；改了什麼列在下面，Backspace 還原那一項，Esc 全部不算。
        # 幾個刻意的決定（改之前先看）：
        #   ‧ 所有文字都用「絕對座標」定位，不靠補空白對齊。中日文字、箭頭這類字元在不同終端機佔一格
        #     還是兩格不一定（Windows Terminal 與傳統主控台就不一樣），算錯只會歪一個字，不會整排亂掉。
        #   ‧ 預覽的色塊是「有底色的空白」，不用方塊／框線字元（傳統主控台的中文字型把它們畫成兩格寬）。
        #   ‧ 介面本身只用終端機的預設色＋灰＋一個強調色，深色、淺色的終端機都看得清楚；真彩色只用在
        #     預覽那一塊。焦點用 ▸、改過的用 ● 標示，不只靠顏色分辨。
        #   ‧ 終端機不支援 VT、輸入輸出被重導向、或視窗太小 → 退回下面的「輸入編號」版本。NA_PLAIN=1 強制退回。
        #   ‧ 測試用：NA_TUI_KEYS（例如 "Down,Right,Enter"）＝不讀鍵盤，照這串按鍵走（Wait＝停四秒）；
        #     NA_TUI_DUMP＝把最後畫出來的那一格畫面（含控制碼）寫進這個檔。
        function Show-OptionsScreen([string]$scriptKeys, [string]$note) {
            $CSI = [string][char]27 + '['
            $kReset = "${CSI}0m"; $kDim = "${CSI}90m"; $kAccent = "${CSI}36m"; $kBold = "${CSI}1m"; $kReverse = "${CSI}7m"
            function At([int]$r, [int]$c) { return "$CSI$r;${c}H" }
            # 字串在終端機上佔幾格（中日韓文字與全形符號算兩格）
            function Cells([string]$s) {
                $w = 0
                foreach ($ch in $s.ToCharArray()) {
                    $c = [int]$ch
                    if (($c -ge 0x1100 -and $c -le 0x115F) -or ($c -ge 0x2E80 -and $c -le 0xA4CF) -or ($c -ge 0xAC00 -and $c -le 0xD7A3) -or
                        ($c -ge 0xF900 -and $c -le 0xFAFF) -or ($c -ge 0xFE30 -and $c -le 0xFE4F) -or ($c -ge 0xFF00 -and $c -le 0xFF60) -or
                        ($c -ge 0xFFE0 -and $c -le 0xFFE6)) { $w += 2 } else { $w += 1 }
                }
                return $w
            }
            # 超過寬度就截掉、補上 …（底下那幾行說明太長時不可以折行，一折整個畫面就錯位）
            function Fit([string]$s, [int]$max) {
                if ((Cells $s) -le $max) { return $s }
                $out = ''; $w = 0
                foreach ($ch in $s.ToCharArray()) { $cw = Cells ([string]$ch); if ($w + $cw -gt $max - 1) { break }; $out += $ch; $w += $cw }
                return $out + '…'
            }
            # 小狼毫的顏色是 0xBBGGRR → 終端機真彩色用的 "R;G;B"
            function Rgb([string]$v, [string]$fallback) {
                if (-not $v -or $v -notmatch '^0x([0-9A-Fa-f]+)$') { return $fallback }
                $h = $Matches[1].PadLeft(6, '0'); $h = $h.Substring($h.Length - 6)
                return ('{0};{1};{2}' -f [Convert]::ToInt32($h.Substring(4, 2), 16), [Convert]::ToInt32($h.Substring(2, 2), 16), [Convert]::ToInt32($h.Substring(0, 2), 16))
            }
            # 選項值的顯示文字：「短名：說明」拆成兩段，短名放在列上、說明放在下面那行
            function Short($row, [string]$v) {
                $hit = $row.items | Where-Object { $_[0] -eq $v } | Select-Object -First 1
                if (-not $hit) { return $v }
                return (((($hit[1] -replace '（預設）', '') -replace '\s{2,}', ' ').Trim()) -split '：', 2)[0]
            }
            function Detail($row, [string]$v) {
                $hit = $row.items | Where-Object { $_[0] -eq $v } | Select-Object -First 1
                if (-not $hit) { return '' }
                $p = ((($hit[1] -replace '（預設）', '') -replace '\s{2,}', ' ').Trim()) -split '：', 2
                if ($p.Count -eq 2) { return $p[1] }
                return ''
            }

            # 各主題的顏色：直接讀 repo 裡的配色定義，預覽畫的就是輸入法會用的那組顏色
            $schemes = @{}; $cur = $null; $inPreset = $false
            $themeFile = Join-Path $SrcDir 'rime\theme\na_weasel.yaml'
            if (Test-Path -LiteralPath $themeFile) {
                foreach ($ln in [IO.File]::ReadAllLines($themeFile, [Text.Encoding]::UTF8)) {
                    if ($ln -match '^  preset_color_schemes:') { $inPreset = $true; continue }
                    if (-not $inPreset) { continue }
                    if ($ln -match '^    ([A-Za-z0-9_]+):\s*$') { $cur = $Matches[1]; $schemes[$cur] = @{}; continue }
                    if ($cur -and $ln -match '^      ([a-z_]+):\s*(\S+)') { $schemes[$cur][$Matches[1]] = $Matches[2] }
                }
            }

            # 進來時的樣子：Esc／Backspace 要還原回這裡，「改了什麼」也是跟它比
            $snap = @{}; foreach ($k in @($opt.Keys)) { $snap[$k] = $opt[$k] }
            $snapEdited = @{}; foreach ($k in @($edited.Keys)) { $snapEdited[$k] = $edited[$k] }
            # 小狼毫對話框那邊的自訂（不是這套的配色、自己勾的方案清單）：沒在這裡動那一項就原樣留著
            $custom = @{ theme = [bool]($guiTheme -and -not $guiThemeKnown); langs = [bool]$guiSchemas }
            function Is-Custom([string]$key) { return ($custom[$key] -and -not $edited[$key]) }
            function Is-Changed([string]$key) {
                if ($opt[$key] -ne $snap[$key]) { return $true }
                return ($custom[$key] -and $edited[$key] -and -not $snapEdited[$key])
            }
            function Old-Text($row) {
                if ($row.key -eq 'theme' -and $custom.theme -and -not $snapEdited.theme) { return "自訂配色 $guiTheme" }
                if ($row.key -eq 'langs' -and $custom.langs -and -not $snapEdited.langs) { return "自訂的 $guiSchemas 個方案" }
                if ($row.multi) { return (Langs-Text $snap.langs) }
                return (Short $row $snap[$row.key])
            }
            function Langs-Text([string]$v) {
                $names = @($langItems | Where-Object { ($v -split ',') -contains $_[0] } | ForEach-Object { ($_[1] -split '：')[0] })
                if ($names.Count) { return ($names -join '、') }
                return '只有注音'
            }

            # 數字鍵照「輸入編號」的編號跳（外面那份 $rows 的順序），兩種畫面的同一個數字才會是同一項
            $numbered = @($rows | ForEach-Object { $_.key })
            # 畫面上照組別排（外觀在前、輸入在後）。這是函式自己的 $rows，外面那份「輸入編號」用的順序不受影響
            $rows = @($rows | Where-Object { $_.group -eq '外觀' }) + @($rows | Where-Object { $_.group -eq '輸入' })
            $focus = 0; $chip = 0
            $queue = $null
            if ($scriptKeys) { $queue = New-Object System.Collections.Queue; foreach ($k in ($scriptKeys -split '[,\s]+' | Where-Object { $_ })) { $queue.Enqueue($k) } }
            $dump = Pick '' 'NA_TUI_DUMP'

            function Render {
                $cols = 120
                try { $cols = [Console]::WindowWidth } catch { }
                $sb = New-Object System.Text.StringBuilder
                function Put([string]$s) { [void]$sb.Append($s) }
                function Block([int]$y, [int]$x, [int]$w, [string]$bg) { Put ((At $y $x) + "${CSI}48;2;${bg}m" + (' ' * $w) + $kReset) }
                function Ink([int]$y, [int]$x, [string]$s, [string]$fg, [string]$bg, [bool]$bold) {
                    $b = ''; if ($bold) { $b = $kBold }
                    Put ((At $y $x) + "${CSI}48;2;${bg}m${CSI}38;2;${fg}m" + $b + $s + $kReset)
                }

                Put "${CSI}?25l"
                for ($r = 1; $r -le 23; $r++) { Put ((At $r 1) + "${CSI}2K") }
                Put ((At 2 3) + $kBold + '注音Na+ 設定' + $kReset)
                if ($note) { Put ((At 2 18) + $kDim + (Fit $note ($cols - 20)) + $kReset) }

                # ── 左邊：選項 ──
                # 每一組前面一行灰色的組名，組與組之間空一行（相近的東西靠在一起，掃一眼就找得到）
                $top = 4; $xLabel = 5; $xValue = 22
                $y = $top - 1; $group = ''
                for ($i = 0; $i -lt $rows.Count; $i++) {
                    $row = $rows[$i]; $on = ($i -eq $focus)
                    if ($row.group -ne $group) {
                        if ($group) { $y += 2 } else { $y += 1 }
                        $group = $row.group
                        Put ((At $y 3) + $kDim + $group + $kReset)
                    }
                    $y++
                    if (Is-Changed $row.key) { Put ((At $y 1) + $kAccent + '●' + $kReset) }
                    if ($on) { Put ((At $y 3) + $kAccent + '▸' + $kReset + (At $y $xLabel) + $kBold + $row.title.Trim('　') + $kReset) }
                    else { Put ((At $y $xLabel) + $row.title.Trim('　')) }
                    Put (At $y $xValue)
                    if (Is-Custom $row.key) {
                        $t = "自訂配色 $guiTheme"; if ($row.multi) { $t = "自訂的 $guiSchemas 個方案" }
                        if ($on) { Put ($kAccent + $kBold + $t + $kReset + $kDim + '   小狼毫對話框選的' + $kReset) } else { Put $t }
                    } elseif ($row.multi) {
                        # 可複選的那一項：一排核取方塊，←→ 移動、空白鍵勾選
                        $set = @($opt.langs -split ',' | Where-Object { $_ -and $_ -ne 'none' })
                        for ($j = 0; $j -lt $row.items.Count; $j++) {
                            $box = '[ ] '; if ($set -contains $row.items[$j][0]) { $box = '[x] ' }
                            $t = $box + (($row.items[$j][1] -split '：')[0])
                            if ($on -and $j -eq $chip) { Put ($kReverse + $t + $kReset + '  ') } else { Put ($t + '  ') }
                        }
                    } else {
                        $ids = @($row.items | ForEach-Object { $_[0] })
                        $t = Short $row $opt[$row.key]
                        if ($on) { Put ($kDim + '‹ ' + $kReset + $kAccent + $kBold + $t + $kReset + $kDim + (' ›   {0}/{1}' -f ([array]::IndexOf($ids, $opt[$row.key]) + 1), $ids.Count) + $kReset) }
                        else { Put $t }
                    }
                }

                # ── 下面：這一項在做什麼、目前這個值的說明 ──
                $row = $rows[$focus]
                $help = $row.hint; $more = ''
                if (Is-Custom $row.key) { $more = '在小狼毫「輸入法設定」那邊選的，沒動這一項就原樣留著；用 ←→ 或空白鍵改成這裡的選項會取代它。' }
                elseif ($row.multi) { $more = Detail $row $row.items[$chip][0]; if (-not $more) { $more = '注音一定有；勾起來的語言會出現在方案選單（Ctrl+` 或 F4）與右 Shift 的循環裡。' } }
                else { $more = Detail $row $opt[$row.key] }
                if (($row.key -eq 'theme' -or $row.key -eq 'dark') -and $sysDark -and $opt.dark -eq 'auto' -and $darkThemes -notcontains $opt.theme) {
                    $more = '系統現在是深色模式，所以實際看到的是 Nat Dark。想在深色模式也用這個主題：把「系統深色模式」換成不跟隨。'
                }
                # 這一項只管這套的主題（每套配色有一行 __patch 接開關）；對話框選的自訂配色管不到
                if ($row.key -eq 'paging' -and (Is-Custom 'theme')) {
                    $more = "現在用的是在小狼毫對話框選的「$guiTheme」，這一項管不到它：它的 < > 照它自己的配色設定。"
                }
                Put ((At 17 3) + (Fit $help ($cols - 4)))
                Put ((At 18 3) + $kDim + (Fit $more ($cols - 4)) + $kReset)

                # ── 改了什麼 ──
                $diff = @()
                foreach ($x in $rows) {
                    if (-not (Is-Changed $x.key)) { continue }
                    $new = Short $x $opt[$x.key]; if ($x.multi) { $new = Langs-Text $opt.langs }
                    $diff += ('{0}：{1} → {2}' -f $x.title.Trim('　'), (Old-Text $x), $new)
                }
                if ($diff.Count) {
                    # 一行放得下就列出「舊 → 新」；放不下改成只列改了哪幾項（寧可少講，也不要被截掉一半）
                    $line = '已修改　' + ($diff -join '　｜　')
                    if ((Cells $line) -gt ($cols - 4)) { $line = ('已修改 {0} 項　' -f $diff.Count) + (($diff | ForEach-Object { ($_ -split '：', 2)[0] }) -join '、') }
                    Put ((At 20 1) + $kAccent + '●' + $kReset + (At 20 3) + (Fit $line ($cols - 4)))
                }
                else { Put ((At 20 3) + $kDim + '還沒有修改。直接按 Enter 就是什麼都不改。' + $kReset) }

                # ── 按鍵提示（每一段各自定位，箭頭字元寬度算錯也不會擠到後面）──
                $hints = @(@('↑↓', '選項目'), @('←→', '換一個'), @('空白', '勾選'), @('Backspace', '還原這一項'), @('Enter', '套用'), @('Esc', '取消'))
                $x = 3
                foreach ($h in $hints) { Put ((At 22 $x) + $kAccent + $h[0] + $kReset + ' ' + $kDim + $h[1] + $kReset); $x += (Cells $h[0]) + (Cells $h[1]) + 4 }

                # ── 右邊：用主題真正的顏色畫一個候選窗 ──
                $px = 70; $pw = 32
                if ($cols -ge ($px + $pw + 2)) {
                    $byKey = @{}; foreach ($x in $rows) { $byKey[$x.key] = $x }
                    # 圖說只放英文名（「Nat Matcha 抹茶奶油色」取前兩個字），再帶上畫不出來的那兩項：排列與字級
                    $name = $themeMap[$opt.theme]
                    $caption = '{0} · {1} · 字級{2}' -f (((Short $byKey.theme $opt.theme) -split ' ')[0..1] -join ' '), (Short $byKey.layout $opt.layout), (Short $byKey.size $opt.size)
                    if ($rows[$focus].key -eq 'dark' -and $opt.dark -eq 'auto' -and $darkThemes -notcontains $opt.theme) { $name = 'NatDark'; $caption = '系統切到深色模式時 → Nat Dark' }
                    $c = $schemes[$name]
                    if ((Is-Custom 'theme') -or -not $c) {
                        Put ((At ($top + 3) $px) + $kDim + '（自訂配色，這裡沒有它的顏色資料）' + $kReset)
                    } else {
                        $back = Rgb $c.back_color '255;255;255'; $frame = Rgb $c.border_color $back
                        $text = Rgb $c.text_color '0;0;0'; $hText = Rgb $c.hilited_text_color $text; $hBack = Rgb $c.hilited_back_color $back
                        $label = Rgb $c.label_color $text; $cand = Rgb $c.candidate_text_color $text; $cmt = Rgb $c.comment_text_color $label
                        $hcBack = Rgb $c.hilited_candidate_back_color $hBack; $hcText = Rgb $c.hilited_candidate_text_color $hText
                        $hcLabel = Rgb $c.hilited_candidate_label_color $hcText; $hcCmt = Rgb $c.hilited_comment_text_color $hcText
                        $mark = Rgb $c.hilited_mark_color $hcText; $page = Rgb $c.nextpage_color $text
                        $ix = $px + 2; $iw = $pw - 4                    # 框裡面那一塊的左緣與寬度
                        $cands = @(@('你好', ''), @('妳好', ''), @('さくら', '櫻花'), @('hello', '哈囉'))
                        $tall = 8; if ($opt.layout -eq 'horizontal') { $tall = 5 }
                        for ($k = 0; $k -lt $tall; $k++) { Block ($top + $k) $px $pw $frame }
                        for ($k = 1; $k -lt $tall - 1; $k++) { Block ($top + $k) $ix $iw $back }
                        # 編碼列：已確定的部分＋高亮段，右側是翻頁箭頭（翻頁提示開的時候；第一頁 < 是一般文字色＝不能往前）
                        Ink ($top + 1) ($ix + 2) 'ㄋㄧ' $text $back $false
                        Ink ($top + 1) ($ix + 7) ' ㄏㄠ ' $hText $hBack $false
                        if ($opt.paging -eq 'on') {
                            Ink ($top + 1) ($ix + $iw - 6) '<' $label $back $false
                            Ink ($top + 1) ($ix + $iw - 3) '>' $page $back $true
                        }
                        if ($opt.layout -eq 'horizontal') {
                            $cx = $ix + 1
                            for ($k = 0; $k -lt 3; $k++) {
                                $w = (Cells $cands[$k][0]) + 4
                                if ($k -eq 0) { Block ($top + 3) $cx $w $hcBack; Ink ($top + 3) ($cx + 1) '1' $hcLabel $hcBack $false; Ink ($top + 3) ($cx + 3) $cands[$k][0] $hcText $hcBack $true }
                                else { Ink ($top + 3) ($cx + 1) ([string]($k + 1)) $label $back $false; Ink ($top + 3) ($cx + 3) $cands[$k][0] $cand $back $true }
                                $cx += $w + 1
                            }
                        } else {
                            for ($k = 0; $k -lt $cands.Count; $k++) {
                                $y = $top + 3 + $k
                                $bg = $back; $fgL = $label; $fgT = $cand; $fgC = $cmt
                                if ($k -eq 0) {
                                    $bg = $hcBack; $fgL = $hcLabel; $fgT = $hcText; $fgC = $hcCmt
                                    Block $y ($ix + 1) ($iw - 2) $hcBack
                                    Block $y ($ix + 1) 1 $mark              # 高亮列左側那條色條
                                }
                                Ink $y ($ix + 3) ([string]($k + 1)) $fgL $bg $false
                                Ink $y ($ix + 6) $cands[$k][0] $fgT $bg $true
                                if ($cands[$k][1]) { Ink $y ($ix + 8 + (Cells $cands[$k][0])) $cands[$k][1] $fgC $bg $false }
                            }
                        }
                        Put ((At ($top + $tall) $px) + $kDim + (Fit $caption $pw) + $kReset)
                    }
                }
                Put (At 23 1)
                return $sb.ToString()
            }

            try {
                while ($true) {
                    $frame = Render
                    # 一定要經過 PowerShell 的主機來寫（它走 Unicode）。用 [Console]::Write 的話會先照主控台的字碼頁
                    # （繁中是 Big5）編碼，Big5 沒有的字 —— ▸、‹ ›、日文假名 —— 全部變成問號（真實截圖才看得出來）。
                    $Host.UI.Write($frame)
                    if ($dump) { [IO.File]::WriteAllText($dump, $frame, (New-Object Text.UTF8Encoding $false)) }
                    $key = ''
                    if ($queue) { if ($queue.Count) { $key = [string]$queue.Dequeue() } else { $key = 'Enter' } }
                    else { $key = [string]([Console]::ReadKey($true)).Key }
                    $row = $rows[$focus]
                    $dir = 0
                    if ($key -eq 'Wait') { Start-Sleep -Seconds 4; continue }   # 只有按鍵腳本會有：停在這一格（截圖用，見 tools\setup-screenshot.ps1）
                    if ($key -match '^(Enter)$') { break }
                    elseif ($key -match '^(Escape|Esc|Q)$') {
                        # 全部不算：選項回到進來時的樣子
                        foreach ($k in @($snap.Keys)) { $opt[$k] = $snap[$k] }
                        $edited.Clear(); foreach ($k in @($snapEdited.Keys)) { $edited[$k] = $snapEdited[$k] }
                        break
                    }
                    elseif ($key -match '^(UpArrow|Up|K)$')     { $focus = ($focus + $rows.Count - 1) % $rows.Count }
                    elseif ($key -match '^(DownArrow|Down|J|Tab)$') { $focus = ($focus + 1) % $rows.Count }
                    elseif ($key -match '^(Home|PageUp)$')      { $focus = 0 }
                    elseif ($key -match '^(End|PageDown)$')     { $focus = $rows.Count - 1 }
                    elseif ($key -match '^(?:D|NumPad)?([1-9])$' -and [int]$Matches[1] -le $numbered.Count) {
                        $want = $numbered[[int]$Matches[1] - 1]
                        for ($k = 0; $k -lt $rows.Count; $k++) { if ($rows[$k].key -eq $want) { $focus = $k } }
                    }
                    elseif ($key -match '^(Backspace|Delete)$') {
                        # 還原這一項（含「回到小狼毫對話框那邊的自訂」）
                        $opt[$row.key] = $snap[$row.key]
                        if ($snapEdited[$row.key]) { $edited[$row.key] = $true } else { $edited.Remove($row.key) }
                    }
                    elseif ($key -match '^(LeftArrow|Left|H)$')  { $dir = -1 }
                    elseif ($key -match '^(RightArrow|Right|L)$') { $dir = 1 }
                    elseif ($key -match '^(Spacebar|Space)$')    { $dir = 2 }      # 2＝空白鍵：單選是「下一個」，複選是「勾／取消」
                    if (-not $dir) { continue }

                    if ($row.multi) {
                        if (Is-Custom $row.key) { $edited[$row.key] = $true; continue }   # 第一下只是「改成在這裡選」，不動內容
                        if ($dir -eq 2) {
                            $id = $row.items[$chip][0]
                            $set = @($opt.langs -split ',' | Where-Object { $_ -and $_ -ne 'none' })
                            if ($set -contains $id) { $set = @($set | Where-Object { $_ -ne $id }) } else { $set += $id }
                            # 照清單的順序排，不然同樣的選擇會因為勾的先後不同而被當成有變動
                            $set = @($row.items | ForEach-Object { $_[0] } | Where-Object { $set -contains $_ })
                            if ($set.Count) { $opt.langs = ($set -join ',') } else { $opt.langs = 'none' }
                            $edited[$row.key] = $true
                        } else { $chip = ($chip + $dir + $row.items.Count) % $row.items.Count }
                    } else {
                        if ($dir -eq 2) { $dir = 1 }
                        $ids = @($row.items | ForEach-Object { $_[0] })
                        $i = [array]::IndexOf($ids, $opt[$row.key]); if ($i -lt 0) { $i = 0 }
                        if (-not (Is-Custom $row.key)) { $i = ($i + $dir + $ids.Count) % $ids.Count }   # 從自訂換過來的第一下：停在選項檔原本那個
                        $opt[$row.key] = $ids[$i]
                        $edited[$row.key] = $true
                    }
                }
            } finally {
                # 不管怎麼離開，終端機都要回到正常狀態（游標、顏色），畫面清乾淨給後面的訊息用
                $Host.UI.Write("${CSI}0m${CSI}?25h${CSI}2J${CSI}H")
            }
        }

        $screenDone = $false
        $tuiKeys = Pick '' 'NA_TUI_KEYS'
        $useScreen = [bool]$tuiKeys
        if (-not $useScreen -and -not (Pick '' 'NA_PLAIN')) {
            try {
                $useScreen = [bool]$Host.UI.SupportsVirtualTerminal -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected -and
                             [Console]::WindowWidth -ge 72 -and [Console]::WindowHeight -ge 24
            } catch { $useScreen = $false }
        }
        if ($useScreen) {
            $optBackup = @{}; foreach ($k in @($opt.Keys)) { $optBackup[$k] = $opt[$k] }
            $editedBackup = @{}; foreach ($k in @($edited.Keys)) { $editedBackup[$k] = $edited[$k] }
            try { Show-OptionsScreen $tuiKeys $launchNote.Trim('　'); $screenDone = $true }
            catch {
                # 畫面出了狀況就退回輸入編號的版本，選項回到進來前的樣子，不要帶著改到一半的值往下走
                foreach ($k in @($optBackup.Keys)) { $opt[$k] = $optBackup[$k] }
                $edited.Clear(); foreach ($k in @($editedBackup.Keys)) { $edited[$k] = $editedBackup[$k] }
                Warn "選項畫面開不起來（$($_.Exception.Message)），改用輸入編號的方式。"
            }
        }

        # ════ 輸入編號的版本（終端機不支援上面那個畫面時用）════
        while (-not $screenDone) {
            Write-Host ''
            Write-Host "目前的設定$launchNote" -ForegroundColor Cyan
            $launchNote = ''
            for ($i = 0; $i -lt $rows.Count; $i++) { Write-Host ("  {0}) {1}　{2}" -f ($i + 1), $rows[$i].title, (Show-Value $rows[$i])) }
            # 最常見的「換了主題怎麼沒變」：系統在深色模式＋跟隨系統，看到的一直是 Nat Dark。
            # 小狼毫的對話框只改得到淺色那一格，在這個狀態下換配色同樣看不出來。
            if ($sysDark -and $opt.dark -eq 'auto' -and $darkThemes -notcontains $opt.theme) {
                Write-Host '  ※ 系統現在是深色模式，所以候選窗顯示的是 Nat Dark；第 1 項的主題要等系統切回淺色才看得到。' -ForegroundColor DarkGray
                Write-Host '    想在深色模式也用第 1 項的主題：把第 2 項改成「不跟隨」。' -ForegroundColor DarkGray
            }
            $ans = (Read-Host ("  輸入編號 1-{0} 修改那一項；直接按 Enter 套用" -f $rows.Count)).Trim()
            if (-not $ans) { break }
            $n = 0
            if (-not ([int]::TryParse($ans, [ref]$n) -and $n -ge 1 -and $n -le $rows.Count)) { Write-Host '  請輸入清單上的數字。' -ForegroundColor Yellow; continue }
            $row = $rows[$n - 1]
            $edited[$row.key] = $true
            if ($row.multi) {
                $curLangs = @($opt.langs -split ',' | Where-Object { $_ -and $_ -ne 'none' })
                $sel = Ask-Many $row.ask $row.items $curLangs
                if ($sel.Count) { $opt.langs = ($sel -join ',') } else { $opt.langs = 'none' }
            } else {
                $opt[$row.key] = Ask-One $row.ask $row.items $opt[$row.key]
            }
        }
    }
    # 檢查（參數／環境變數／手改的檔頭都可能給出不認得的值）
    if (-not $themeMap.ContainsKey($opt.theme)) { Die "不認得的主題：$($opt.theme)（可用：matcha light fluent sakura ocean latte dark midnight classic）" }
    if ('auto', 'off' -notcontains $opt.dark) { Die "不認得的深色模式設定：$($opt.dark)（可用：auto off）" }
    if (-not $sizeMap.ContainsKey($opt.size)) { Die "不認得的字級：$($opt.size)（可用：small medium large）" }
    if ('vertical', 'horizontal' -notcontains $opt.layout) { Die "不認得的排列：$($opt.layout)（可用：vertical horizontal）" }
    if ('on', 'off' -notcontains $opt.emoji) { Die "不認得的 emoji 設定：$($opt.emoji)（可用：on off）" }
    if ('on', 'off' -notcontains $opt.paging) { Die "不認得的翻頁提示設定：$($opt.paging)（可用：on off）" }
    if (-not $glossMap.ContainsKey($opt.gloss)) { Die "不認得的釋義語言：$($opt.gloss)（可用：zh en ja）" }
    if ('huninn', 'system' -notcontains $opt.font) { Die "不認得的字型：$($opt.font)（可用：huninn system）" }

    # ── 字型：粉圓體（jf open 粉圓，SIL OFL 授權的開源字型）──
    # 字型的「家族名稱」帶版本號（jf open 粉圓 2.1），所以先看電腦上裝的是哪一版、用它真正的名字；
    # 沒裝才下載。裝在使用者自己的字型資料夾，不需要系統管理員權限。下載失敗就退回系統字型，不中斷安裝。
    $fontFace = 'Microsoft JhengHei:bold, Segoe UI Emoji'; $commentFace = 'Microsoft JhengHei, Segoe UI'
    if ($opt.font -eq 'huninn') {
        function Find-Huninn {
            try {
                Add-Type -AssemblyName System.Drawing
                $fc = New-Object System.Drawing.Text.InstalledFontCollection
                return ($fc.Families | Where-Object { $_.Name -like 'jf open 粉圓*' } | Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty Name)
            } catch { return $null }
        }
        $family = Find-Huninn
        if (-not $family) {
            Step '下載並安裝粉圓體（jf open 粉圓，約 5 MB）'
            try {
                $url = Pick '' 'NA_FONT_URL'
                if (-not $url) { $url = 'https://github.com/justfont/open-huninn-font/releases/download/v2.1/jf-openhuninn-2.1.ttf' }
                $fontDir = Pick '' 'NA_FONT_DIR'    # 測試用：裝到別的資料夾、不寫登錄檔
                $register = -not $fontDir
                if (-not $fontDir) { $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts' }
                New-Item -ItemType Directory -Force $fontDir | Out-Null
                $ttf = Join-Path $fontDir 'jf-openhuninn-2.1.ttf'
                [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
                $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'   # 5.1 的進度條會讓下載慢十倍
                try { Invoke-WebRequest -Uri $url -OutFile $ttf -UseBasicParsing } finally { $ProgressPreference = $old }
                if (-not (Test-Path $ttf) -or (Get-Item $ttf).Length -lt 1000000) { throw '下載到的檔案不完整' }
                if ($register) {
                    New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' -Name 'jf open 粉圓 2.1 (TrueType)' -Value $ttf -PropertyType String -Force | Out-Null
                    # 讓這次登入階段馬上認得新字型（不用登出再登入）
                    $sig = '[DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResourceW(string f); [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint f, uint t, out IntPtr r);'
                    $api = Add-Type -MemberDefinition $sig -Name 'NaFont' -Namespace 'NaPlus' -PassThru
                    [void]$api::AddFontResourceW($ttf)
                    $r = [IntPtr]::Zero; [void]$api::SendMessageTimeout([IntPtr]0xffff, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$r)
                    $family = Find-Huninn
                }
                if (-not $family) { $family = 'jf open 粉圓 2.1' }
                Ok "已安裝 $family"
            } catch {
                Warn "粉圓體安裝失敗（$($_.Exception.Message)），先改用系統字型。之後重跑安裝指令可以再試。"
                $opt.font = 'system'; $family = $null
            }
        }
        if ($family) {
            # 粉圓體只有一種字重，不加 :bold（合成的粗體會糊）。後面接正黑體當後備，粉圓沒有的字才會用到。
            $fontFace = "$family, Microsoft JhengHei, Segoe UI Emoji"
            $commentFace = "$family, Microsoft JhengHei, Segoe UI"
        }
    }
    $langs = @($opt.langs -split '[,\s]+' | Where-Object { $_ -and $_ -ne 'none' })
    foreach ($l in $langs) { if (-not $langSchemas.Contains($l)) { Die "不認得的語言：$l（可用：ja ko en extra none）" } }
    if ($langs.Count) { $opt.langs = ($langs -join ',') } else { $opt.langs = 'none' }

    $horizontal = 'false'; $mac = 'stacked'
    if ($opt.layout -eq 'horizontal') { $horizontal = 'true'; $mac = 'linear' }
    # 翻頁提示關掉：小狼毫的 < > 是把配色裡的兩個翻頁顏色蓋成透明（見 na_weasel.yaml）；Mac 的 lua 看 paging_hint
    $pagingHint = 'true'; $weaselPaging = '{}'
    if ($opt.paging -eq 'off') { $pagingHint = 'false'; $weaselPaging = '{ prevpage_color: "0x00000000", nextpage_color: "0x00000000" }' }
    $emojiNum = 1
    if ($opt.emoji -eq 'off') { $emojiNum = 0 }
    $scheme = $themeMap[$opt.theme]
    # 不跟隨系統深色模式 → theme_dark 留空（~）。不可以寫成跟 theme 同名：那會把深色模式
    # 釘死在這個主題，之後從小狼毫自己的「輸入法設定」換配色，在深色模式下會完全沒反應。
    # 本身就是深色的主題也一樣留空（深色模式直接沿用它）。
    $schemeDark = '~'
    if ($opt.dark -eq 'auto' -and $darkThemes -notcontains $opt.theme) { $schemeDark = 'NatDark' }
    $sz = $sizeMap[$opt.size]

    # 只重寫內容真的變了的檔：RIME 是看檔案時間決定要不要重編的，沒變卻重寫等於白白重編一輪。
    # 不帶 BOM、LF：這些檔是給 librime 讀的。
    $script:optChanged = 0
    function Write-Option([string]$path, [string[]]$lines) {
        $text = ($lines -join "`n") + "`n"
        if ((Test-Path -LiteralPath $path) -and ([IO.File]::ReadAllText($path) -eq $text)) { return }
        [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding $false))
        $script:optChanged++
    }
    # 把對話框寫的那一筆從使用者的 *.custom.yaml 拿掉（只刪那個鍵，其他內容原樣留著）
    function Remove-Override([string]$path, [string]$pattern) {
        $text = [IO.File]::ReadAllText($path)
        $new = ([regex]$pattern).Replace($text, '', 1)
        if ($new -ne $text) {
            [IO.File]::WriteAllText($path, $new, (New-Object Text.UTF8Encoding $false))
            $script:optChanged++
        }
    }
    # 主題：對話框選的是這套的主題 → 上面已經當成這次的值寫進選項檔，那一筆可以拿掉；
    #       選的是別的配色 → 這次有重選主題才拿掉。方案清單：這次有重選語言才拿掉。
    if ($guiTheme -and ($guiThemeKnown -or $edited.theme)) { Remove-Override $weaselUser $reTheme }
    if ($guiSchemas -and $edited.langs) { Remove-Override $defaultUser $reSchema }

    $note = '# ↓ 這行是給安裝腳本讀「上次選了什麼」用的，手動改值時請一起改，或整行刪掉。'
    $macFont = '"PingFangTC-Semibold"'; $macComment = '"PingFangTC-Regular"'
    if ($opt.font -eq 'huninn') { $macFont = '"jf-openhuninn-2.1, PingFangTC-Semibold"'; $macComment = '"jf-openhuninn-2.1, PingFangTC-Regular"' }
    Write-Option $styleFile @(
        "# na_style.custom.yaml — 個人選項：候選窗的長相（由 '/setup 產生，不進版控）",
        "# 想換：輸入法裡打 '/setup；或手動改下面的值後重新部署。各鍵說明見 na_style.yaml。",
        $note,
        "# na-options: theme=$($opt.theme) dark=$($opt.dark) layout=$($opt.layout) size=$($opt.size) font=$($opt.font) paging=$($opt.paging)",
        'patch:',
        "  theme: $scheme",
        "  theme_dark: $schemeDark",
        "  font_point: $($sz[0])",
        "  label_font_point: $($sz[1])",
        "  mac_font_point: $($sz[2])",
        "  mac_label_font_point: $($sz[3])",
        "  font_face: `"$fontFace`"",
        "  comment_font_face: `"$commentFace`"",
        "  mac_font_face: $macFont",
        "  mac_comment_font_face: $macComment",
        "  horizontal: $horizontal",
        "  candidate_list_layout: $mac",
        "  paging_hint: $pagingHint",
        "  weasel_paging: $weaselPaging"
    )
    Write-Option $inputFile @(
        "# na_input.custom.yaml — 個人選項：輸入時的行為（由 '/setup 產生，不進版控）",
        "# 想換：輸入法裡打 '/setup；或手動改下面的值後重新部署。各鍵說明見 na_input.yaml。",
        $note,
        "# na-options: emoji=$($opt.emoji) gloss=$($opt.gloss)",
        'patch:',
        "  emoji: $emojiNum",
        "  gloss: $($glossMap[$opt.gloss])"
    )
    $m = New-Object System.Collections.Generic.List[string]
    $m.Add("# na_menu.custom.yaml — 個人選項：方案選單裡的語言（由 '/setup 產生，不進版控）")
    $m.Add("# 想換：輸入法裡打 '/setup；或手動改下面的清單後重新部署。說明見 na_menu.yaml。")
    $m.Add($note)
    $m.Add("# na-options: langs=$($opt.langs)")
    $m.Add('patch:')
    $m.Add('  schema_list:')
    $m.Add('    - { schema: bopomo_onionplus } # 注音Na+')
    foreach ($l in $langSchemas.Keys) {
        if ($langs -contains $l) { foreach ($sc in $langSchemas[$l]) { $m.Add("    - { schema: $($sc[0]) } # $($sc[1])") } }
    }
    Write-Option $menuFile $m.ToArray()
    if ($script:optChanged) { Step '已寫入選項' } else { Step '選項沒有變動' }
    # 對話框那邊的自訂還在生效的項目，摘要也照實寫（不然會印出一個其實沒在用的值）
    $themeShown = $opt.theme; $langsShown = $opt.langs
    if ($guiTheme -and -not $guiThemeKnown -and -not $edited.theme) { $themeShown = "$guiTheme（小狼毫對話框選的）" }
    if ($guiSchemas -and -not $edited.langs) { $langsShown = "自訂的 $guiSchemas 個方案（小狼毫對話框勾的）" }
    if ($opt.paging -eq 'off' -and $guiTheme -and -not $guiThemeKnown -and -not $edited.theme) {
        Warn "翻頁提示關掉只對這套的主題有效。現在用的「$guiTheme」是在小狼毫對話框選的，它的配色如果有翻頁顏色，< > 還是會出現。"
    }
    Say "    主題 $themeShown｜深色模式 $($opt.dark)｜排列 $($opt.layout)｜字級 $($opt.size)｜字型 $($opt.font)｜翻頁提示 $($opt.paging)｜emoji $($opt.emoji)｜語言 $langsShown｜釋義 $($opt.gloss)"

    # ── [6] 套用檔案＋部署 ────────────────────────────────────────────
    # 交給 repo 裡的 rime-update.ps1：它會把 rime\ 攤平複製到使用者資料夾，並自己判斷要不要
    # 部署、要不要重啟服務（lua 有變才需要重啟）。這裡只補它看不到的事：
    #   第一次安裝          → -Force（整輪部署＋重啟）
    #   只是選項檔變了      → -Deploy（部署就會生效，不必重啟服務）
    #   什麼都沒變          → 不加，rime-update 發現沒事可做就直接結束
    # 以前不管有沒有變都 -Force，所以只是進來看一眼選項也要等上一輪部署加重啟。
    # 另開一個行程並帶 -ExecutionPolicy Bypass：Windows 預設政策不准直接執行 .ps1 檔。
    if ($NoDeploy) { Step '套用檔案（-NoDeploy：不部署、不動輸入法服務）' }
    elseif (-not $ours) { Step '套用檔案、部署並重啟小狼毫（第一次要編譯詞典，約 2～5 分鐘，請等它跑完）' }
    else { Step '套用檔案（有變動才重新部署）' }
    $psExe = (Get-Process -Id $PID).Path
    $upArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $SrcDir 'scripts\rime-update.ps1'),
                '-SkipPull', '-NoPause', '-CloseAfter', '0', '-RimeDir', $RimeDir)
    if (-not $ours) { $upArgs += '-Force' } elseif ($script:optChanged) { $upArgs += '-Deploy' }
    if ($NoDeploy) { $upArgs += '-NoDeploy' }
    & $psExe @upArgs
    if ($LASTEXITCODE -ne 0) { Die '套用／部署沒有成功，請看上面的訊息。' }

    Say ''
    Write-Host '✓ 完成。' -ForegroundColor Green
    if ($ours) {
        # 已經裝過、只是進來改選項：不必再把安裝完的說明整段印一次
        Say "  ‧ 之後想再改：輸入法內打 '/setup 再按空白鍵"
    } else {
        Say '  ‧ 切到小狼毫後按 Ctrl+` 開方案選單；打 ''/h 再按空白鍵可開速查表'
        Say "  ‧ 想重選主題／語言／emoji：輸入法內打 '/setup 再按空白鍵（或再跑一次同一行安裝指令）"
        Say "  ‧ 之後更新：輸入法內打 '/git 再按空白鍵"
        Say "  ‧ 設定來源放在 $SrcDir（更新靠它，請不要刪）"
    }
    Say ''
    # 給 scripts\rime-setup.cmd 看的：成功就讓視窗自己關，失敗才停下來等人看（它用 NA_AUTOCLOSE 告訴這裡）
    $global:NaSetupOk = $true
    if (Pick '' 'NA_AUTOCLOSE') {
        Say '  視窗 2 秒後自動關閉…'
        Start-Sleep -Seconds 2
    }
}

try {
    Install-NaPlus -Theme $Theme -Dark $Dark -Layout $Layout -Size $Size -Font $Font -Paging $Paging -Emoji $Emoji -Langs $Langs -Gloss $Gloss `
        -Yes ([bool]$Yes) -NoDeploy ([bool]$NoDeploy) -Repo $Repo -Branch $Branch -RimeDir $RimeDir
} catch {
    Write-Host ''
    $msg = $_.Exception.Message
    if ($msg -like 'NAPLUS: *') { Write-Host ('✗ ' + $msg.Substring(8)) -ForegroundColor Red }
    else { Write-Host ('✗ 安裝中斷：' + $msg) -ForegroundColor Red; Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray }
    Write-Host ''
}
