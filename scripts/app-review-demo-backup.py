#!/usr/bin/env python3
"""Write a same-day R3hab JSON backup for the App Review screen recording.

The App Store binary has no demo seed. Settings → Seed sample week is
compiled only into Debug builds. This file is imported with
Settings → Import JSON backup → Replace all data.

Generate it on the iPhone's calendar day, in the same time zone as the phone.
Noon local dates keep each row on the intended day after import.

The fixture is sample logging data:
- Seven morning scores of 2, so the 7-day Progress read is steady pain.
- Three seated-extension HSR sessions. Volume is higher in the recent half.
- The newest session is two days ago, still 24h Pending, pain during 6.
  That is above ProgressionEngine's pain gate of 5, so Today's next
  prescription steps back from 3×10 @ 35 lb to 3×8 @ 35 lb.
- Older resolved responses are Better/Same, so Resolve → Worse suggests
  Soft cut (not Hard drop).

Stdout is the JSON. Expected on-screen strings go to stderr.
"""

from __future__ import annotations

import json
import sys
import uuid
from datetime import datetime, timedelta, timezone


def local_noon(offset_days: int, now: datetime) -> datetime:
    day = (now + timedelta(days=offset_days)).date()
    return datetime(day.year, day.month, day.day, 12, 0, 0, tzinfo=now.tzinfo)


