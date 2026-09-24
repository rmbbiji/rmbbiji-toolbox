# rmbbiji 工具配置

这个仓库放了一些个人常用的终端配置、代理规则和维护脚本，主要用于快速初始化 shell 环境、更新快捷脚本、配置 Vim，以及清理本地 Codex 聊天记录。

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `.vimrc` | 精简版 Vim 终端编辑配置，只保留 15 条常用配置：UTF-8 编码、文件类型缩进、语法高亮、行号、鼠标、退格、缩进和搜索增强。 |
| `Crypto.list` | 加密货币和交易相关站点的代理/分流规则列表，包含 futu、Binance、Bybit、Gate、HTX、Hyperliquid、KuCoin、MEXC、OKX、MetaMask、WalletConnect、Web3 等域名关键字、域名后缀、IP-CIDR 和 IP-ASN 规则。适合放进支持 `DOMAIN-SUFFIX`、`DOMAIN-KEYWORD`、`IP-CIDR`、`IP-ASN` 规则格式的代理工具中使用。 |
| `setup_zsh_tools_debian.sh` | Debian / Ubuntu 环境下一次安装 zsh、oh-my-zsh、Starship、`eza`、`bat`、`fd-find`、`fzf`、`zoxide` 和 Nerd Font，并安装/更新 `zsh-autosuggestions`、`zsh-syntax-highlighting`。脚本会备份已有 `.zshrc` 和 Starship 配置，写入 Catppuccin Powerline 双行提示符，以及 `ls` / `ll` / `la` / `tree` / `cat` / `v` / `fd` / `zoxide` 相关配置，其中 `cat` 会直接映射到 `bat`，并为 `bat` 设置兼容较旧 Debian 版本的默认主题，然后尝试切换当前用户默认 shell 为 zsh。`fzf` 使用官方 git 安装脚本，自动启用 zsh 的补全和快捷键。 |
| `install_rmbbiji_github_rsa_key.sh` | 在远程服务器上拉取 `https://github.com/rmbbiji.keys`，只提取其中的 `ssh-rsa` 公钥，并写入当前用户的 `~/.ssh/authorized_keys`。重复执行不会重复追加。适合先给服务器配置 `rmbbiji` 的登录公钥。 |
| `update_short_cuts.sh` | 更新 `short_cuts` 仓库。脚本会先删除当前目录下已有的 `short_cuts` 目录，然后通过 SSH 克隆 `git@rmbbiji:rain-strom/short_cuts.git`，给 `short_cuts/expand/get_running_python.sh` 添加执行权限并安装依赖，最后停止并重启 `/root/short_cuts/web/server.py`（端口 `4188`）。运行前需要确认当前目录正确，并且本机已配置好对应 SSH 权限和 `rmbbiji` Git 主机别名。 |
| `update_short_cuts_gitee.sh` | 从 Gitee 的 `rmbbiji/short_cuts` 更新仓库，适合 GitHub 的 `rmbbiji` 别名不可用、但已在本机配置好 Gitee SSH 权限的场景。与 `update_short_cuts.sh` 的区别在于：① **探测方式**——用 `git ls-remote` 直接探测 Gitee 仓库本身（与 `git clone` 走同一条认证链路），不再用 `ssh -T` 测另一个平台；② **私钥显式指定**——自动探测 `~/.ssh/rmbbiji_gitee`、`~/.ssh/gitee_ed25519`、`~/.ssh/gitee`，也可用 `GITEE_SSH_KEY` 指定，用 `-i` 传给 ssh，从而绕开 `~/.ssh/config` 的 Host 别名问题；③ **多通道回退**——`gitee.com:22` 不通时自动改用 `ssh.gitee.com:443`，还可用 `GITEE_TOKEN` 环境变量走 HTTPS 私人令牌；④ **安全更新**——先克隆到临时目录、成功后再原子替换，`clone` 失败时保留本地版本并继续执行后续步骤，不会出现「旧目录已删、新目录又没下来」导致服务起不来的情况。其余步骤（清理 `~/logs`、备份并尽早恢复 Web 认证文件、装依赖、重启服务）与 GitHub 版一致。 |
| `update_report.sh` | 完整替换 `$HOME/py/report`。脚本可以从任意目录执行，会克隆 `git@rmbbiji:rmbbiji/trading-tools.git` 到临时目录，删除旧的 `$HOME/py/report`，再把新版 `report` 移动到 `$HOME/py/report`，不会做目录合并，也不会备份旧目录。 |
| `clear_codex_chat_history_no_backup.sh` | 清理本机 Codex 聊天历史。默认目标目录是 `$HOME/.codex`，也可以通过 `CODEX_HOME` 指定。脚本会清空相关 SQLite 表、`session_index.jsonl`、`sessions` 文件和 `shell_snapshots` 文件；运行前会要求交互确认。该操作不可逆，建议先退出 Codex 再执行。 |

