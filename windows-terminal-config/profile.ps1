# ============================================================
#  PowerShell 7.6 Profile（已实测验证版）
#  目标位置：C:\Users\zuo\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
#           ↑ 就是 $PROFILE 指向的文件，用 `notepad $PROFILE` 可直接编辑
#  原则：本文件只做「配置」，不做任何「安装」。
#        安装动作只执行一次，见《PowerShell7.6-最终配置方案.md》
# ============================================================


# ---------- 1. 编码：输出 / 管道 / 重定向统一 UTF-8 ----------
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$PSDefaultParameterValues['Out-File:Encoding']    = 'utf8'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'
$PSDefaultParameterValues['Export-Csv:Encoding']  = 'utf8'

# 让表格自动按内容宽度排版（大结果集会变慢，觉得慢就注释掉这一行）
$PSDefaultParameterValues['Format-Table:AutoSize'] = $true


# ---------- 2. scoop 模块目录兜底 ----------
# scoop 已把 ~\scoop\modules 写进「用户环境变量 PSModulePath」，
# 新开的窗口本来就能看到。这里只兜底「安装前就开着的旧窗口」。
$scoopModules = "$env:USERPROFILE\scoop\modules"
if ((Test-Path $scoopModules) -and (($env:PSModulePath -split ';') -notcontains $scoopModules)) {
    $env:PSModulePath = "$scoopModules;$env:PSModulePath"
}


# ---------- 3. PSReadLine（只在真正的交互终端里配置）----------
# 判断条件避免在「脚本 / 重定向 / CI」场景下产生一堆无害但难看的报错
$isInteractive = $false
try {
    $isInteractive = (-not [Console]::IsOutputRedirected) -and ($Host.Name -eq 'ConsoleHost')
} catch { $isInteractive = $false }