def iso_z(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def day_key(moment: datetime) -> str:
    return moment.astimezone().strftime("%Y-%m-%d")


def set_id(session_id: str, label: str) -> str:
    return str(uuid.uuid5(uuid.UUID(session_id), label))


def pair(session_id: str, reps: int, load: float, label: str) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for side in ("left", "right"):
        rows.append(
            {
                "id": set_id(session_id, f"{label}-{side}"),
                "reps": reps,
                "loadLbs": load,
                "isWarmup": False,
                "side": side,
            }
        )
    return rows


def warmup(session_id: str, load: float) -> dict[str, object]:
    return {
        "id": set_id(session_id, "warmup"),
        "reps": 2,
        "loadLbs": load,
        "holdSeconds": 30,
        "isWarmup": True,
    }


def work_sets(session_id: str, reps: int, load: float) -> list[dict[str, object]]:
    sets: list[dict[str, object]] = [warmup(session_id, load)]
    for set_index in range(1, 4):
        sets.extend(pair(session_id, reps, load, f"set-{set_index}"))
    return sets


def session(
    *,
    session_id: str,
    when: datetime,
    created: datetime,
    reps: int,
    load: float,
    pain_during: int,
    response: str,
    decision: str | None,
    resolved: datetime | None,
) -> dict[str, object]:
    row: dict[str, object] = {
        "id": session_id,
        "date": iso_z(when),
        "phase": "C",
        "type": "hsrStrength",
        "whatIDid": "Seated extension",
        "painDuring": pain_during,
        "painAfter": 2,
        "sets": 3,
        "reps": reps,
        "loadLbs": load,
        "resistanceSets": work_sets(session_id, reps, load),
        "response24h": response,
        "notes": "",
        "snoozeUsed": False,
        "createdAt": iso_z(created),
        "isDraft": False,
    }
    if decision is not None:
        row["decision"] = decision
    if resolved is not None:
        row["resolvedAt"] = iso_z(resolved)
    return row


def check_in(when: datetime, steps: int) -> dict[str, object]:
    return {
        "dayKey": day_key(when),
        "date": iso_z(when),
        "restingPainAM": 2,
        "dailyPainPM": 2,
        "steps": steps,
        "phase": "C",
        "notes": "",
    }


def build(now: datetime | None = None) -> dict[str, object]:
    clock = now or datetime.now().astimezone()
    today = local_noon(0, clock)
    phase_start = local_noon(-21, clock)

    # Dates are local offsets from the generation day.
    # D-6 and D-3 are resolved. D-2 stays Pending so Today leads with 24h.
    # D-2's createdAt is D-4 so a new log the same day is past the 48h spacing hint.
    d6 = local_noon(-6, clock)
    d3 = local_noon(-3, clock)
    d2 = local_noon(-2, clock)

    sessions = [
        session(
            session_id="11111111-1111-4111-8111-111111111111",
            when=d6,
            created=d6,
            reps=8,
            load=20,
            pain_during=2,
            response="same",
            decision="stay",
            resolved=local_noon(-5, clock),
        ),
        session(
            session_id="22222222-2222-4222-8222-222222222222",
            when=d3,
            created=d3,
            reps=8,
            load=30,
            pain_during=2,
            response="better",
            decision="stay",
            resolved=local_noon(-2, clock),
        ),
        session(
            session_id="33333333-3333-4333-8333-333333333333",
            when=d2,
            created=local_noon(-4, clock),
            reps=10,
            load=35,
            pain_during=6,
            response="pending",
            decision=None,
            resolved=None,
        ),
    ]

    steps = [6400, 7100, 6800, 7500, 6200, 8000, 7000]
    check_ins = [
        check_in(local_noon(-6 + offset, clock), steps[offset]) for offset in range(7)
    ]

    return {
        "schemaVersion": 6,
        "exportedAt": iso_z(clock),
        "settings": {
            "currentPhase": "C",
            "phaseChangedAt": iso_z(phase_start),
            "phaseAPainThreshold": 2,
            "phaseAStableDaysRequired": 3,
            "stepNearNormalMin": 6000,
            "stepBaselineTypical": 7500,
            "amReminderHour": 8,
            "amReminderMinute": 0,
            "pmReminderHour": 18,
            "pmReminderMinute": 30,
            "notificationsEnabled": False,
            "protocolRevision": "v1.2 · 2026-09-11",
            "selectedInjuryID": "patellar-tendinopathy",
            "primaryLoadID": "seated-extension",
        },
        "dailyCheckIns": check_ins,
        "trainingSessions": sessions,
        "today": day_key(today),
    }


def assert_story(payload: dict[str, object]) -> None:
    """Fail the script if the fixture drifts from the recording script."""
    sessions = payload["trainingSessions"]
    assert isinstance(sessions, list)
    for row in sessions:
        uuid.UUID(str(row["id"]))
        sets = row["resistanceSets"]
        assert isinstance(sets, list)
        for item in sets:
            uuid.UUID(str(item["id"]))
    pending = [row for row in sessions if row["response24h"] == "pending"]
    assert len(pending) == 1
    latest = pending[0]
    assert latest["painDuring"] == 6
    assert latest["reps"] == 10
    assert latest["loadLbs"] == 35
    # Newest resolved prior is Better, so Worse suggests Soft cut, not Hard drop.
    resolved = [row for row in sessions if row["response24h"] in ("better", "same", "worse")]
    assert resolved[-1]["response24h"] == "better"

    check_ins = payload["dailyCheckIns"]
    assert isinstance(check_ins, list) and len(check_ins) == 7
    assert all(row["restingPainAM"] == 2 for row in check_ins)
    assert check_ins[-1]["dayKey"] == payload["today"]

    # Bilateral work volume: 3 sets × 2 sides × reps × lb.
    # 7-day window early half is the first session only; late half is the other two.
    early = 3 * 2 * 8 * 20
    late = (3 * 2 * 8 * 30) + (3 * 2 * 10 * 35)
    assert late / early >= 1.10


def main() -> None:
    payload = build()
    assert_story(payload)
    today = payload.pop("today")
    json.dump(payload, sys.stdout, indent=2)
    sys.stdout.write("\n")
    print(
        "\n".join(
            [
                f"Recording day {today}. Import this file today, same time zone as the iPhone.",
                "After Replace, expect:",
                "  Progress (7): You're doing well. Volume is up and pain is holding steady.",
                "  Today gold button: Resolve 24h response (Needs your 24h call).",
                "  Seated extension row: 8 @ 35 lbs (stepped back from the pending 3×10).",
                "  Resolve → Worse → Soft cut, then Save → Take the next session easier.",
                "  After Got it: Log seated extension / Today: 3×8 @ 35 lbs.",
                "  Import alert counts: Check-ins: 7, sessions: 3.",
            ]
        ),
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