## 远程运行 Shell 脚本

下面命令会直接从 GitHub 拉取脚本并交给 `bash` 执行。建议先确认脚本内容再运行。

### 安装 zsh / 常用终端工具

这个脚本面向 Debian / Ubuntu，会安装 zsh、oh-my-zsh、Starship、`eza`、`bat`、`fd-find`、`fzf`、`zoxide` 和 Nerd Font。Starship 使用 Catppuccin Powerline 彩虹条，输入符号单独显示在下一行。执行完成后，请运行 `exec zsh -l`，或退出并重新连接 SSH，以加载新的终端配置。

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/setup_zsh_tools_debian.sh)"
```

### 给当前服务器安装 rmbbiji 的 GitHub 公钥

这个脚本需要在目标服务器上执行。它会拉取 `rmbbiji` 的 GitHub 公钥，只取 `ssh-rsa` 那一行，并写入当前用户的 `~/.ssh/authorized_keys`。

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/install_rmbbiji_github_rsa_key.sh)"
```

### 更新 short_cuts

这个脚本会删除当前目录下的 `short_cuts` 目录并安装依赖。关闭旧服务前，脚本会把 `/root/auth.json` 复制到 `/root/short_cuts/web/data/auth.json`，并继续保留 `/root/auth.json`。如果首次运行时只有旧目录中的认证文件，脚本会先将其复制到 `/root/auth.json` 作为长期备份。随后，它只查找命令参数包含 `/root/short_cuts/web/server.py` 的 Python 进程：找到便先停止旧服务，找不到则直接继续，最后始终启动 Web 服务并监听 `0.0.0.0:4188`。进程类型检查可避免误结束执行更新脚本的 `bash -c`。请先切换到你希望放置 `short_cuts` 的目录再运行，并确认 Web 服务确实使用这个路径和端口。

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/update_short_cuts.sh)"
```

### 更新 short_cuts（从 Gitee 克隆）

和上面的脚本行为基本一致，区别是源码仓库换成 Gitee 的 `rmbbiji/short_cuts`（私有库），并且：

- **探测改用 `git ls-remote`**：直接探测 Gitee 仓库本身，和后面的 `git clone` 走完全相同的认证链路，探测通过基本就等于克隆能成。
- **私钥显式指定**：脚本会自动查找 `~/.ssh/rmbbiji_gitee` → `~/.ssh/gitee_ed25519` → `~/.ssh/gitee`，找到就用 `-i` 显式传给 ssh；也可用 `GITEE_SSH_KEY=/path/to/key` 覆盖。这一步是为了绕开下面这个坑。
- **三通道自动回退**：`git@gitee.com:22` → `ssh://git@ssh.gitee.com:443/...` → HTTPS（设置 `GITEE_TOKEN` 私人令牌后启用）。机房封 22 端口时无需额外处理。
- **原子替换**：先把仓库克隆到临时目录，成功后再替换 `./short_cuts`。克隆失败会保留本地已有版本，并继续执行后面的装依赖、重启服务步骤。

### ⚠️ 配置 Gitee SSH 时最容易踩的两个坑

**坑一：`~/.ssh/config` 里的 `Host` 名必须与脚本实际连接的主机名一致。**

