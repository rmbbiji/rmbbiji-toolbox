#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

if [ ! -d "$CODEX_HOME" ]; then
  echo "Codex home not found: $CODEX_HOME" >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 not found. Please install sqlite3 first." >&2
  exit 1
fi

echo "=== Clearing local Codex chat history ==="
echo "Target: $CODEX_HOME"
echo
echo "建议先退出 Codex 再运行，否则当前活跃会话可能会被重新写入。"
echo

read -r -p "确定要清除所有 Codex 本地聊天记录吗？此操作不可逆 (y/N): " -n 1
echo

if [[ ! "${REPLY:-}" =~ ^[Yy]$ ]]; then
  echo "操作已取消。"
  exit 0
fi

if [ -f "$CODEX_HOME/logs_2.sqlite" ]; then
  sqlite3 "$CODEX_HOME/logs_2.sqlite" <<'SQL'
DELETE FROM logs;
PRAGMA wal_checkpoint(TRUNCATE);
VACUUM;
SQL
fi

if [ -f "$CODEX_HOME/state_5.sqlite" ]; then
  sqlite3 "$CODEX_HOME/state_5.sqlite" <<'SQL'
PRAGMA foreign_keys = OFF;
DELETE FROM thread_spawn_edges;
DELETE FROM thread_dynamic_tools;
DELETE FROM agent_job_items;
DELETE FROM agent_jobs;
DELETE FROM threads;
DELETE FROM backfill_state;
PRAGMA wal_checkpoint(TRUNCATE);
VACUUM;
SQL
fi

if [ -f "$CODEX_HOME/goals_1.sqlite" ]; then
  sqlite3 "$CODEX_HOME/goals_1.sqlite" <<'SQL'
DELETE FROM thread_goals;
PRAGMA wal_checkpoint(TRUNCATE);
VACUUM;
SQL
fi

if [ -f "$CODEX_HOME/session_index.jsonl" ]; then
  : > "$CODEX_HOME/session_index.jsonl"
fi

if [ -d "$CODEX_HOME/sessions" ]; then
  find "$CODEX_HOME/sessions" -type f -delete
fi

if [ -d "$CODEX_HOME/shell_snapshots" ]; then
  find "$CODEX_HOME/shell_snapshots" -type f -delete
fi

echo "Done. Local Codex chat history has been cleared."
