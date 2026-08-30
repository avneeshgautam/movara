# movara
Move + Vara = Move towards your better self.

A simple workout tracker: log how many reps and sets you did per exercise.

## Structure

```
backend/    Spring Boot REST API (Java 17, H2 in-memory DB for now)
frontend/   Flutter app (mobile + web) that talks to the backend
```

See [backend/README.md](backend/README.md) and
[frontend/README.md](frontend/README.md) for how to run each half.

## Quick start

```bash
# Terminal 1
cd backend && mvn spring-boot:run

# Terminal 2
cd frontend && flutter run -d chrome
```

This is an intentionally minimal first scaffold — one entity for exercises,
one for logged sets, a couple of screens. Extend from here.