`Host` 段只对「你实际连接的那个主机名」生效。脚本连的是 `git@gitee.com`，所以配置必须写成 `Host gitee.com`：

```
Host gitee.com
  HostName gitee.com
  User git
  IdentityFile ~/.ssh/rmbbiji_gitee
  IdentitiesOnly yes
```

写成 `Host rmbbiji` 之类**自定义别名是无效的** —— 别名不会被匹配到，ssh 会退回使用 `~/.ssh/id_rsa`、`~/.ssh/id_ed25519` 等默认密钥，最后报 `Permission denied (publickey)`。更麻烦的是 `ssh -T rmbbiji` 这种自测方式会成功，很容易误判成「密钥没问题」。

所以自测请用脚本同款命令，而不是 `ssh -T`：

```bash
git ls-remote git@gitee.com:rmbbiji/short_cuts.git
```

（或者干脆不碰 config，直接 `export GITEE_SSH_KEY=~/.ssh/rmbbiji_gitee`，脚本会用 `-i` 显式指定。）

**坑二：公钥加在哪里。**

| 类型 | 添加位置 | 权限 | `ssh -T git@gitee.com` 显示 |
| --- | --- | --- | --- |
| 账号公钥 | 个人设置 → 安全设置 → SSH 公钥 | 账号下所有仓库可读可写 | `Hi <你的用户名>!` |
| 部署公钥 | 目标仓库 → 管理 → 部署公钥管理 | **仅该仓库只读** | `Hi Anonymous!` |

拉取代码用哪种都行，**但用部署公钥时必须加在 `short_cuts` 这个仓库上**，加在别的仓库上会认证失败。看到 `Hi Anonymous!` 是部署公钥的正常表现，不代表失败。

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/update_short_cuts_gitee.sh)"
```

### 完整替换 py/report

这个脚本可以从任意目录执行。它会删除旧的 `$HOME/py/report`，然后用 `rmbbiji/trading-tools` 仓库里的新版 `report` 完整替换 `$HOME/py/report`，不会备份旧目录。

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/update_report.sh)"
```

### 清理本地 Codex 聊天历史

