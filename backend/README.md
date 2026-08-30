# Movara backend

Spring Boot 3 / Java 17 REST API for logging workouts (sets, reps, weight per exercise).

## Run

Requires a local Maven install (`brew install maven`) and Java 17+.

```bash
cd backend
mvn spring-boot:run
```

The API comes up on `http://localhost:8080`, backed by an in-memory H2
database (data resets on every restart — swap this for Postgres later, see
`src/main/resources/application.yml`). The H2 console is at
`http://localhost:8080/h2-console` (JDBC URL `jdbc:h2:mem:movara`, user `sa`,
empty password).

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
exercise/   Exercise entity, repository, controller
workout/    WorkoutEntry entity + DTOs, repository, service, controller
config/     CORS setup for the Flutter client
```

## Deploy

Built as a Docker image ([Dockerfile](Dockerfile)) — Render has no native
Java runtime. The blueprint is [render.yaml](../render.yaml) at the **repo
root** (Render only looks there; its `rootDir: backend` points back here).

Configured entirely by environment variable:

| Variable          | Purpose                                            |
|-------------------|----------------------------------------------------|
| `PORT`            | Injected by the host; defaults to 8080 locally      |
| `ALLOWED_ORIGINS` | Comma-separated CORS origins for the deployed frontend |

⚠️ Still H2 in-memory: **all data is lost on every restart, sleep, or
redeploy**, and there is no authentication — anyone with the URL can read
or delete entries.

## Next steps

- Swap H2 for Postgres (add `spring-boot-starter-data-jpa` driver + update
  `application.yml`, run via Docker Compose).
- Add auth (Spring Security + JWT) once there's more than one user.
- Add `WorkoutEntryServiceTest` / `WorkoutEntryControllerTest` with
  `spring-boot-starter-test` (already on the classpath).
