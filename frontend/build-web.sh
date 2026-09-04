#!/usr/bin/env bash
# Builds the Flutter web app with the settings the deployed site needs.
#
# The Firebase values below are the web client config. They are public by
# design -- they identify the project and grant nothing on their own, which is
# why they ship inside every web app's JavaScript. Access is controlled by the
# Authorized domains list and by backend token verification, not by hiding
# these. The MongoDB URI, by contrast, is a real secret and lives only in
# run-local.sh / Render.
set -euo pipefail
cd "$(dirname "$0")"

API_BASE_URL="${API_BASE_URL:-https://movara-backend-h22y.onrender.com/api}"

exec flutter build web --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=FIREBASE_API_KEY=AIzaSyBRPPj_ASwysLpyUeYorRFsYv6VC9TUu0c \
  --dart-define=FIREBASE_AUTH_DOMAIN=movara-2b8f1.firebaseapp.com \
  --dart-define=FIREBASE_PROJECT_ID=movara-2b8f1 \
  --dart-define=FIREBASE_APP_ID=1:323894602937:web:41f5fa76827831185c7f68 \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=323894602937
