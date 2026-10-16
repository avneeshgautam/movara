# Movara admin dashboard (local only)

A private dashboard that runs **only on your Mac**: user growth, activity,
per-user detail, and sending notifications to one user or everyone. It is
never deployed and isn't reachable from the app or the internet.

## Run it

```bash
export DATABASE_URL='postgresql://postgres.<project>:PASSWORD@<pooler-host>:5432/postgres'
./admin/run-admin.sh        # opens http://127.0.0.1:8090
```

The launcher requires `DATABASE_URL` so it cannot silently send messages to an
old or different database. Use the same live database connection string as the
deployed backend, not a local development database:

```bash
export DATABASE_URL="postgresql://..."
```

Copy it from Render → movara-backend → Environment → `DATABASE_URL`, or
from Supabase → your project → **Connect** → *Session pooler* (fill in your
database password). Keep it in your shell environment only; never commit or
paste it anywhere. Stop the dashboard with Ctrl+C.

## What it shows

- **Overview** — total users, new this week, active today / 7 days, sets,
  runs, km, notifications sent, and a 60-day user-growth chart.
- **Users** — everyone, searchable: name, status, photo, email*, first seen,
  last active, sets this week / all time, runs and km. Click a user for their
  recent workouts, runs and the messages you've sent them.
- **Notifications** — send a title + message to **everyone** or **one user**,
  and see everything you've sent.

\* Emails and exact sign-up / last sign-in times come from Firebase — see below.

## How notifications reach people

Messages are always saved to the database. With Firebase Cloud Messaging
configured, the app also registers a device token and the admin sends a normal
system notification while the app is backgrounded or closed. If no token is
available, the portal reports that it saved the message for in-app delivery.
The app still checks messages when it opens or returns to the foreground.

## Optional: emails and sign-up times (Firebase)

1. Firebase console → ⚙️ **Project settings** → **Service accounts** →
   **Generate new private key**.
2. Save the downloaded file as **`admin/service-account.json`** (it's
   gitignored — this key has full admin access to the Firebase project, so
   never commit or share it).
3. Install the library once:
   `backend/.venv/bin/pip install firebase-admin`
4. Restart the dashboard. The yellow banner disappears and emails show.

## Safety

- Bound to `127.0.0.1`; requests from any other address are refused.
- Sending requires a custom header that other websites can't add, so a page
  open in your browser can't send notifications through the dashboard.
- It connects to the **live** database: what you send reaches real users.
