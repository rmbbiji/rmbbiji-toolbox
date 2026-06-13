#!/usr/bin/env bash
set -euo pipefail

echo "=== short_cuts 更新脚本 ==="

# ==================== 检测是否能访问 rmbbiji (GitHub) ====================
echo "正在检测 rmbbiji (GitHub) SSH 权限..."

if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no rmbbiji "exit" 2>/dev/null; then
    echo "✅ SSH 认证成功（GitHub），开始更新仓库..."
    
    rm -rf short_cuts
    git clone git@rmbbiji:rain-strom/short_cuts.git
    
    if [ ! -d "short_cuts" ]; then
        echo "❌ git clone 失败！"
        exit 1
    fi
    echo "✅ 仓库克隆/更新完成。"
    
else
    echo "⚠️  无法通过 SSH 访问 rmbbiji（GitHub），跳过更新，使用本地已有版本。"
fi

# ==================== 后续通用操作 ====================
echo "正在添加执行权限..."
if [ -f "short_cuts/expand/get_running_python.sh" ]; then
    chmod +x short_cuts/expand/get_running_python.sh
    echo "✅ 执行权限已添加。"
else
    echo "❌ 错误：未找到 short_cuts/expand/get_running_python.sh"
    echo "   请检查仓库是否正确克隆。"
    exit 1
fi

echo "正在安装依赖..."
if [ -f "short_cuts/requirements.txt" ]; then
    pip3 install --break-system-packages -r short_cuts/requirements.txt
    echo "✅ 依赖安装完成。"
else
    echo "⚠️  未找到 short_cuts/requirements.txt，跳过安装。"
fi

echo "🎉 所有步骤执行完毕！"
