# ============================================================
#  PowerShell 7.6 Profile（已实测验证版）
#  目标位置：C:\Users\zuo\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
#           ↑ 就是 $PROFILE 指向的文件，用 `notepad $PROFILE` 可直接编辑
#  原则：本文件只做「配置」，不做任何「安装」。
#
#  2026-10-17 变更：移除 oh-my-posh 提示符主题（含主题预览 / 切换函数）。
#  提示符回归 shell 原生，每渲染一次省一次 omp 子进程调用；
#  原第 8 节为「与 oh-my-posh 共存」而写的 prompt 包装层一并删除。
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
    # 若你更习惯 bash 的「↑ 按前缀翻历史」，注释掉上面 ListView 那行，
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

# 4.2 fzf 集成：Ctrl+r 模糊搜历史、Ctrl+Alt+t 选文件、Ctrl+Alt+j 补全
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


# ---------- 7. zoxide 目录跳转 ----------
# 旧版这里必须手写 prompt 包装层，因为 oh-my-posh 会抢走 $Function:prompt。
# 主题移除后提示符回归 shell 原生，直接用 zoxide 自带的包装即可：
# 它只是把原来的 prompt 套一层再记账，纯 .NET 调用，不起子进程。
if ($isInteractive -and (Get-Command zoxide -ErrorAction Ignore)) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
