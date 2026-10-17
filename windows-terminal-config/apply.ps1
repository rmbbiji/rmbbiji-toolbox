#Requires -Version 7.0
<#
.SYNOPSIS
    部署 Windows Terminal 与 PowerShell 7 配置到当前用户。

.DESCRIPTION
    两种用法都支持：

    1) 一键远程执行（无需克隆仓库）
       irm https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/windows-terminal-config/apply.ps1 | iex

    2) 本地执行（配置与脚本同目录）
       pwsh -File .\apply.ps1
       pwsh -File .\apply.ps1 -WhatIf

    远程执行时 $PSScriptRoot 为空，脚本会自行从仓库下载 settings.json 与 profile.ps1 到临时目录，
    部署完成后清理，不残留文件。

    流程：校验源配置 -> 备份目标文件 -> 复制 -> 复校落地文件。
    只写两个位置，不触碰其他任何文件：
      %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
      <用户文档目录>\PowerShell\<主机名>_profile.ps1

.PARAMETER SourceRoot
    配置源目录。默认使用脚本所在目录；远程执行时自动回落到仓库下载。

.PARAMETER Ref
    远程下载使用的分支、标签或提交，默认 main。

.PARAMETER SkipBackup
    跳过备份。不建议使用。

.PARAMETER ProfileOnly
    只部署 PowerShell 配置，不动 Windows Terminal 设置。

.PARAMETER TerminalOnly
    只部署 Windows Terminal 设置，不动 PowerShell 配置。

.EXAMPLE
    iwr https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/windows-terminal-config/apply.ps1 | iex
    一键部署两份配置，写入前自动备份。

.EXAMPLE
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/windows-terminal-config/apply.ps1))) -WhatIf
    远程执行但只预演，不写任何文件。
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [string]$SourceRoot,
    [string]$Ref = 'main',
    [switch]$SkipBackup,
    [switch]$ProfileOnly,
    [switch]$TerminalOnly
)

$ErrorActionPreference = 'Stop'

# $PSCmdlet 在 irm | iex 场景下可能为 $null，先捕获，供 ShouldProcess 使用
$script:CallerCmdlet = $PSCmdlet

function Confirm-Step {
    param([string]$Target, [string]$Action)
    if ($null -ne $script:CallerCmdlet) {
        return $script:CallerCmdlet.ShouldProcess($Target, $Action)
    }
    return $true
}

function Write-Section {
    param([string]$Text)
    Write-Host ''
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host '  ----------------------------------------' -ForegroundColor DarkGray
}

function Write-Item {
    param([string]$Label, [string]$Value, [ConsoleColor]$Color = [ConsoleColor]::Gray)
    Write-Host ("    {0,-6}{1}" -f $Label, $Value) -ForegroundColor $Color
}

function Resolve-SourceRoot {
    param([string]$Explicit, [string]$LocalRoot, [string[]]$Files)

    if (-not [string]::IsNullOrWhiteSpace($Explicit)) {
        if (-not (Test-Path -LiteralPath $Explicit)) {
            throw "指定的 -SourceRoot 不存在：$Explicit"
        }
        Write-Item '来源' $Explicit
        return @{ Path = $Explicit; Temporary = $false }
    }

    if (-not [string]::IsNullOrWhiteSpace($LocalRoot) -and (Test-Path -LiteralPath (Join-Path $LocalRoot 'settings.json'))) {
        Write-Item '来源' "$LocalRoot（本地）"
        return @{ Path = $LocalRoot; Temporary = $false }
    }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('rmbbiji-terminal-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    # 临时目录与下载始终执行（仅涉及系统临时区，且结束时清理），否则 -WhatIf 时无法完成校验
    New-Item -ItemType Directory -Path $tmp -Force -WhatIf:$false | Out-Null
    Write-Item '来源' "仓库 $Ref 分支（临时目录下载）"
    foreach ($f in $Files) {
        $url = "$script:RepoRaw/$f"
        Write-Item '下载' $url ([ConsoleColor]::DarkGray)
        Invoke-WebRequest -Uri $url -OutFile (Join-Path $tmp $f) -UseBasicParsing
    }
    return @{ Path = $tmp; Temporary = $true }
}

function Test-JsonFile {
    param([string]$Path)
    try {
        $null = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
    }
    catch {
        throw "JSON 解析失败：$Path`n$($_.Exception.Message)"
    }
}

function Test-ScriptSyntax {
    param([string]$Path)
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        $detail = ($errors | ForEach-Object { "  行 $($_.Extent.StartLineNumber): $($_.Message)" }) -join "`n"
        throw "脚本语法错误：$Path`n$detail"
    }
}