if ($isInteractive -and (Get-Command Set-PSReadLineOption -ErrorAction Ignore)) {

    Set-PSReadLineOption -BellStyle None                       # 关掉补全失败时的响铃
    Set-PSReadLineOption -EditMode Windows                     # Windows 键位习惯
    Set-PSReadLineOption -HistoryNoDuplicates                  # 开关参数：只能写参数名，不能接 $true
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd        # 同样不能接 $true
    Set-PSReadLineOption -MaximumHistoryCount 10000            # 显式约定，不依赖默认值
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin    # 历史 + 插件预测
    Set-PSReadLineOption -PredictionViewStyle ListView         # 下拉列表式建议；F2 可在 Inline/List 间切换
    Set-PSReadLineOption -Colors @{ InlinePrediction = "`e[38;5;244m" }

    # --- 键位 ---
    Set-PSReadLineKeyHandler -Key Tab          -Function MenuComplete            # Tab 出补全菜单
    Set-PSReadLineKeyHandler -Key Ctrl+d       -Function DeleteCharOrExit       # 空行时 Ctrl+d 退出
    Set-PSReadLineKeyHandler -Key Ctrl+Shift+c -Function CopyOrCancelLine       # 有选中则复制，否则取消当前行

    # 注意：ListView 模式下 ↑↓ 用于在候选列表里上下选择，
    # 因此「↑↓ = 按前缀搜历史」与 ListView 互斥，二者只能留一个。
    # 若你更习惯 bash 的「↑ 按前缀翻历史」，注释掉上面第 ... 行的 ListView 那行，
    # 并取消下面两行的注释：
    # Set-PSReadLineOption -PredictionViewStyle InlineView
    # Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    # Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}


# ---------- 4. 交互增强模块（全部带守卫，没装也不报错）----------
function Test-ModuleReady {
    param([Parameter(Mandatory)][string]$Name)
    [bool](Get-Module -ListAvailable -Name $Name -ErrorAction Ignore)
}

# 4.1 文件/目录图标 —— 必须配 Nerd Font，否则图标显示成方块
if (Test-ModuleReady Terminal-Icons) {
    Import-Module Terminal-Icons -ErrorAction Ignore
}

# 4.2 fzf 集成：Ctrl+r 模糊搜历史、Ctrl+Alt+t 选文件、Ctrl+Alt+f 等
#     注：Ctrl+t 已让给 Windows Terminal 的「新建标签页」，因此文件选择改为 Ctrl+Alt+t
if (Test-ModuleReady PSFzf) {
    Import-Module PSFzf -ErrorAction Ignore
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+Alt+t' `
                    -PSReadlineChordReverseHistory 'Ctrl+r' `
                    -ErrorAction Ignore

    # Ctrl+Alt+J：fzf 版 Tab 补全（与第 3 节里 Tab=MenuComplete 并存，互不覆盖）
    #   原理：读取 PSReadLine 当前缓冲区，交给 PowerShell 补全引擎 CompleteInput，
    #         再把候选列表送进 fzf 挑选。候选集与原生 Tab 完全相同，差别只在交互：
    #         fzf 支持模糊匹配、右侧预览、按 \ 逐层钻取目录。
    #   代价：每次按键起一个 fzf 进程（预览再起一个 pwsh -NoProfile 子进程），
    #         在家目录这类上万文件的路径下有明显延迟，所以不作全局替换。
    #   为什么不用 Alt+t：本机 Alt 组合键送不到 PSReadLine（实测按 Alt+? 只输出 /，
    #         说明 Shift 与 Alt 都被输入法/键盘层吃掉），Ctrl+Alt 系不受影响。
    if ($isInteractive -and (Get-Command Set-PSReadLineKeyHandler -ErrorAction Ignore)) {
        Set-PSReadLineKeyHandler -Key Ctrl+Alt+J -ScriptBlock { Invoke-FzfTabCompletion }
    }
}

# 4.3 插件式补全预测（PSGallery 上的真实包名是 CompletionPredictor）
if (Test-ModuleReady CompletionPredictor) {
    Import-Module CompletionPredictor -ErrorAction Ignore
}

# 4.4 zoxide —— 初始化代码在第 8 节，不能挪到这里
#     原因：zoxide 靠「接管 prompt 函数」记录你 cd 过的目录，
#     而第 7 节 oh-my-posh init 会重新定义 prompt，把它覆盖掉。
#     放在这里 = 钩子失效 = 数据库永远是空的 = z / zi 一直 "no match found"。


# ---------- 5. 命令别名 / 小工具 ----------

# PS7 的 Windows 版没有 which；用 Ignore 而非 SilentlyContinue，避免污染 $Error
function which { Get-Command @args -ErrorAction Ignore }

# 目录上跳
function ..   { Set-Location .. }
function ...  { Set-Location ../.. }
function .... { Set-Location ../../.. }

# 新建目录并进入
function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}

# 常用别名
Set-Alias -Name open -Value Invoke-Item          # open . / open 某文件
function ll { Get-ChildItem -Force @args }       # 含隐藏项
function la { Get-ChildItem -Force @args }

# 改文件时间戳 / 新建空文件
function Touch {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path $Path) { (Get-Item $Path).LastWriteTime = Get-Date }
    else { New-Item -Path $Path -ItemType File -Force | Out-Null }
}

# ---------- 6. Profile 自身维护 ----------
# 本文件就是 $PROFILE（C:\Users\zuo\Documents\PowerShell\Microsoft.PowerShell_profile.ps1）
# 所以 `notepad $PROFILE` 打开的就是这里，直接改即可
function Edit-Profile   { notepad $PROFILE }
function Update-Profile { . $PROFILE; 'profile reloaded' }
Set-Alias -Name reload -Value Update-Profile

$ErrorView = 'ConciseView'   # 7.x 已是默认，显式写出来便于以后对照


# ---------- 7. 提示符主题 oh-my-posh ----------
# 字体已确认安装：家族名 MesloLGM Nerd Font（取自 TTF 的 name 表，非猜测）
#
# ★★★ 换主题就在下面这一行改 ★★★
#     只写主题名，不要带 .omp.json 后缀，也不要带引号外的空格
#     改完必须「新开一个窗口」才生效（同窗口有缓存，见文件末尾说明）
$OmpThemeName = 'M365Princess'

# 只在交互终端里启用；脚本 / 重定向场景不加载，省掉每次约 50-100ms 的启动开销
if ($isInteractive -and (Get-Command oh-my-posh -ErrorAction Ignore)) {

    $ompDir = if ($env:POSH_THEMES_PATH -and (Test-Path $env:POSH_THEMES_PATH)) {
        $env:POSH_THEMES_PATH
    } else {
        "$env:USERPROFILE\scoop\apps\oh-my-posh\current\themes"
    }

    $ompThemeFile = Join-Path $ompDir "$OmpThemeName.omp.json"

    if (Test-Path $ompThemeFile) {
        oh-my-posh init pwsh --config $ompThemeFile | Invoke-Expression
    }
    else {
        Write-Host "oh-my-posh 主题不存在：$ompThemeFile" -ForegroundColor Red
        Write-Host "用 Get-PoshThemes 查看全部可用主题" -ForegroundColor DarkGray
    }
}


# ---------- 8. zoxide 目录跳转（位置不能挪，必须在 oh-my-posh 之后）----------
# 为什么必须放在这里：zoxide 的 PowerShell 集成是靠「接管 prompt 函数」来记录每一次 cd 的
#     function global:prompt { & $__zoxide_prompt_old; $null = __zoxide_hook }
# 而 oh-my-posh init 会重新赋值 $Function:prompt（见 init.ps1 里的 $Function:prompt = $promptFunction）。
# 谁在后面初始化，prompt 就归谁。所以这段原先放在第 4 节（OMP 之前）时，
# 钩子被 OMP 覆盖 → 数据库永远是空的 → `z co` / `z code` 一直 "no match found"
# （实测：db.zo 12 字节、`zoxide query --list` 无输出）。
if ($isInteractive -and (Get-Command zoxide -ErrorAction Ignore)) {

    # 先设这个标记，让 zoxide init 跳过它自带的 prompt 包装。
    # 原因：它的包装只负责调 __zoxide_hook，不还原 $LASTEXITCODE；
    # 而 `zoxide add` 是外部程序，会把上一条命令的退出码冲成 0，
    # 导致 oh-my-posh 的「上一条命令失败」提示失灵（实测：7 变 0）。
    $global:__zoxide_hooked = 1

    # 这一步只定义 __zoxide_hook / __zoxide_z / __zoxide_zi 和 z / zi 别名，不碰 prompt
    Invoke-Expression (& { (zoxide init powershell | Out-String) })

    # 只包一次：reload 时 $function:prompt 已经是下面这层包装，
    # 重复捕获会层层套娃，所以用 __ompPromptBase 是否存在做幂等守卫
    if (-not (Get-Variable -Name __ompPromptBase -Scope Global -ErrorAction Ignore)) {

        $global:__ompPromptBase = $function:prompt      # oh-my-posh 的 prompt 原件

        function global:prompt {
            $ompLastExitCode = $global:LASTEXITCODE     # 记下真实退出码
            & $global:__ompPromptBase                   # 先渲染（实测 $? 不受包装影响，OMP 仍能判断成功/失败）
            $null = __zoxide_hook                       # 再记录当前目录（只在目录变化时才真正写库）
            $global:LASTEXITCODE = $ompLastExitCode     # 还原，别污染主题的失败提示
        }
    }
}


# ---------- 9. 主题预览（旧版 Get-PoshThemes 的替代实现）----------
# 旧版 oh-my-posh 自带 Get-PoshThemes，31.x 已移除（实测子命令里没有 theme 相关项）。
# 这里补一个等价命令，用法：
#   Get-PoshThemes               列出全部主题名
#   Get-PoshThemes agnoster      按关键字筛选
#   Get-PoshThemes -Preview      逐个渲染预览（约 5-10 秒）
#   Get-PoshThemes agnoster -Preview
function Get-PoshThemes {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Filter = '*',
        [switch]$Preview
    )

    $root = $env:POSH_THEMES_PATH
    if (-not $root -or -not (Test-Path $root)) {
        $root = "$env:USERPROFILE\scoop\apps\oh-my-posh\current\themes"
    }

    # 关键字不含通配符时按「包含」匹配，含通配符时按原样匹配
    $pattern = if ($Filter -match '[\*\?\[]') { $Filter } else { "*$Filter*" }

    $themes = Get-ChildItem -Path $root -Filter '*.omp.json' -ErrorAction Ignore |
              Sort-Object Name |
              Where-Object { (($_.Name -replace '\.omp\.json$', '')) -like $pattern }

    if (-not $themes) {
        Write-Warning "没有匹配 '$Filter' 的主题"
        return
    }

    if (-not $Preview) {
        return $themes | ForEach-Object { $_.Name -replace '\.omp\.json$', '' }
    }

    # 关键：oh-my-posh 有「会话级缓存」，文件为 pwsh.<POSH_SESSION_ID>.omp.cache。
    # 该缓存一旦存在，--config 参数会被忽略，所有主题都会渲染成当前正在用的那个。
    # 实测：保留 POSH_SESSION_ID 时 atomic / agnoster 输出完全相同（都是 245 字符）；
    #       临时摘掉后三者分别恢复为 630 / 245 / 429 字符。
    # 所以预览期间必须把会话 ID 摘掉，用完再恢复。
    $savedSessionId = $env:POSH_SESSION_ID
    Remove-Item Env:\POSH_SESSION_ID -ErrorAction Ignore

    try {
        foreach ($t in $themes) {
            Write-Host ''
            Write-Host ('  ▸ ' + ($t.Name -replace '\.omp\.json$', '')) -ForegroundColor DarkCyan
            $line = (oh-my-posh print primary --config $t.FullName --shell pwsh 2>$null) -join ''
            Write-Host ('    ' + $line)
        }
    }
    finally {
        if ($savedSessionId) { $env:POSH_SESSION_ID = $savedSessionId }
    }
}


# ---------- 10. 切换主题（立即生效 + 写入 Profile）----------
# 用法：
#   Set-OmpTheme atomic          切到 atomic，本窗口立刻变，并写进 Profile
#   Set-OmpTheme atom            支持模糊匹配，唯一命中就切换
#   Set-OmpTheme                 不带参数：显示当前主题 + 常用备选
#
# 原理（实测确认，两步缺一不可）：
#   1) 改 $env:POSH_CONFIG 指向新主题
#   2) oh-my-posh cache clear
# 只做第 1 步不生效 —— 因为渲染结果被缓存文件固定住了，改配置不会让它失效。
function Set-OmpTheme {
    [CmdletBinding()]
    param([Parameter(Position = 0)][string]$Name)

    $root = $env:POSH_THEMES_PATH
    if (-not $root -or -not (Test-Path $root)) {
        $root = "$env:USERPROFILE\scoop\apps\oh-my-posh\current\themes"
    }

    # 当前主题名：POSH_CONFIG 是完整路径，取出文件名再去后缀
    $current = if ($env:POSH_CONFIG) {
        [System.IO.Path]::GetFileName($env:POSH_CONFIG) -replace '\.omp\.json$', ''
    } else { '(未加载)' }

    if (-not $Name) {
        Write-Host ''
        Write-Host "  当前主题：$current" -ForegroundColor Green
        Write-Host '  用法：Set-OmpTheme <主题名>    如 Set-OmpTheme atomic' -ForegroundColor DarkGray
        Write-Host '  预览：Get-PoshThemes -Preview' -ForegroundColor DarkGray
        Write-Host ''
        return
    }

    $Name = $Name -replace '\.omp\.json$', ''
    $file = Join-Path $root "$Name.omp.json"

    # 精确命中失败时按关键字模糊找；只有一个候选就自动用它
    if (-not (Test-Path $file)) {
        $hits = Get-PoshThemes "*$Name*" -ErrorAction Ignore
        if (@($hits).Count -eq 1) {
            $Name = $hits
            $file = Join-Path $root "$Name.omp.json"
        }
        elseif (@($hits).Count -gt 1) {
            Write-Host "「$Name」匹配到多个主题，请写得更具体：" -ForegroundColor Yellow
            $hits | ForEach-Object { Write-Host "    $_" }
            return
        }
        else {
            Write-Host "找不到主题：$Name" -ForegroundColor Red
            Write-Host '用 Get-PoshThemes 查看全部可用主题' -ForegroundColor DarkGray
            return
        }
    }

    # 1) 立即生效
    $env:POSH_CONFIG = $file
    oh-my-posh cache clear 2>&1 | Out-Null

    if (Get-Command Invoke-PoshPromptRepaint -ErrorAction Ignore) {
        Invoke-PoshPromptRepaint
    }

    # 2) 持久化：改写 Profile 里的 $OmpThemeName 那一行
    $prof = $PROFILE
    if (Test-Path $prof) {
        $raw = Get-Content $prof -Raw
        $pattern = '(?m)^\s*\$OmpThemeName\s*=\s*''[^'']*'''
        if ($raw -match $pattern) {
            $raw = [regex]::Replace($raw, $pattern, "`$OmpThemeName = '$Name'")
            Set-Content -Path $prof -Value $raw -Encoding utf8 -NoNewline
            Write-Host "主题已切换：$Name（已写入 Profile，下个窗口仍生效）" -ForegroundColor Green
        }
        else {
            Write-Host "主题已切换：$Name（本窗口生效；Profile 里没找到 `$OmpThemeName 定义，未持久化）" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "主题已切换：$Name（仅本窗口）" -ForegroundColor Yellow
    }
}

