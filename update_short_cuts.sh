#!/bin/bash
set -e  # 遇到任何错误立即退出

# 删除旧的目录（当前目录下）
rm -rf short_cuts

# 克隆仓库（使用 SSH，请确保你有权限且 git 主机别名 rmbbiji 配置正确）
git clone git@rmbbiji:rain-strom/short_cuts.git

# 给目标脚本加执行权限（路径使用当前目录下的 short_cuts）
chmod +x short_cuts/expand/get_running_python.sh

echo "Done."