# ------------------------------------------------------------------ 主流程

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "需要 PowerShell 7 或更高版本，当前为 $($PSVersionTable.PSVersion)。"
}
if ($ProfileOnly -and $TerminalOnly) {
    throw 'ProfileOnly 与 TerminalOnly 不能同时指定。'
}

$script:RepoRaw = "https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/$Ref/windows-terminal-config"
$profileName = Split-Path -Leaf $PROFILE.CurrentUserCurrentHost

$plan = [ordered]@{}
if (-not $TerminalOnly) {
    $plan[$profileName] = $PROFILE.CurrentUserCurrentHost
}
if (-not $ProfileOnly) {
    $plan['settings.json'] = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
}

$sourceNameFor = @{ $profileName = 'profile.ps1' }

Write-Section 'Windows Terminal + PowerShell 7 配置部署'

$resolved = Resolve-SourceRoot -Explicit $SourceRoot -LocalRoot $PSScriptRoot -Files @('settings.json', 'profile.ps1')
$srcRoot = $resolved.Path

try {
    foreach ($name in $plan.Keys) {
        $fileName = if ($sourceNameFor.ContainsKey($name)) { $sourceNameFor[$name] } else { $name }
        $src = Join-Path $srcRoot $fileName
        $dst = $plan[$name]

        Write-Host ''
        Write-Host "  [$name]" -ForegroundColor Yellow
        Write-Item '源' $src
        Write-Item '目标' $dst

        if (-not (Test-Path -LiteralPath $src)) {
            throw "源文件不存在：$src"
        }

        if ($name -eq 'settings.json') {
            Test-JsonFile -Path $src
            Write-Item '校验' 'JSON 可解析' ([ConsoleColor]::DarkGreen)
        }
        else {
            Test-ScriptSyntax -Path $src
            Write-Item '校验' '语法通过' ([ConsoleColor]::DarkGreen)
        }

        if (-not $SkipBackup -and (Test-Path -LiteralPath $dst)) {
            $bak = "$dst.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            if (Confirm-Step -Target $bak -Action '备份现有文件') {
                Copy-Item -LiteralPath $dst -Destination $bak -Force
                Write-Item '备份' $bak ([ConsoleColor]::DarkGray)
            }
        }

        if (Confirm-Step -Target $dst -Action '写入配置文件') {
            $parent = Split-Path -Parent $dst
            if (-not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            Copy-Item -LiteralPath $src -Destination $dst -Force
            Write-Item '状态' '已写入' ([ConsoleColor]::Green)
        }
    }
}
finally {
    if ($resolved.Temporary -and (Test-Path -LiteralPath $srcRoot)) {
        # 用 .NET 删除，避免受 $WhatIfPreference 影响而留下临时目录
        try { [System.IO.Directory]::Delete($srcRoot, $true) } catch { }
    }
}

Write-Section '完成'
Write-Host '    - Windows Terminal：新开窗口或标签页生效（已开的窗格不会重绘）'
Write-Host '    - PowerShell：新开窗口，或在现有窗口执行  reload'
Write-Host '    - 若键位异常，先确认没有开着"设置"界面（它会用内存中的旧状态覆盖文件）'
Write-Host ''
