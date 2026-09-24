#!/usr/bin/env bash
set -euo pipefail

echo "=== short_cuts 更新脚本（Gitee 版） ==="

# ==================== 第一步：清理 ~/logs 中超过 3 天的日志 ====================
logs_dir="$HOME/logs"
log_keep_days=3

echo "正在清理 $logs_dir 中超过 ${log_keep_days} 天的文件..."
if [ -d "$logs_dir" ]; then
    # -type f        ：只删文件，保留目录结构（~/logs 本身不会被删）
    # -mtime +3      ：最后修改时间超过 3 天；如需精确 72 小时可改为 -mmin +4320
    # 清理过程中出现的权限/IO 错误只提示、不中断整个更新流程。
    old_logs=$( { find "$logs_dir" -type f -mtime +"$log_keep_days" 2>/dev/null || true; } | wc -l | tr -d ' ' )
    if [ "$old_logs" -gt 0 ]; then
        find "$logs_dir" -type f -mtime +"$log_keep_days" -delete 2>/dev/null || true
        left_logs=$( { find "$logs_dir" -type f 2>/dev/null || true; } | wc -l | tr -d ' ' )
        echo "✅ 已清理 $old_logs 个超过 ${log_keep_days} 天的日志文件，剩余 $left_logs 个。"
    else
        echo "ℹ️  没有超过 ${log_keep_days} 天的日志文件，无需清理。"
    fi
else
    echo "ℹ️  目录 $logs_dir 不存在，跳过清理。"
fi

auth_file="/root/short_cuts/web/data/auth.json"
auth_backup="/root/auth.json"

work_dir="$(pwd)"
clone_dir="$work_dir/short_cuts"
tmp_dir="$work_dir/.short_cuts_new.$$"
# 中途任何原因退出都清掉临时目录，不污染工作目录
trap 'rm -rf "$tmp_dir"' EXIT

# ==================== Gitee 仓库地址 ====================
# ① 默认通道：gitee.com 的 22 端口
gitee_repo_ssh="git@gitee.com:rmbbiji/short_cuts.git"
# ② 备用通道：Gitee 官方为「22 端口被封锁」提供的 443 端口
gitee_repo_ssh443="ssh://git@ssh.gitee.com:443/rmbbiji/short_cuts.git"
# ③ 兜底通道：完全绕开 SSH，用 Gitee 私人令牌走 HTTPS
#    启用方式：先 export GITEE_TOKEN=<你的私人令牌>，再执行本脚本
gitee_repo_https="https://oauth2:${GITEE_TOKEN:-}@gitee.com/rmbbiji/short_cuts.git"

# 所有 SSH 操作统一参数：非交互 + 超时 + 自动接受新主机指纹（否则会卡在 yes/no 提示）
ssh_base_opts="ssh -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new"

# ==================== Gitee 专用私钥 ====================
# 这里用 -i 显式指定私钥，是为了彻底绕开 ~/.ssh/config 的 Host 匹配问题。
# 常见的坑：config 里写的是 `Host rmbbiji`，但脚本连接的是 `git@gitee.com`——
# Host 段只对「实际连接的主机名」生效，别名压根不会被匹配到，ssh 于是退回使用
# ~/.ssh 下的默认密钥（id_rsa / id_ed25519 …），最终报 Permission denied (publickey)。
# 而 `ssh -T rmbbiji` 自测却是成功的，非常容易误判。
# 可选覆盖：export GITEE_SSH_KEY=/path/to/your_gitee_key
gitee_key=""
if [ -n "${GITEE_SSH_KEY:-}" ]; then
    if [ -f "$GITEE_SSH_KEY" ]; then
        gitee_key="$GITEE_SSH_KEY"
    else
        echo "⚠️  GITEE_SSH_KEY 指向的文件不存在：${GITEE_SSH_KEY}（已忽略，改为自动探测）"
    fi
