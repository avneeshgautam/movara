#!/usr/bin/env bash
# Builds the web app and serves it on http://localhost:8099
#
# Use this rather than opening build/web/index.html directly: Flutter web
# needs a real HTTP origin, and both Google sign-in and the GPS used by the
# Running tab only work on a secure context, which localhost counts as.
#
# Pass --no-build to re-serve the existing build without recompiling.
set -euo pipefail
cd "$(dirname "$0")"

PORT="${PORT:-8099}"

if [ "${1:-}" != "--no-build" ]; then
  ./build-web.sh
fi

echo
echo "Serving on http://localhost:$PORT  (Ctrl-C to stop)"
exec python3 -m http.server "$PORT" --directory build/web
