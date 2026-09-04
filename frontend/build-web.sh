#!/usr/bin/env bash
# Builds the Flutter web app with the settings the deployed site needs.
#
# Firebase client config is read from firebase.env (gitignored) so no keys
# live in the repository. Copy firebase.env.example and fill in the values
# from the Firebase console: Settings -> General -> Your apps -> Web.
set -euo pipefail
cd "$(dirname "$0")"

if [ -f firebase.env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./firebase.env
  set +a
fi

: "${FIREBASE_API_KEY:?missing — copy firebase.env.example to firebase.env and fill it in}"
: "${FIREBASE_PROJECT_ID:?missing — see firebase.env.example}"
: "${FIREBASE_APP_ID:?missing — see firebase.env.example}"

API_BASE_URL="${API_BASE_URL:-https://movara-backend-h22y.onrender.com/api}"

exec flutter build web --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-}" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_APP_ID="$FIREBASE_APP_ID" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="${FIREBASE_MESSAGING_SENDER_ID:-}"
