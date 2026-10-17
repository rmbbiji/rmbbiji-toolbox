#Requires -Version 7.0
<#
.SYNOPSIS
    部署本目录中的 Windows Terminal 与 PowerShell 7 配置到当前用户。

.DESCRIPTION
    做四件事，任一环节失败即中止，不会留下半成品：
      1. 校验源配置（settings.json 能否解析、profile.ps1 语法是否合法）
      2. 备份目标位置现有的同名文件（追加时间戳后缀，不覆盖旧备份）
      3. 复制 settings.json 与 profile.ps1 到目标位置
      4. 再次校验落地文件

    脚本只写两个位置，不触碰其他任何文件：
      %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
      <用户文档目录>\PowerShell\<主机名>_profile.ps1

.PARAMETER SkipBackup
    跳过备份。不建议使用，仅在目标文件不存在或你已自行备份时使用。

.PARAMETER ProfileOnly
    只部署 PowerShell 配置，不动 Windows Terminal 设置。

.PARAMETER TerminalOnly
    只部署 Windows Terminal 设置，不动 PowerShell 配置。

.EXAMPLE
    pwsh -File .\apply.ps1
    按默认流程部署两份配置并自动备份。

.EXAMPLE
    pwsh -File .\apply.ps1 -WhatIf
    只显示将要发生的操作，不实际写入。
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [switch]$SkipBackup,
    [switch]$ProfileOnly,
    [switch]$TerminalOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($ProfileOnly -and $TerminalOnly) {
    throw 'ProfileOnly 与 TerminalOnly 不能同时指定。'
}

$sourceRoot = $PSScriptRoot

$targets = [ordered]@{}
if (-not $ProfileOnly) {
    $targets['settings.json'] = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
}
if (-not $TerminalOnly) {
    $targets[(Split-Path -Leaf $PROFILE.CurrentUserCurrentHost)] = $PROFILE.CurrentUserCurrentHost
}

$sourceFor = @{
    'settings.json' = Join-Path $sourceRoot 'settings.json'
    (Split-Path -Leaf $PROFILE.CurrentUserCurrentHost) = Join-Path $sourceRoot 'profile.ps1'
}

function Test-JsonFile {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $null = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
    }
    catch {
        throw "JSON 解析失败：$Path`n$($_.Exception.Message)"
    }
}

function Test-ScriptSyntax {
    param([Parameter(Mandatory)][string]$Path)
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        $detail = ($errors | ForEach-Object { "  行 $($_.Extent.StartLineNumber): $($_.Message)" }) -join "`n"
        throw "脚本语法错误：$Path`n$detail"
    }
}

function Get-BackupPath {
    param([Parameter(Mandatory)][string]$Path)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    return "$Path.bak-$stamp"
}

Write-Host ''
Write-Host '  Windows Terminal + PowerShell 7 配置部署' -ForegroundColor Cyan
Write-Host '  ----------------------------------------' -ForegroundColor DarkGray

foreach ($name in $targets.Keys) {
    $src = $sourceFor[$name]
    $dst = $targets[$name]

    Write-Host ''
    Write-Host "  [$name]" -ForegroundColor Yellow
    Write-Host "    源:   $src"
    Write-Host "    目标: $dst"

    if (-not (Test-Path -LiteralPath $src)) {
        throw "源文件不存在：$src"
    }

    if ($name -eq 'settings.json') {
        Test-JsonFile -Path $src
        Write-Host '    校验: JSON 可解析' -ForegroundColor DarkGreen
    }
    else {
        Test-ScriptSyntax -Path $src
        Write-Host '    校验: 语法通过' -ForegroundColor DarkGreen
    }

    if (-not $SkipBackup -and (Test-Path -LiteralPath $dst)) {
        $bak = Get-BackupPath -Path $dst
        if ($PSCmdlet.ShouldProcess($bak, '备份现有文件')) {
            Copy-Item -LiteralPath $dst -Destination $bak -Force
            Write-Host "    备份: $bak" -ForegroundColor DarkGray
        }
    }

    if ($PSCmdlet.ShouldProcess($dst, '写入配置文件')) {
        $parent = Split-Path -Parent $dst
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Copy-Item -LiteralPath $src -Destination $dst -Force
        Write-Host '    状态: 已写入' -ForegroundColor Green
    }
}

Write-Host ''
Write-Host '  完成。后续操作：' -ForegroundColor Cyan
Write-Host '    - Windows Terminal：新开一个窗口或标签页即生效（已开的窗格不会重绘）'
Write-Host '    - PowerShell：新开窗口，或在现有窗口执行  reload'
Write-Host '    - 若键位异常，先确认没有开着"设置"界面（它会用内存中的旧状态覆盖文件）'
Write-Host ''
