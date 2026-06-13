#!/usr/bin/env bash
set -euo pipefail

echo "=== short_cuts 更新脚本 ==="

# ==================== 检测 SSH 权限 ====================
echo "正在检测 rmbbiji SSH 权限..."

if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no git@rmbbiji "exit" 2>/dev/null; then
    echo "✅ SSH 认证成功，开始更新仓库..."
    
    rm -rf short_cuts
    git clone git@rmbbiji:rain-strom/short_cuts.git
    
    if [ ! -d "short_cuts" ]; then
        echo "❌ git clone 失败！"
        exit 1
    fi
    echo "✅ 仓库更新完成。"
    
else
    echo "⚠️  无法通过 SSH 访问，跳过更新，使用本地已有版本。"
fi

# ==================== 后续操作（无论是否更新都执行） ====================
echo "正在设置执行权限..."
if [ -f "short_cuts/expand/get_running_python.sh" ]; then
    chmod +x short_cuts/expand/get_running_python.sh
    echo "✅ 执行权限已添加。"
else
    echo "❌ 未找到 short_cuts/expand/get_running_python.sh"
    exit 1
fi

echo "正在安装依赖..."
if [ -f "short_cuts/requirements.txt" ]; then
    pip3 install --break-system-packages -r short_cuts/requirements.txt
    echo "✅ 依赖安装完成。"
else
    echo "⚠️  未找到 requirements.txt，跳过安装。"
fi

echo "🎉 脚本执行完毕！"