默认清理 `$HOME/.codex`：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/clear_codex_chat_history_no_backup.sh)"
```

如果你的 Codex 目录不是默认位置，可以指定 `CODEX_HOME`：

```bash
CODEX_HOME=/path/to/.codex bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/clear_codex_chat_history_no_backup.sh)"
```

## 服务器一键使用

如果你想在一台新的 Debian / Ubuntu 服务器上直接使用这套配置，可以运行下面这一行。它会把 `.vimrc` 下载到 `~/.vimrc`，然后执行 `setup_zsh_tools_debian.sh` 安装 zsh / oh-my-zsh / Starship / `eza` / `bat` / `fd-find` / `fzf` / `zoxide` / Nerd Font。

```bash
bash -c 'set -euo pipefail; BASE="https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main"; curl -fsSL "$BASE/.vimrc" -o "$HOME/.vimrc"; bash -c "$(curl -fsSL "$BASE/setup_zsh_tools_debian.sh")"'
```

## setup_zsh_tools_debian.sh 安装后怎么用

脚本执行完成后，先重新进入 zsh：

```bash
exec zsh -l
```

如果你是通过 SSH 登录服务器，直接断开后重新连一次也可以。

### zsh + oh-my-zsh

安装完成后，默认 shell 会切到 zsh，`~/.zshrc` 里会启用 `git`、`zsh-autosuggestions`、`zsh-syntax-highlighting`。

常用体验：

- 输入输过的长命令时，灰色尾巴是 `zsh-autosuggestions` 给的建议，按右方向键可以整段接受。
- 命令输入正确时通常会高亮，拼错命令时不会按正常命令颜色显示，这是 `zsh-syntax-highlighting` 在工作。
- 重新加载配置可以用：

```bash
source ~/.zshrc
```

### Starship 提示符

Starship 会自动显示当前目录、Git 分支、语言运行时等信息，配置文件在：

```bash
~/.config/starship.toml
```

如果你改了这个文件，重新加载 shell 即可生效：

```bash
exec zsh -l
```

### eza

脚本已经把常用别名写好了：

```bash
ls
ll
la
tree
```

实际效果分别是：

- `ls`：图标 + 目录优先。
- `ll`：长列表，带 Git 状态、相对时间。
- `la`：长列表 + 显示隐藏文件。
- `tree`：树状查看目录，默认深度 2。

如果你想直接用 `eza` 原生命令，也可以：

```bash
eza --long --header --git
eza --all --long
eza --tree --level=3
```

### bat

脚本会把 `cat` 映射到 `bat`，所以以后这些命令都可以直接用：

```bash
cat README.md
bat README.md
v README.md
```

说明：

- `cat 文件`：会带语法高亮和行号预览。
- `v 文件`：不分页，直接显示，适合快速看代码。
- 如果你临时想用系统原生 `cat`，可以执行：

```bash
command cat README.md
```

### fd

Debian / Ubuntu 包名是 `fd-find`，脚本已经自动加了 `alias fd='fdfind'`，所以平时直接用 `fd`：

```bash
fd
fd report
fd -t f py
fd -e sh
fd config ~
```

常见用法：

- `fd report`：找名字里带 `report` 的文件或目录。
- `fd -t f py`：只找文件名里带 `py` 的文件。
- `fd -e sh`：找所有 `.sh` 文件。
- `fd config ~`：从 `~` 开始搜索。

### fzf

脚本会按官方方式安装 `fzf`，并自动启用 zsh 集成。最常用的是下面几种：

```bash
fzf
history | fzf
vim "$(fzf)"
```

常用按键：

- `Ctrl-R`：模糊搜索历史命令。
- `Ctrl-T`：把当前目录下选中的文件或目录贴到命令行。
- `Alt-C`：模糊搜索目录，然后直接 `cd` 进去。
- `Enter`：确认选择。
- `Esc` 或 `Ctrl-C`：退出。
- `Tab`：多选。

zsh 集成开启后，还可以用模糊补全：

```bash
vim **<Tab>
cd **<Tab>
ssh **<Tab>
kill -9 **<Tab>
```

例子：

- `vim **<Tab>`：模糊找文件后打开。
- `cd **<Tab>`：模糊找目录后进入。
- `ssh **<Tab>`：从 `~/.ssh/config` 或 `/etc/hosts` 里模糊选主机。

### zoxide

`zoxide` 是增强版 `cd`，会记住你常去的目录。脚本已经自动执行了 `eval "$(zoxide init zsh)"`。

常用命令：

```bash
z report
z /var/log
zi
```

说明：

- `z report`：跳到历史里最匹配 `report` 的目录。
- `z /var/log`：第一次正常进入目录，之后 `z log` 一般就能快速跳。
- `zi`：打开交互选择器，挑一个常去目录再跳转。

它会随着你平时 `cd` 的使用自动学习，不需要额外维护。

### Nerd Font

脚本默认安装 `JetBrainsMono Nerd Font`，也可以在执行脚本前改成别的名字：

```bash
NERD_FONT_NAME=FiraCode bash setup_zsh_tools_debian.sh
```

安装完成后，还需要在你自己的终端软件里把字体切换成对应的 Nerd Font，否则：

- Starship 的分隔符可能显示成方块。
- `eza` 的图标可能显示不正常。

如果你想确认字体已经装好，可以运行：

```bash
fc-list | grep "Nerd Font"
```

如果只想在服务器上使用 Vim 配置，不安装 zsh：

```bash
curl -fsSL https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/.vimrc -o ~/.vimrc
```

如果服务器上也需要更新 `short_cuts`，请先确认 SSH key 和 `git@rmbbiji` 主机别名已经配置好，然后在目标目录运行：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/update_short_cuts.sh)"
```

如果这台服务器走 Gitee 更稳（没有配置 `git@rmbbiji` 别名，但有 Gitee SSH 权限），改用：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/rmbbiji-toolbox/main/update_short_cuts_gitee.sh)"
```
