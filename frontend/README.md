# Movara frontend

The Flutter app (iPhone, Android, web). Full details — feature map, recipes
for adding features, shipping — are in
**[../docs/DEVELOPER_GUIDE.md](../docs/DEVELOPER_GUIDE.md)**.

## Quick reference

```bash
flutter test              # test suite
flutter analyze
flutter run -d chrome     # web dev loop (hot reload)
./serve-web.sh            # web build on http://localhost:8099 (needs firebase.env)
./run-ios.sh              # build + install on the connected iPhone
```

Android is built in CI only (`.github/workflows/android-apk.yml`).

The app talks to `http://localhost:8080/api` unless given
`--dart-define=API_BASE_URL=...` (`run-ios.sh` and CI pass the deployed
backend).

```
lib/
  main.dart   Firebase init, theme, sign-in gate
  screens/    One file per screen/tab (home_shell.dart holds the tabs)
  services/   State stores, API client, platform integrations
  models/     Data classes
  widgets/    Reusable UI
  theme/      AppTheme + MovaraColors
```
