# Movara admin dashboard (local only)

A private dashboard that runs **only on your Mac**: user growth, activity,
per-user detail, and sending notifications to one user or everyone. It is
never deployed and isn't reachable from the app or the internet.

## Run it

```bash
./admin/run-admin.sh        # opens http://127.0.0.1:8090
```

It reads `DATABASE_URL` from `backend/run-local.sh` (gitignored). **One-time
setup:** put the live database's connection string there —

```bash
export DATABASE_URL="postgresql://..."
```

— copied from Render → movara-backend → Environment → `DATABASE_URL`, or
from Supabase → your project → **Connect** → *Session pooler* (fill in your
database password). Keep it in that file only; never commit or paste it
anywhere. Stop the dashboard with Ctrl+C.

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

Messages are saved to the database. The app checks for new ones **when it
opens and whenever it comes back to the foreground**, then shows a
notification and a card at the top of the screen (iPhone, Android and web).

They don't arrive while the app is fully closed — that needs real push
notifications (Firebase Cloud Messaging). On iPhone that also requires the
paid Apple Developer Program; Android can get it on the free plan.

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
