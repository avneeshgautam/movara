#!/usr/bin/env bash
# Rebuilds Movara and reinstalls it on the connected iPhone.
#
# Use this for shipping a change you have finished. While actually working on
# something, prefer:
#
#   flutter run            # then press r to hot reload, R to hot restart
#
# which pushes Dart changes to the running app in about a second instead of
# rebuilding and reinstalling.
#
# A full reinstall IS required when you change anything native: permissions or
# other Info.plist keys, the Firebase config, app icons, or dependencies in
# pubspec.yaml.
#
# Requires signing to be set up once in Xcode (Runner target -> Signing &
# Capabilities -> Automatically manage signing -> your Apple ID as Team).
set -euo pipefail
cd "$(dirname "$0")"

# Without this the app falls back to the localhost default in api_config.dart,
# which on a phone means the phone itself -- so every request fails with
# "could not reach the backend". firebase.env may override API_BASE_URL; the
# Firebase keys in it are web-only (iOS reads GoogleService-Info.plist).
if [ -f firebase.env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./firebase.env
  set +a
fi
API_BASE_URL="${API_BASE_URL:-https://movara-backend-h22y.onrender.com/api}"

echo "==> Building against $API_BASE_URL"
echo "    (codesigning with the team set in Xcode)"
flutter build ios --release --dart-define=API_BASE_URL="$API_BASE_URL"

# A booted simulator makes "the attached device" ambiguous and flutter then
# installs nowhere -- while still exiting 0, so this has to be checked by hand.
DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  DEVICE=$(flutter devices --machine 2>/dev/null \
    | python3 -c "import json,sys; d=[x['id'] for x in json.load(sys.stdin) if x.get('targetPlatform','').startswith('ios') and not x.get('emulator')]; print(d[0] if len(d)==1 else '')")
fi

if [ -z "$DEVICE" ]; then
  echo "error: could not identify a single physical iPhone."
  echo "Connect one (and unlock it), or pass its id:  ./run-ios.sh <device-id>"
  flutter devices
  exit 1
fi

echo "==> Installing to $DEVICE"
flutter install --release -d "$DEVICE"

# flutter install can report success having done nothing, so confirm.
if xcrun devicectl device info apps --device "$DEVICE" 2>/dev/null \
     | grep -q com.avneesh.movaraApp; then
  echo "==> Confirmed on device."
else
  echo "error: the app is not listed on the device after install." >&2
  exit 1
fi

echo
echo "Done. If the app refuses to open, trust the certificate again:"
echo "  Settings -> General -> VPN & Device Management -> your Apple ID -> Trust"
