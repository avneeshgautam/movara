# Movara backend

FastAPI + MongoDB REST API for logging workouts (sets, reps, weight per
exercise). Python was chosen over the original Java/Spring Boot service so
ML work can live alongside the API later.

## Run

Requires Python 3.12+ and a MongoDB to point at — MongoDB Atlas or a local
`mongod`.

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt

# Option A: local mongod (mongodb://localhost:27017/movara is the default)
.venv/bin/uvicorn app.main:app --reload --port 8080

# Option B: your Atlas cluster (do NOT paste the URI into any committed file)
MONGODB_URI="mongodb+srv://USER:PASS@cluster0.xxxx.mongodb.net/movara" \
  .venv/bin/uvicorn app.main:app --reload --port 8080
```

Or copy your URI into the gitignored `run-local.sh` and just run `./run-local.sh`.

Interactive API docs are served at `http://localhost:8080/docs`.

## Endpoints

Identical to the previous Java service — the Flutter client needs no changes.

| Method | Path                        | Description                                     |
|--------|-----------------------------|-------------------------------------------------|
| GET    | `/api/exercises`            | List all exercises                               |
| POST   | `/api/exercises`            | Create an exercise `{ name, category }` (existing name is returned, not duplicated) |
| GET    | `/api/workout-entries`      | List logged sets, newest first (`?date=` filter) |
| POST   | `/api/workout-entries`      | Log a set `{ exerciseName, sets, reps, weightKg, performedAt, notes }` |
| DELETE | `/api/workout-entries/{id}` | Delete a logged set                              |

IDs are MongoDB ObjectId strings. Invalid payloads return **400** (FastAPI's
default 422 is remapped) to match the old contract.

A few exercises (Push-ups, Squats, Bench Press, ...) are seeded on first run.

## Layout

```
app/
  main.py       FastAPI app, CORS, validation-error mapping
  config.py     Environment configuration
  db.py         Mongo client, indexes, seeding, date coercion
  models.py     Pydantic request/response models
  routers/      exercises.py, workout_entries.py
tests/          Tests that need no database
```

Two collections: `exercises` (unique index on `name`, backs autocomplete) and
`workout_entries` (one document per logged set, with the exercise name stored
denormalized — MongoDB has no SQL joins).

`performedAt` is stored as a BSON date at midnight, the same mapping Spring
Data used for `LocalDate`, so documents written by the old Java backend are
read and written unchanged.

## Test

```bash
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest tests -q
```

These cover validation, date coercion and CORS pattern handling without
needing a database. Full CRUD was verified against a real local `mongod`.

## Deploy

Built as a Docker image ([Dockerfile](Dockerfile)) — the blueprint is
[render.yaml](../render.yaml) at the **repo root**, with `rootDir: backend`.

| Variable          | Purpose                                                |
|-------------------|--------------------------------------------------------|
| `MONGODB_URI`     | MongoDB connection string, including the `/movara` db name |
| `PORT`            | Injected by the host; defaults to 8080 locally          |
| `ALLOWED_ORIGINS` | Comma-separated CORS origins; `*` wildcards supported   |

⚠️ There is no authentication yet — anyone with the URL can read or delete
entries. Add auth before sharing the URL.

## Next steps

- Add auth (e.g. FastAPI security dependencies) once there's more than one user.
- ML: with Python in place, training/inference can live in this service or a
  sibling module sharing the same MongoDB.
