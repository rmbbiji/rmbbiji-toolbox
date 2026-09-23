#!/usr/bin/env bash
set -euo pipefail

echo "=== short_cuts 更新脚本 ==="

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

# ==================== 检测 GitHub SSH 权限 (适配 rmbbiji) ====================
echo "正在检测 rmbbiji (GitHub) SSH 权限..."

# GitHub 认证成功也会返回非 0，不能直接用 ssh 退出码判断。
ssh_output=$(ssh -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=no -T rmbbiji 2>&1 || true)
if printf "%s\n" "$ssh_output" | grep -qi "successfully authenticated"; then
    echo "✅ SSH 认证成功（GitHub），开始更新仓库..."

    if [ -f "$auth_file" ]; then
        if [ ! -f "$auth_backup" ]; then
            cp "$auth_file" "$auth_backup"
            echo "✅ 已将 web 认证文件备份到 $auth_backup。"
        else
            echo "ℹ️  $auth_backup 已存在，继续保留该认证文件。"
        fi
    fi

    rm -rf short_cuts
    git clone git@rmbbiji:rain-strom/short_cuts.git
    
    if [ ! -d "short_cuts" ]; then
        echo "❌ git clone 失败！"
        exit 1
    fi

    echo "✅ 仓库更新完成。"

    # 认证文件会随着 rm -rf short_cuts 一起消失，这里尽早恢复：
    # 后续任何步骤失败（比如依赖安装报错退出）时，Web 控制台的 auth.json 都还在。
    if [ -f "$auth_backup" ]; then
        echo "正在恢复 web 认证文件..."
        mkdir -p "$(dirname "$auth_file")"
        cp -f "$auth_backup" "$auth_file"
        echo "✅ 已将 $auth_backup 复制到 $auth_file，源文件继续保留。"
    else
        echo "ℹ️  未找到 $auth_backup，无需复制认证文件。"
    fi

else
    echo "⚠️  无法通过 SSH 访问 rmbbiji，跳过更新，使用本地已有版本。"
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
echo "✅ Web 服务已启动（PID: $server_pid，端口: $server_port）。"

echo "🎉 所有步骤执行完毕！"
