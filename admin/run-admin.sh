#!/usr/bin/env bash
# Starts the Movara admin dashboard on http://127.0.0.1:8090 — local only.
#
# It connects to the same database as the live app, reusing DATABASE_URL
# from backend/run-local.sh (gitignored), so no new secret is needed. It is
# bound to 127.0.0.1 and never deployed: nobody else can reach it.
set -euo pipefail
cd "$(dirname "$0")"

LOCAL_ENV=../backend/run-local.sh
if [ -z "${DATABASE_URL:-}" ]; then
  if [ -f "$LOCAL_ENV" ]; then
    eval "$(grep -E '^export DATABASE_URL=' "$LOCAL_ENV")"
  fi
fi
: "${DATABASE_URL:?set DATABASE_URL, or add 'export DATABASE_URL=...' to backend/run-local.sh}"
export DATABASE_URL

PY=../backend/.venv/bin/python
PORT="${PORT:-8090}"
echo "==> Movara admin on http://127.0.0.1:$PORT  (Ctrl+C to stop)"
( sleep 2 && open "http://127.0.0.1:$PORT" >/dev/null 2>&1 || true ) &
exec "$PY" -m uvicorn admin_app:app --app-dir . --host 127.0.0.1 --port "$PORT"
