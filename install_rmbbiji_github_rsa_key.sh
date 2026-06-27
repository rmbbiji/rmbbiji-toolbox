#!/usr/bin/env bash
set -euo pipefail

github_keys_url="https://github.com/rmbbiji.keys"

fetch_keys() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$github_keys_url"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO- "$github_keys_url"
    return
  fi

  echo "curl or wget is required" >&2
  exit 1
}

key="$(
  fetch_keys | awk '/^ssh-rsa / { print; exit }'
)"

if [[ -z "$key" ]]; then
  echo "ssh-rsa key not found in $github_keys_url" >&2
  exit 1
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"

if ! grep -qxF "$key" "$HOME/.ssh/authorized_keys"; then
  printf '%s\n' "$key" >> "$HOME/.ssh/authorized_keys"
  echo "installed rmbbiji ssh-rsa key to $HOME/.ssh/authorized_keys"
else
  echo "rmbbiji ssh-rsa key already exists in $HOME/.ssh/authorized_keys"
fi
