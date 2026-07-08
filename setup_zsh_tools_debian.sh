#!/usr/bin/env bash
set -euo pipefail

# Debian / Ubuntu: 安装 zsh + oh-my-zsh + eza/bat/fd/zoxide + Nerd Font
# 用法：
#   bash setup_zsh_tools_debian.sh
# 可选：
#   NERD_FONT_NAME=FiraCode bash setup_zsh_tools_debian.sh
#
# 默认安装当前用户；如果你当前就是 root，则给 root 安装。

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
NERD_FONT_NAME="${NERD_FONT_NAME:-JetBrainsMono}"
NERD_FONT_DIR="${TARGET_HOME}/.local/share/fonts/NerdFonts/${NERD_FONT_NAME}"
MANAGED_BEGIN="# >>> rmbbiji-toolbox managed block >>>"
MANAGED_END="# <<< rmbbiji-toolbox managed block <<<"

echo "当前用户: ${TARGET_USER}"
echo "用户目录: ${TARGET_HOME}"
echo "Nerd Font: ${NERD_FONT_NAME}"
echo "开始安装 zsh / oh-my-zsh / eza / bat / fd / zoxide / Nerd Font..."

${SUDO} apt-get update
${SUDO} apt-get install -y \
  zsh \
  git \
  curl \
  ca-certificates \
  gpg \
  wget \
  bat \
  fd-find \
  fontconfig \
  xz-utils

install_eza() {
  echo "安装 eza..."
  ${SUDO} mkdir -p /etc/apt/keyrings
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | ${SUDO} gpg --dearmor --yes -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    | ${SUDO} tee /etc/apt/sources.list.d/gierens.list >/dev/null
  ${SUDO} chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  ${SUDO} apt-get update
  ${SUDO} apt-get install -y eza
}

install_eza

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

install_zoxide() {
  local zoxide_bin="${TARGET_HOME}/.local/bin/zoxide"

  if command -v zoxide >/dev/null 2>&1 || [[ -x "${zoxide_bin}" ]]; then
    echo "zoxide 已存在，跳过安装"
    return
  fi

  echo "安装 zoxide..."
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
}

install_zoxide

install_nerd_font() {
  local tmp_dir archive_url archive_path

  echo "安装 Nerd Font: ${NERD_FONT_NAME}..."
  tmp_dir="$(mktemp -d)"
  archive_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${NERD_FONT_NAME}.tar.xz"
  archive_path="${tmp_dir}/${NERD_FONT_NAME}.tar.xz"

  mkdir -p "${NERD_FONT_DIR}"
  curl -fsSL "${archive_url}" -o "${archive_path}"
  tar -xJf "${archive_path}" -C "${NERD_FONT_DIR}"

  if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "${TARGET_HOME}/.local/share/fonts"
  fi

  rm -rf "${tmp_dir}"
}

install_nerd_font

ensure_zshrc_base() {
  if [[ ! -f "${ZSHRC}" ]]; then
    echo "创建 ${ZSHRC}"
    cat > "${ZSHRC}" <<EOF
export ZSH="${ZSH_DIR}"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source "\$ZSH/oh-my-zsh.sh"
EOF
    return
  fi

  backup_file="${ZSHRC}.bak.$(date +%Y%m%d_%H%M%S)"
  echo "备份 ${ZSHRC} 到 ${backup_file}"
  cp "${ZSHRC}" "${backup_file}"

  if ! grep -q '^export ZSH=' "${ZSHRC}"; then
    sed -i "1iexport ZSH=\"${ZSH_DIR}\"" "${ZSHRC}"
  fi

  if grep -q '^plugins=' "${ZSHRC}"; then
    sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "${ZSHRC}"
  elif grep -q 'oh-my-zsh\.sh' "${ZSHRC}"; then
    awk '
      !done && /oh-my-zsh\.sh/ {
        print "plugins=(git zsh-autosuggestions zsh-syntax-highlighting)"
        done=1
      }
      { print }
    ' "${ZSHRC}" > "${ZSHRC}.tmp"
    mv "${ZSHRC}.tmp" "${ZSHRC}"
  else
    printf '\nplugins=(git zsh-autosuggestions zsh-syntax-highlighting)\n' >> "${ZSHRC}"
  fi

  if ! grep -q 'oh-my-zsh\.sh' "${ZSHRC}"; then
    cat >> "${ZSHRC}" <<'EOF'

source "$ZSH/oh-my-zsh.sh"
EOF
  fi
}

write_managed_block() {
  local block_file
  block_file="$(mktemp)"

  cat > "${block_file}" <<'EOF'
# >>> rmbbiji-toolbox managed block >>>
export PATH="$HOME/.local/bin:$PATH"

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza --icons=auto --group-directories-first --long --header --git --time-style=relative'
  alias la='eza --icons=auto --group-directories-first --long --header --all --git --time-style=relative'
  alias tree='eza --tree --level=2 --icons=auto --group-directories-first'
fi

if command -v batcat >/dev/null 2>&1; then
  alias bat='batcat'
  alias cat='batcat --paging=never --style=plain'
elif command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never --style=plain'
fi

if command -v fdfind >/dev/null 2>&1; then
  alias fd='fdfind'
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi
# <<< rmbbiji-toolbox managed block <<<
EOF

  if grep -qF "${MANAGED_BEGIN}" "${ZSHRC}" && grep -qF "${MANAGED_END}" "${ZSHRC}"; then
    awk -v begin="${MANAGED_BEGIN}" -v end="${MANAGED_END}" '
      $0 == begin { skip=1; next }
      $0 == end { skip=0; next }
      skip != 1 { print }
    ' "${ZSHRC}" > "${ZSHRC}.tmp"
    mv "${ZSHRC}.tmp" "${ZSHRC}"
  fi

  printf '\n' >> "${ZSHRC}"
  cat "${block_file}" >> "${ZSHRC}"
  rm -f "${block_file}"
}

ensure_zshrc_base
write_managed_block

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
echo "请到你的终端设置里把字体切换成 '${NERD_FONT_NAME} Nerd Font' 或同名字体变体。"
echo "这样 eza / bat / 其他带图标的工具才会正常显示图标。"

if [[ -t 0 && -t 1 ]]; then
  echo
  echo "正在自动进入新的 zsh 登录会话..."
  exec zsh -l
fi
