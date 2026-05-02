#!/usr/bin/env bash
set -euo pipefail

# Ubuntu 24.04: 安装 zsh + oh-my-zsh + 常用插件
# 用法：
#   bash install_zsh.sh
#
# 如果你当前是 root，会给 root 安装。
# 如果你当前是普通用户，会给当前普通用户安装。

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

TARGET_USER="${USER}"
TARGET_HOME="${HOME}"
ZSH_DIR="${TARGET_HOME}/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-${ZSH_DIR}/custom}"
ZSHRC="${TARGET_HOME}/.zshrc"

echo "当前用户: ${TARGET_USER}"
echo "用户目录: ${TARGET_HOME}"
echo "开始安装 zsh / oh-my-zsh..."

${SUDO} apt-get update
${SUDO} apt-get install -y \
  zsh \
  git \
  curl \
  ca-certificates

# 安装 oh-my-zsh：已存在则跳过
if [[ -f "${ZSH_DIR}/oh-my-zsh.sh" ]]; then
  echo "oh-my-zsh 已存在，跳过安装: ${ZSH_DIR}"
else
  echo "安装 oh-my-zsh..."
  export RUNZSH=no
  export CHSH=no
  export KEEP_ZSHRC=yes
  export ZSH="${ZSH_DIR}"

  tmp_install_script="$(mktemp)"
  curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "${tmp_install_script}"
  sh "${tmp_install_script}"
  rm -f "${tmp_install_script}"
fi

mkdir -p "${ZSH_CUSTOM}/plugins"

install_or_update_plugin() {
  local repo_url="$1"
  local plugin_dir="$2"

  if [[ -d "${plugin_dir}/.git" ]]; then
    echo "更新插件: ${plugin_dir}"
    git -C "${plugin_dir}" pull --ff-only || true
  elif [[ -e "${plugin_dir}" ]]; then
    echo "插件路径已存在但不是 git 仓库，跳过: ${plugin_dir}"
  else
    echo "安装插件: ${repo_url}"
    git clone --depth=1 "${repo_url}" "${plugin_dir}"
  fi
}

install_or_update_plugin \
  "https://github.com/zsh-users/zsh-autosuggestions.git" \
  "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"

install_or_update_plugin \
  "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
  "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"

# 确保 .zshrc 存在
if [[ ! -f "${ZSHRC}" ]]; then
  echo "创建 ${ZSHRC}"
  cat > "${ZSHRC}" <<EOF
export ZSH="${ZSH_DIR}"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source "\$ZSH/oh-my-zsh.sh"
EOF
else
  backup_file="${ZSHRC}.bak.$(date +%Y%m%d_%H%M%S)"
  echo "备份 ${ZSHRC} 到 ${backup_file}"
  cp "${ZSHRC}" "${backup_file}"

  # 如果 .zshrc 里没有 ZSH 配置，补上
  if ! grep -q '^export ZSH=' "${ZSHRC}"; then
    sed -i "1iexport ZSH=\"${ZSH_DIR}\"" "${ZSHRC}"
  fi

  # 如果 .zshrc 里没有 source oh-my-zsh，补上
  if ! grep -q 'oh-my-zsh.sh' "${ZSHRC}"; then
    cat >> "${ZSHRC}" <<'EOF'

source "$ZSH/oh-my-zsh.sh"
EOF
  fi

  # 替换已有 plugins=(...)
  if grep -q '^plugins=' "${ZSHRC}"; then
    sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "${ZSHRC}"
  else
    cat >> "${ZSHRC}" <<'EOF'

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
EOF
  fi
fi

# 确保 zsh-syntax-highlighting 在 zsh-autosuggestions 后面加载
# oh-my-zsh 的 plugins 顺序已经处理好了，这里只提示不做额外 source，避免重复加载。

ZSH_BIN="$(command -v zsh)"

if [[ -z "${ZSH_BIN}" ]]; then
  echo "没有找到 zsh，可检查 apt 安装是否成功"
  exit 1
fi

CURRENT_SHELL="$(getent passwd "${TARGET_USER}" | cut -d: -f7 || true)"

if [[ "${CURRENT_SHELL}" != "${ZSH_BIN}" ]]; then
  echo "切换默认 shell 为: ${ZSH_BIN}"
  if [[ "${EUID}" -eq 0 ]]; then
    chsh -s "${ZSH_BIN}" "${TARGET_USER}"
  else
    sudo chsh -s "${ZSH_BIN}" "${TARGET_USER}"
  fi
else
  echo "默认 shell 已经是 zsh: ${ZSH_BIN}"
fi

echo
echo "安装完成。"
echo "当前终端立即进入 zsh："
echo "  exec zsh -l"
echo
echo "重新登录 SSH 后也会默认进入 zsh。"
