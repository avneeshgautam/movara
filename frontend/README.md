# Movara frontend

Flutter app for logging workouts against the [Movara backend](../backend).

## Setup

The `web/` platform folder has been generated, so the app builds and runs on
Chrome as-is. To target other platforms, generate their scaffolding once:

```bash
flutter create --platforms=android,ios,macos .
```

This only adds missing platform folders — it leaves `lib/` alone.

## Run

Start the [backend](../backend) first, then:

```bash
flutter run -d chrome   # runs as a web app
# or
flutter run              # runs on a connected device / simulator
```

The app talks to `http://localhost:8080/api` by default. On an Android
emulator this is automatically switched to `10.0.2.2` (see
`lib/services/api_config.dart`). To point at a backend on another machine:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8080/api
```

## Layout

```
lib/
  models/     Exercise, WorkoutEntry — mirror the backend DTOs
  services/   api_service.dart (HTTP calls), api_config.dart (base URL)
  screens/    home_screen.dart (list + delete), add_entry_screen.dart (log a set)
  widgets/    workout_entry_card.dart, empty_state.dart
  theme/      app_theme.dart — single place to restyle the app
```

## Test

```bash
flutter test
```

Covers `WorkoutEntry` JSON round-tripping (including the date format the
backend's `LocalDate` requires) and `WorkoutEntryCard` rendering.

## Next steps

- Add a chart/summary view (reps or volume over time).
- State management (Provider/Riverpod) once screens/state grow past
  `FutureBuilder` + `setState`.
- Persist auth token / user identity once the backend has auth.
- Exercise picker: turn `POST /api/exercises` into a "create new exercise"
  flow from the Autocomplete field.
