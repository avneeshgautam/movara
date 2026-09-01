# Movara backend

Spring Boot 3 / Java 17 REST API for logging workouts (sets, reps, weight per exercise).

## Run

Requires a local Maven install (`brew install maven`) and Java 17+, plus a
MongoDB to point at — either MongoDB Atlas (cloud) or a local `mongod`.

```bash
cd backend

# Option A: local mongod (mongodb://localhost:27017/movara is the default)
mvn spring-boot:run

# Option B: your Atlas cluster (do NOT paste the URI into any file)
MONGODB_URI="mongodb+srv://USER:PASS@cluster0.xxxx.mongodb.net/movara" mvn spring-boot:run
```

The API comes up on `http://localhost:8080`. Data is stored in MongoDB and
**persists** across restarts. The connection string is read from the
`MONGODB_URI` environment variable (see `src/main/resources/application.yml`);
it holds your password, so it is never committed.

## Endpoints

| Method | Path                       | Description                                   |
|--------|----------------------------|------------------------------------------------|
| GET    | `/api/exercises`           | List all exercises                              |
| POST   | `/api/exercises`           | Create an exercise `{ name, category }`         |
| GET    | `/api/workout-entries`     | List logged sets, newest first (`?date=` filter)|
| POST   | `/api/workout-entries`     | Log a set `{ exerciseName, sets, reps, weightKg, performedAt, notes }` |
| DELETE | `/api/workout-entries/{id}`| Delete a logged set                             |

A few exercises (Push-ups, Squats, Bench Press, ...) are seeded on first run
— see `ExerciseSeeder`.

## Layout

```
exercise/   Exercise document, repository, controller
workout/    WorkoutEntry document + DTOs, repository, service, controller
config/     CORS setup for the Flutter client
```

Documents are stored in two collections: `exercises` (backs the autocomplete
list, unique index on `name`) and `workout_entries` (each set, with the
exercise name stored denormalized -- MongoDB has no SQL joins). IDs are Mongo
ObjectId strings.

## Deploy

Built as a Docker image ([Dockerfile](Dockerfile)) — Render has no native
Java runtime. The blueprint is [render.yaml](../render.yaml) at the **repo
root** (Render only looks there; its `rootDir: backend` points back here).

Configured entirely by environment variable:

| Variable          | Purpose                                            |
|-------------------|----------------------------------------------------|
| `MONGODB_URI`     | MongoDB connection string, including the `/movara` db name |
| `PORT`            | Injected by the host; defaults to 8080 locally      |
| `ALLOWED_ORIGINS` | Comma-separated CORS origins for the deployed frontend |

⚠️ There is no authentication yet — anyone with the URL can read or delete
entries. Data now persists in MongoDB, so an open API means persistent data
anyone can modify. Add auth before sharing the URL.

## Next steps

- Add auth (Spring Security + JWT) once there's more than one user.
- Add `WorkoutEntryServiceTest` / `WorkoutEntryControllerTest` with
  `spring-boot-starter-test` (already on the classpath).
