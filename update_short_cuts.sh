#!/usr/bin/env bash
set -euo pipefail

echo "=== short_cuts 更新脚本 ==="

# ==================== 检测 GitHub SSH 权限 (适配 rmbbiji) ====================
echo "正在检测 rmbbiji (GitHub) SSH 权限..."

# GitHub 认证成功也会返回非 0，不能直接用 ssh 退出码判断。
ssh_output=$(ssh -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=no -T rmbbiji 2>&1 || true)
if printf "%s\n" "$ssh_output" | grep -qi "successfully authenticated"; then
    echo "✅ SSH 认证成功（GitHub），开始更新仓库..."
    
    rm -rf short_cuts
    git clone git@rmbbiji:rain-strom/short_cuts.git
    
    if [ ! -d "short_cuts" ]; then
        echo "❌ git clone 失败！"
        exit 1
    fi
    echo "✅ 仓库更新完成。"
    
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
    pip3 install --break-system-packages -r short_cuts/requirements.txt
    echo "✅ 依赖安装完成。"
else
    echo "⚠️  未找到 short_cuts/requirements.txt，跳过安装。"
fi

echo "🎉 所有步骤执行完毕！"