fi
if [ -z "$gitee_key" ]; then
    for k in "$HOME/.ssh/rmbbiji_gitee" "$HOME/.ssh/gitee_ed25519" "$HOME/.ssh/gitee"; do
        if [ -f "$k" ]; then
            gitee_key="$k"
            break
        fi
    done
fi

ssh_with_key=""
if [ -n "$gitee_key" ]; then
    ssh_with_key="$ssh_base_opts -i $gitee_key -o IdentitiesOnly=yes"
    echo "ℹ️  检测到 Gitee 专用私钥：$gitee_key"
else
    echo "ℹ️  未找到 Gitee 专用私钥，将按 ~/.ssh/config 与默认密钥规则尝试。"
fi

# 用 git ls-remote 探测仓库，而不是 ssh -T：
# 它和后面的 git clone 走的是**同一条认证链路**，「探测通过」就基本等于「clone 能成」。
# 原脚本测的是 GitHub（ssh -T rmbbiji），clone 的却是 Gitee，两个平台密钥不同，
# 探测结果永远代表不了真正的克隆链路，只能一直落进「跳过更新」分支。
probe_repo() {
    case "$1" in
        http*) git ls-remote --heads "$1" >/dev/null 2>&1 ;;
        *)     GIT_SSH_COMMAND="$2" git ls-remote --heads "$1" >/dev/null 2>&1 ;;
    esac
}

echo "正在检测 Gitee 仓库可访问性：$gitee_repo_ssh"

candidates_repo=()
candidates_ssh=()
# 尝试顺序：显式私钥(22) → 默认规则(22) → 显式私钥(443) → 默认规则(443) → HTTPS 令牌
if [ -n "$ssh_with_key" ]; then
    candidates_repo+=("$gitee_repo_ssh");    candidates_ssh+=("$ssh_with_key")
fi
candidates_repo+=("$gitee_repo_ssh");        candidates_ssh+=("$ssh_base_opts")
if [ -n "$ssh_with_key" ]; then
    candidates_repo+=("$gitee_repo_ssh443"); candidates_ssh+=("$ssh_with_key")
fi
candidates_repo+=("$gitee_repo_ssh443");     candidates_ssh+=("$ssh_base_opts")
if [ -n "${GITEE_TOKEN:-}" ]; then
    candidates_repo+=("$gitee_repo_https");  candidates_ssh+=("")
fi

gitee_ok=""
gitee_repo=""
gitee_ssh=""
for i in "${!candidates_repo[@]}"; do
    if probe_repo "${candidates_repo[$i]}" "${candidates_ssh[$i]}"; then
        gitee_ok=1
        gitee_repo="${candidates_repo[$i]}"
        gitee_ssh="${candidates_ssh[$i]}"
        break
    fi
done

if [ -n "$gitee_ok" ]; then
    echo "✅ Gitee 仓库可访问：$gitee_repo"
    case "$gitee_repo" in
        *ssh.gitee.com*) echo "   （22 端口不通，已自动改用 Gitee 官方 443 通道）" ;;
    esac
    if [ -n "$gitee_key" ] && [ "$gitee_ssh" = "$ssh_with_key" ]; then
        echo "   （使用私钥：${gitee_key}）"
    fi
fi

