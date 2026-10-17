# Windows Terminal + PowerShell 7 配置

一套在 Windows 上实测可用的终端环境配置：Windows Terminal 键位、PowerShell 7 profile、oh-my-posh 主题、zoxide 目录跳转、fzf 模糊补全。

配置不是拼凑的模板，而是从零调试出来的结果，**其中若干处与网上常见写法不同**，原因都记在「设计取舍」一节，改之前建议先看那一节。

## 目录内容

| 文件 | 作用 |
| --- | --- |
| `settings.json` | Windows Terminal 配置。含 7 条自定义键位、4 个 profile、字体与外观 |
| `profile.ps1` | PowerShell 7 profile。含编码设置、PSReadLine、oh-my-posh、Terminal-Icons、PSFzf、zoxide、别名与小工具 |
| `apply.ps1` | 部署脚本。校验 → 备份 → 复制 → 复校，支持 `-WhatIf`，也支持远程一键执行 |

## 适用环境

| 组件 | 实测版本 |
| --- | --- |
| Windows Terminal | 1.24.12741.0（Microsoft Store 版） |
| PowerShell | 7.6.7 |
| PSReadLine | 2.4.5 |
| oh-my-posh | 31.8.0 |
| PSFzf | 2.7.12 |
| fzf | 0.74.5 |
| Terminal-Icons | 0.11.0 |
| zoxide | 0.10.0 |

仅适用于 Windows。`settings.json` 里的 Store 版路径为
`%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`，
若使用免安装版或 Preview 版，路径不同，需自行调整。

## 依赖安装

依赖全部通过 scoop 管理：

```powershell
scoop install git gh 7zip python312 sudo
scoop install Meslo-NF --bucket nerd-fonts
scoop install oh-my-posh fzf zoxide
scoop install psfzf terminal-icons --bucket extras
```

`Meslo-NF` 是 Nerd Font，必须安装，否则 oh-my-posh 与 Terminal-Icons 的图标会显示成方块。字体家族名以 `MesloLGM Nerd Font` 被 `settings.json` 的 `font.face` 引用。

## 部署

### 方式零：一键远程执行（无需克隆）

```powershell
irm https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/windows-terminal-config/apply.ps1 | iex
```

只预演、不写任何文件：

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/windows-terminal-config/apply.ps1))) -WhatIf
```

远程执行时 `$PSScriptRoot` 为空，脚本会自动把 `settings.json` 与 `profile.ps1` 下载到系统临时目录，部署结束后删除，不残留。写入前同样会备份。

可用 `-Ref` 指定分支或标签，用 `-ProfileOnly` / `-TerminalOnly` 单项部署，例如：

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/windows-terminal-config/apply.ps1))) -TerminalOnly
```

### 方式一：脚本

```powershell
pwsh -File .\apply.ps1 -WhatIf     # 先看会做什么
pwsh -File .\apply.ps1             # 实际部署
```

脚本只写两个位置：Windows Terminal 的 `settings.json`，以及 `$PROFILE.CurrentUserCurrentHost`。写入前会把现有文件备份为 `<原文件名>.bak-yyyyMMdd-HHmmss`。

### 方式二：手动

1. `settings.json` 覆盖到上述 LocalState 目录
2. `profile.ps1` 覆盖到 `$PROFILE`（`notepad $PROFILE` 打开的就是它）

### 生效方式

- Windows Terminal：新开窗口或标签页。已打开的窗格不会重绘
- PowerShell：新开窗口，或在现有窗口执行 `reload`（本 profile 内置的别名）

## 键位总表

### Windows Terminal（终端层，最先拦截）

| 按键 | 动作 | 动作 ID |
| --- | --- | --- |
| `Ctrl+T` | 新建标签页 | `Terminal.OpenNewTab` |
| `Ctrl+N` | 新建窗口 | `Terminal.OpenNewWindow` |
| `Ctrl+W` | 关闭窗格（仅剩一个则关标签，最后一个则关窗口） | `Terminal.ClosePane` |
| `Ctrl+C` / `Ctrl+V` | 复制 / 粘贴 | — |
| `Ctrl+Shift+F` | 搜索滚回缓冲区 | `Terminal.FindText` |
| `Alt+Shift+D` | 复制当前窗格并分屏 | `Terminal.DuplicatePaneAuto` |
| `Alt+Shift+=` / `-` | 左右 / 上下分屏 | 默认值 |
| `Alt+方向键` | 窗格间切换焦点 | 默认值 |
| `Alt+Shift+方向键` | 调整窗格尺寸 | 默认值 |
| `Ctrl+,` | 打开设置界面 | 默认值 |

### PowerShell 7（shell 层）

| 按键 | 动作 |
| --- | --- |
| `Tab` | 原生补全菜单（PSReadLine `MenuComplete`） |
| `Ctrl+Alt+J` | fzf 补全：模糊匹配 + 右侧预览 + 逐层钻取 |
| `Ctrl+Alt+T` | fzf 选文件，把路径插入命令行 |
| `Ctrl+R` | fzf 搜索命令历史 |
| `Ctrl+D` | 空行时退出（`DeleteCharOrExit`） |
| `Ctrl+Shift+C` | 有选中则复制，否则取消当前行 |
| `↑` / `↓` | 在历史预测列表（ListView）中选择，`→` 接受 |
| `z <关键字>` / `zi` | zoxide 跳转目录 / 交互式挑选 |

## 设计取舍

下面六处是与常见写法不同的地方，改动前请先理解原因。

### 1. 键位覆盖必须用真实的动作 ID

`settings.json` 用 `keybindings` 数组、按动作 ID 覆盖默认值。**ID 写错不会报错，只会被静默忽略**：

