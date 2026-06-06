#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${PY_BASE_DIR:-${HOME}/py}"
REPO_URL="${TRADING_TOOLS_REPO:-git@rmbbiji:rmbbiji/trading-tools.git}"
REPORT_DIR="${BASE_DIR}/report"
TMP_DIR="${BASE_DIR}/.trading-tools-update.$$"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

if ! command -v git >/dev/null 2>&1; then
  echo "git is required but was not found."
  exit 1
fi

mkdir -p "${BASE_DIR}"

echo "Base dir: ${BASE_DIR}"
echo "Clone repo: ${REPO_URL}"

rm -rf "${TMP_DIR}"
git clone "${REPO_URL}" "${TMP_DIR}"

if [[ -e "${REPORT_DIR}" || -L "${REPORT_DIR}" ]]; then
  echo "Remove existing report: ${REPORT_DIR}"
  rm -rf "${REPORT_DIR}"
fi

echo "Install report: ${REPORT_DIR}"
mv "${TMP_DIR}/report" "${REPORT_DIR}"

echo "Done."