# ==================== 更新仓库 ====================
if [ -n "$gitee_ok" ]; then
    echo "开始更新仓库..."

    if [ -f "$auth_file" ]; then
        if [ ! -f "$auth_backup" ]; then
            cp "$auth_file" "$auth_backup"
            echo "✅ 已将 web 认证文件备份到 ${auth_backup}。"
        else
            echo "ℹ️  $auth_backup 已存在，继续保留该认证文件。"
        fi
    fi

    clone_repo() {
        if [ -n "$gitee_ssh" ]; then
            GIT_SSH_COMMAND="$gitee_ssh" git clone "$gitee_repo" "$tmp_dir"
        else
            git clone "$gitee_repo" "$tmp_dir"
        fi
    }

    # 先克隆到临时目录，成功后再整体替换。
    # 原脚本是 rm -rf short_cuts && git clone，一旦 clone 失败，
    # 本地版本已经没了、脚本又 set -e 退出，服务直接起不来（与「保留本地版本」的承诺自相矛盾）。
    rm -rf "$tmp_dir"
    if clone_repo; then
        old_dir="${clone_dir}.old.$$"
        rm -rf "$old_dir"
        if [ -d "$clone_dir" ]; then
            mv "$clone_dir" "$old_dir"
        fi
        mv "$tmp_dir" "$clone_dir"
        rm -rf "$old_dir"

        if [ ! -d "$clone_dir" ]; then
            echo "❌ 仓库替换失败！"
            exit 1
        fi
        echo "✅ 仓库更新完成（来源：${gitee_repo}）。"
    else
        rm -rf "$tmp_dir"
        echo "❌ git clone 失败（探测通过但拉取失败，多为网络抖动）。"
        echo "   本地版本 $clone_dir 未被改动，本次跳过更新并继续走后续流程。"
    fi

    # 认证文件会随目录替换一起消失，这里尽早恢复：
    # 后续任何步骤失败（比如依赖安装报错退出）时，Web 控制台的 auth.json 都还在。
    if [ -f "$auth_backup" ]; then
        echo "正在恢复 web 认证文件..."
        mkdir -p "$(dirname "$auth_file")"
        cp -f "$auth_backup" "$auth_file"
        echo "✅ 已将 $auth_backup 复制到 ${auth_file}，源文件继续保留。"
    else
        echo "ℹ️  未找到 ${auth_backup}，无需复制认证文件。"
    fi

else
    echo "⚠️  无法访问 Gitee 仓库 rmbbiji/short_cuts，跳过更新，使用本地已有版本。"
    echo
    echo "   排查步骤："
    echo "   1) 生成一把专供 Gitee 的密钥（不要和 GitHub 共用同一把）："
    echo "        ssh-keygen -t ed25519 -C \"rmbbiji@gitee\" -f ~/.ssh/rmbbiji_gitee -N \"\""
    echo "   2) 把公钥加进 Gitee（两种任选其一，仅拉取代码都够用）："
    echo "        · 账号公钥：Gitee → 个人设置 → 安全设置 → SSH 公钥 → 添加公钥（全仓库可读写）"
    echo "        · 部署公钥：short_cuts 仓库 → 管理 → 部署公钥管理 → 添加部署公钥（只读，仅限该仓库）"
    echo "      ⚠️ 用部署公钥时务必加在 short_cuts 仓库上；加在别的仓库上会认证失败。"
    echo "   3) 关键的一步——config 里的 Host 名必须和脚本实际连接的主机名一致："
    echo "        Host gitee.com"
    echo "          HostName gitee.com"
    echo "          User git"
    echo "          IdentityFile ~/.ssh/rmbbiji_gitee"
    echo "          IdentitiesOnly yes"
    echo "      ⚠️ 写成 Host rmbbiji 是无效的：脚本连的是 git@gitee.com，别名不会被匹配到。"
    echo "   4) 最省事的办法——跳过 config，直接指定私钥："
    echo "        export GITEE_SSH_KEY=~/.ssh/rmbbiji_gitee"
    echo "      或把密钥放到默认路径（脚本会自动探测）：~/.ssh/rmbbiji_gitee"
    echo "   5) 自测请用脚本同款命令，不要只用 ssh -T（密钥类型不同时它可能给出误导结果）："
    echo "        git ls-remote git@gitee.com:rmbbiji/short_cuts.git"
    echo "      注：使用部署公钥时，ssh -T git@gitee.com 显示 Hi Anonymous! 属正常现象。"
fi

# ==================== 后续操作 ====================
echo "正在添加执行权限..."
if [ -f "short_cuts/expand/get_running_python.sh" ]; then
    chmod +x short_cuts/expand/get_running_python.sh
    echo "✅ 执行权限已添加。"
