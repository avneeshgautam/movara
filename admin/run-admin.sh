#!/usr/bin/env bash
# Starts the Movara admin dashboard on http://127.0.0.1:8090 — local only.
#
# It connects to the same database as the live app, reusing DATABASE_URL
# from backend/run-local.sh (gitignored), so no new secret is needed. It is
# bound to 127.0.0.1 and never deployed: nobody else can reach it.
set -euo pipefail
cd "$(dirname "$0")"

PY=../backend/.venv/bin/python
PORT="${PORT:-8090}"
echo "==> Movara admin on http://127.0.0.1:$PORT  (Ctrl+C to stop)"
( sleep 2 && open "http://127.0.0.1:$PORT" >/dev/null 2>&1 || true ) &
exec env \
  DATABASE_URL="${DATABASE_URL:?Set DATABASE_URL to the live Supabase connection string before starting the admin portal}" \
  "$PY" -m uvicorn admin_app:app --app-dir . --host 127.0.0.1 --port "$PORT"