| 想要的动作 | 正确 ID | 常见误写 |
| --- | --- | --- |
| 新建标签页 | `Terminal.OpenNewTab` | `Terminal.NewTab` |
| 新建窗口 | `Terminal.OpenNewWindow` | `Terminal.NewWindow` |
| 关闭窗格 | `Terminal.ClosePane` | 正确 |

排查方法：把终端安装目录里 `defaults.json` 解出来检索，或查官方动作表。写错的表现是「按了没反应」，而不是报错。

### 2. `Tab` 保持原生菜单，fzf 补全另绑一键

两者候选集**完全相同**——`Invoke-FzfTabCompletion` 内部调用的就是原生补全引擎 `CommandCompletion::CompleteInput`，区别只在展示与开销：

- 原生菜单：进程内完成，无额外进程，参数名补全会显示类型说明，1–3 个候选时几乎瞬时
- fzf 版：每次按键启动 fzf 进程，预览再起一个子进程；换来模糊匹配、内容预览、逐层钻取

在候选上万的家目录下，全局替换 `Tab` 会有肉眼可见的延迟。因此按「高频走短路径、低频才付开销」分配：`Tab` 留给原生，fzf 挂 `Ctrl+Alt+J`。

### 3. 不用 `Alt+字母` 作自定义键

实测本机 `Alt` 组合键送不到 PSReadLine：按 `Alt+?` 屏幕只输出 `/`（正常应是 `?`，即 `Shift+/`），说明 `Shift` 被输入法中文状态吃掉、`Alt` 修饰也一并丢失。因此 fzf 补全绑定为 `Ctrl+Alt+J` 而非更顺手的 `Alt+T`；同类的 `Ctrl+Alt+T`（fzf 选文件）一直可用，是佐证。

### 4. zoxide 的初始化必须放在 oh-my-posh 之后

zoxide 靠「接管 `prompt` 函数」记录每次 `cd`，而 `oh-my-posh init` 会重新赋值 `$Function:prompt`。谁在后面初始化，`prompt` 就归谁。顺序颠倒的后果是 database 永远为空，`z` 一直 `no match found`。

profile 第 8 节同时处理了两件事：用 `$global:__zoxide_hooked = 1` 让 zoxide 跳过自带的 prompt 包装（避免 `zoxide add` 把 `$LASTEXITCODE` 冲成 0，导致 oh-my-posh 的失败提示失灵），并只包一层 prompt（用 `__ompPromptBase` 做幂等守卫，防止 `reload` 时层层套娃）。

### 5. PSFzf 的文件选择键从 `Ctrl+T` 改为 `Ctrl+Alt+T`

`Ctrl+T` 已被终端占用为「新建标签页」。终端层的绑定优先于 shell，若不同步让位，PSFzf 的文件选择会被永久吞掉。

### 6. 背景图不要指向桌面

`settings.json` 中 PowerShell profile 的 `backgroundImage` 指向桌面上的某个 png。桌面是最容易被清理的目录，文件一旦被删，终端**静默回退纯色背景**，不报错。建议把图放到 `Pictures\Wallpapers\` 这类稳定位置再引用。

## 已知问题排查

### 键位改了没反应

按顺序查三步：

```powershell
Get-Module PSFzf                                        # 空 = 模块没加载
Get-PSReadLineKeyHandler -Bound | ? Key -eq 'Ctrl+Alt+J' # 空 = 键位没注册
Get-Command Invoke-FzfTabCompletion                     # 空 = 模块未导出
```

常见原因依次是：终端窗口在改配置之前就开着（未重载）、开着「设置」界面被旧状态覆盖、模块未加载。

### fzf 补全「按了没反应」

`Invoke-FzfTabCompletion` 有两个**静默分支**，都不会给任何提示：

- 当前行为空或全空白 → 源码直接 `return $false`
- 候选只有 1 个 → 不弹界面，直接把结果回填进行内

所以测试时务必先输入内容，并选一个必然多候选的目标（例如 `Get-ChildItem C:\`）。

### 背景图消失

`backgroundImage` 路径上的文件不存在了。配置文件本身通常完好，先用 `Test-Path` 确认图片是否还在；若被误删，回收站里可找回。

### 设置界面会覆盖手工修改

Windows Terminal 的「设置」界面在保存时，会用内存中的状态整体重写 `settings.json`。外部编辑该文件时，务必先关闭设置界面，否则改动会被回退。

### 状态可能是假阴性

若在非交互环境（脚本、CI、外部工具调用）里检查键位或模块，可能因为环境以 `-NoProfile` 启动、或 `PSModulePath` 未包含 scoop 模块目录而查不到结果。此时先执行：

```powershell
$env:PSModulePath = "$HOME\scoop\modules;$env:PSModulePath"
```

## 回滚

`apply.ps1` 每次写入前都会生成带时间戳的备份，直接覆盖回去即可：

```powershell
Copy-Item "$PROFILE.bak-20261017-1108" $PROFILE -Force
```

Windows Terminal 同理，备份在同目录下。

## 维护

```powershell
scoop status              # 查看可升级项
scoop update *            # 全部升级
oh-my-posh cache clear    # oh-my-posh 升级后清缓存，否则主题可能不生效
```

Windows Terminal 大版本升级后，建议核对一次 `defaults.json` 中的动作 ID 是否变动，再确认自定义键位仍然生效。

## 复用说明

`settings.json` 与 `profile.ps1` 中存在硬编码的用户路径（如 `C:\Users\zuo`、桌面背景图）。复用到其他机器时需要替换：

- `settings.json`：各 profile 的 `startingDirectory`、`backgroundImage`
- `profile.ps1`：无硬编码绝对路径，主题目录通过 `%USERPROFILE%` 推导，可直接复用