else
    echo "❌ 未找到 short_cuts/expand/get_running_python.sh"
    echo "   请确保仓库已正确存在或网络正常。"
    exit 1
fi

echo "正在安装依赖..."
if [ -f "short_cuts/requirements.txt" ]; then
    # 这里必须带 --ignore-installed：
    # lighter-sdk>=1.1.4 要求 urllib3<2.1.0，pip 会去装 urllib3 2.0.7；
    # 但 Debian 上的 urllib3 2.3.0 由 apt（python3-urllib3）装在 /usr/lib/python3/dist-packages，
    # 没有 RECORD 文件，pip 卸载它会直接报 uninstall-no-record-file 并中断整个脚本。
    # 加上 --ignore-installed 后 pip 只往 /usr/local 的 dist-packages 里装（sys.path 中优先于
    # /usr/lib/python3/dist-packages），不再尝试卸载 apt 的包。
    if ! pip3 install --break-system-packages --ignore-installed -r short_cuts/requirements.txt; then
        echo "❌ 依赖安装失败。"
        echo "   如仍报 uninstall-no-record-file，请在服务器上手动执行同一条命令查看完整日志："
        echo "   pip3 install --break-system-packages --ignore-installed -r short_cuts/requirements.txt"
        exit 1
    fi
    # lighter-sdk 要求 urllib3<2.1，这里打印实际生效的版本，便于确认没有被 apt 的 2.3.0 抢走。
    python3 -c "import urllib3; print('   urllib3', urllib3.__version__, urllib3.__file__)" || true
    echo "✅ 依赖安装完成。"
else
    echo "⚠️  未找到 short_cuts/requirements.txt，跳过安装。"
fi

# ==================== 重启 short_cuts Web 服务 ====================
server_script="/root/short_cuts/web/server.py"
server_port="4188"

if [ ! -f "$server_script" ]; then
    echo "❌ 未找到 Web 服务文件：$server_script"
    exit 1
fi

get_server_pids() {
    # 只返回 Python 进程，并且命令行必须包含目标 server.py。
    # 即使 bash -c 的命令行里出现 server.py，也会因为进程名不是 Python 而被排除。
    ps -eo pid=,comm=,args= | awk -v target="$server_script" '
        $2 ~ /^python/ && index($0, target) { print $1 }
    '
}

# 认证文件已在 clone 之后立即恢复（见上方），这里直接关闭旧服务。
echo "正在停止旧的 short_cuts Web 服务..."
server_pids=$(get_server_pids)
if [ -n "$server_pids" ]; then
    for pid in $server_pids; do
        kill "$pid" 2>/dev/null || true
    done

    # 给服务一个正常退出的机会，避免新服务启动时端口仍被占用。
    sleep 1
    remaining_pids=$(get_server_pids)
    if [ -n "$remaining_pids" ]; then
        echo "⚠️  旧服务未正常退出，正在强制停止..."
        for pid in $remaining_pids; do
            kill -KILL "$pid" 2>/dev/null || true
        done
        sleep 1
        remaining_pids=$(get_server_pids)
        if [ -n "$remaining_pids" ]; then
            echo "❌ 无法停止旧的 Web 服务，请确认当前用户有权限结束这些进程：$remaining_pids"
            exit 1
        fi
    fi
    echo "✅ 旧的 Web 服务已停止。"
else
    echo "ℹ️  未找到正在运行的旧 Web 服务。"
fi

echo "正在启动新的 short_cuts Web 服务..."
nohup python3 "$server_script" --host 0.0.0.0 --port "$server_port" >/dev/null 2>&1 &
server_pid=$!
sleep 1
if ! kill -0 "$server_pid" 2>/dev/null; then
    echo "❌ Web 服务启动失败。"
    exit 1
fi
echo "✅ Web 服务已启动（PID: ${server_pid}，端口: ${server_port}）。"

echo "🎉 所有步骤执行完毕！"
