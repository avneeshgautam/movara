# Movara backend

FastAPI + SQLAlchemy on PostgreSQL, with Firebase ID-token auth. Deployed to
Render from the `main` branch (`render.yaml` at the repo root). Tables,
endpoints, environment variables and the "add an endpoint" recipe are in
**[../docs/DEVELOPER_GUIDE.md](../docs/DEVELOPER_GUIDE.md)** (§6, §8 recipe C,
§11).

## Quick reference

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt -r requirements-dev.txt
./run-local.sh                          # gitignored; sets DATABASE_URL etc.
.venv/bin/python -m pytest tests -q     # DB tests skip without PostgreSQL
```

API docs while running locally: http://localhost:8080/docs

```
app/
  main.py      App, CORS, router registration
  config.py    Environment variables
  auth.py      Firebase ID-token verification
  db.py        Tables + _migrate() column adds + seeding
  models.py    Pydantic request/response models
  routers/     exercises, workout_entries, runs, social, chat
tests/         pytest
```

Every endpoint except the public profile-photo GET requires
`Authorization: Bearer <Firebase ID token>`, and all data is scoped to that
user.
