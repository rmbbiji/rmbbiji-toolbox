# rmbbiji 工具配置

这个仓库放了一些个人常用的终端配置、代理规则和维护脚本，主要用于快速初始化 shell 环境、更新快捷脚本、配置 Vim，以及清理本地 Codex 聊天记录。

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `.vimrc` | 精简版 Vim 终端编辑配置，只保留 15 条常用配置：UTF-8 编码、文件类型缩进、语法高亮、行号、鼠标、退格、缩进和搜索增强。 |
| `Crypto.list` | 加密货币和交易相关站点的代理/分流规则列表，包含 futu、Binance、Bybit、Gate、HTX、Hyperliquid、KuCoin、MEXC、OKX、MetaMask、WalletConnect、Web3 等域名关键字、域名后缀、IP-CIDR 和 IP-ASN 规则。适合放进支持 `DOMAIN-SUFFIX`、`DOMAIN-KEYWORD`、`IP-CIDR`、`IP-ASN` 规则格式的代理工具中使用。 |
| `install_zsh.sh` | Ubuntu 24.04 环境下安装 zsh、oh-my-zsh、git、curl、ca-certificates，并安装/更新 `zsh-autosuggestions` 和 `zsh-syntax-highlighting` 插件。脚本会备份已有 `.zshrc`，补齐 oh-my-zsh 配置，并尝试把当前用户默认 shell 切换为 zsh。 |
| `update_short_cuts.sh` | 更新 `short_cuts` 仓库。脚本会先删除当前目录下已有的 `short_cuts` 目录，然后通过 SSH 克隆 `git@rmbbiji:rain-strom/short_cuts.git`，最后给 `short_cuts/expand/get_running_python.sh` 添加执行权限。运行前需要确认当前目录正确，并且本机已配置好对应 SSH 权限和 `rmbbiji` Git 主机别名。 |
| `update_report.sh` | 完整替换 `$HOME/py/report`。脚本可以从任意目录执行，会克隆 `git@rmbbiji:rmbbiji/trading-tools.git` 到临时目录，删除旧的 `$HOME/py/report`，再把新版 `report` 移动到 `$HOME/py/report`，不会做目录合并，也不会备份旧目录。 |
| `clear_codex_chat_history_no_backup.sh` | 清理本机 Codex 聊天历史。默认目标目录是 `$HOME/.codex`，也可以通过 `CODEX_HOME` 指定。脚本会清空相关 SQLite 表、`session_index.jsonl`、`sessions` 文件和 `shell_snapshots` 文件；运行前会要求交互确认。该操作不可逆，建议先退出 Codex 再执行。 |

## 远程运行 Shell 脚本

下面命令会直接从 GitHub 拉取脚本并交给 `bash` 执行。建议先确认脚本内容再运行。

### 安装 zsh / oh-my-zsh

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/-/main/install_zsh.sh)"
```

### 更新 short_cuts

这个脚本会删除当前目录下的 `short_cuts` 目录，请先切换到你希望放置 `short_cuts` 的目录再运行。

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/-/main/update_short_cuts.sh)"
```

### 完整替换 py/report

这个脚本可以从任意目录执行。它会删除旧的 `$HOME/py/report`，然后用 `rmbbiji/trading-tools` 仓库里的新版 `report` 完整替换 `$HOME/py/report`，不会备份旧目录。

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/-/main/update_report.sh)"
```

### 清理本地 Codex 聊天历史

默认清理 `$HOME/.codex`：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/-/main/clear_codex_chat_history_no_backup.sh)"
```

如果你的 Codex 目录不是默认位置，可以指定 `CODEX_HOME`：

```bash
CODEX_HOME=/path/to/.codex bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/-/main/clear_codex_chat_history_no_backup.sh)"
```

## 服务器一键使用

如果你想在一台新的 Ubuntu 服务器上直接使用这套配置，可以运行下面这一行。它会把 `.vimrc` 下载到 `~/.vimrc`，然后执行 `install_zsh.sh` 安装 zsh / oh-my-zsh 和常用插件。

```bash
bash -c 'set -euo pipefail; BASE="https://raw.githubusercontent.com/rmbbiji/-/main"; curl -fsSL "$BASE/.vimrc" -o "$HOME/.vimrc"; bash -c "$(curl -fsSL "$BASE/install_zsh.sh")"'
```

如果只想在服务器上使用 Vim 配置，不安装 zsh：

```bash
curl -fsSL https://raw.githubusercontent.com/rmbbiji/-/main/.vimrc -o ~/.vimrc
```

如果服务器上也需要更新 `short_cuts`，请先确认 SSH key 和 `git@rmbbiji` 主机别名已经配置好，然后在目标目录运行：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmbbiji/-/main/update_short_cuts.sh)"
```
