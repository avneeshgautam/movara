"""Per-user data isolation, against a real PostgreSQL.

Skipped automatically when no database is reachable, so the default suite
stays DB-free. Run with:
    DATABASE_URL=postgresql://postgres:postgres@localhost:55432/movara \
        pytest tests/test_user_isolation.py
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import delete, select
from sqlalchemy.exc import SQLAlchemyError

from app import db
from app.main import app

from conftest import make_token

client = TestClient(app)


@pytest.fixture(autouse=True)
def require_database():
    try:
        db.init()
    except SQLAlchemyError:
        pytest.skip('no PostgreSQL reachable')

    with db.SessionLocal() as session:
        session.execute(delete(db.WorkoutEntry))
        session.commit()


def headers_for(key, uid):
    return {'Authorization': f'Bearer {make_token(key, sub=uid)}'}


def log_set(key, uid, name='Squats'):
    return client.post(
        '/api/workout-entries',
        json={
            'exerciseName': name,
            'sets': 1,
            'reps': 10,
            'weightKg': 60,
            'performedAt': '2026-09-04',
        },
        headers=headers_for(key, uid),
    )


class TestIsolation:
    def test_entries_are_scoped_to_their_owner(self, local_signing_key):
        created = log_set(local_signing_key, 'alice')
        assert created.status_code == 201

        mine = client.get('/api/workout-entries',
                          headers=headers_for(local_signing_key, 'alice'))
        assert mine.status_code == 200
        assert len(mine.json()) == 1

        theirs = client.get('/api/workout-entries',
                            headers=headers_for(local_signing_key, 'bob'))
        assert theirs.status_code == 200
        assert theirs.json() == [], "bob must not see alice's entries"

    def test_one_user_cannot_delete_anothers_entry(self, local_signing_key):
        entry_id = log_set(local_signing_key, 'alice').json()['id']

        # Bob tries to delete it. The API stays quiet (204) but must not act.
        client.delete(f'/api/workout-entries/{entry_id}',
                      headers=headers_for(local_signing_key, 'bob'))

        still_there = client.get('/api/workout-entries',
                                 headers=headers_for(local_signing_key, 'alice'))
        assert len(still_there.json()) == 1, "bob deleted alice's entry"

        # Alice can delete her own.
        client.delete(f'/api/workout-entries/{entry_id}',
                      headers=headers_for(local_signing_key, 'alice'))
        gone = client.get('/api/workout-entries',
                          headers=headers_for(local_signing_key, 'alice'))
        assert gone.json() == []

    def test_date_filter_stays_scoped(self, local_signing_key):
        log_set(local_signing_key, 'alice')

        theirs = client.get('/api/workout-entries?date=2026-09-04',
                            headers=headers_for(local_signing_key, 'bob'))
        assert theirs.json() == []

    def test_new_entries_record_their_owner(self, local_signing_key):
        log_set(local_signing_key, 'alice')
        with db.SessionLocal() as session:
            row = session.scalar(select(db.WorkoutEntry))
        assert row.user_id == 'alice'
