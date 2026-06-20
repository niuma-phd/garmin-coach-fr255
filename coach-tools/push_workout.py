#!/usr/bin/env python3
"""Push a structured Zone-2 run workout to your Garmin Forerunner 255.

This is the "customization toolkit" half of the project: it shows how the
*cloud* side complements the watch face. A watch face is installed over USB and
cannot be touched by the cloud API — but the cloud API CAN push a structured
workout that your watch will then guide you through step by step.

It reuses an EXISTING Garmin Connect session (saved tokens). It does NOT log in
with a password — generate the token file once yourself (see the project README)
and point --tokens at it. China-region (国行) accounts must pass --cn.

  IMPORTANT, read once:
  - The Garmin "workout-service" JSON below is a REVERSE-ENGINEERED schema used
    by the unofficial `garminconnect` library. It is not an official API and can
    change without notice. Treat this as experimental.
  - Your saved token is on borrowed time: `garth`/`garminconnect` new logins are
    broken since ~2026-03 (Cloudflare 429; 国行 SSO hardcoded to .com). Back up
    your token file and avoid re-login loops.

Examples:
  # Just print the workout JSON, upload nothing:
  python push_workout.py --dry-run

  # Upload a 10/30/5-min warmup/Zone2/cooldown run (HR 136-150) to your account:
  python push_workout.py --cn --zone2-low 136 --zone2-high 150

  # Upload AND schedule it for a date:
  python push_workout.py --cn --schedule 2026-06-22
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Garmin workout-service enum ids (reverse-engineered, stable for years).
SPORT_RUNNING = {"sportTypeId": 1, "sportTypeKey": "running"}
STEP_WARMUP = {"stepTypeId": 1, "stepTypeKey": "warmup"}
STEP_COOLDOWN = {"stepTypeId": 2, "stepTypeKey": "cooldown"}
STEP_INTERVAL = {"stepTypeId": 3, "stepTypeKey": "interval"}
END_TIME = {"conditionTypeId": 2, "conditionTypeKey": "time"}
TARGET_NONE = {"workoutTargetTypeId": 1, "workoutTargetTypeKey": "no.target"}
TARGET_HR = {"workoutTargetTypeId": 4, "workoutTargetTypeKey": "heart.rate.zone"}


def _step(order: int, step_type: dict, secs: int, *, hr_low: int | None = None,
          hr_high: int | None = None) -> dict:
    step = {
        "type": "ExecutableStepDTO",
        "stepOrder": order,
        "stepType": step_type,
        "endCondition": END_TIME,
        "endConditionValue": float(secs),
        "targetType": TARGET_NONE,
    }
    if hr_low is not None and hr_high is not None:
        # Custom bpm range: targetValueOne = low, targetValueTwo = high.
        step["targetType"] = TARGET_HR
        step["targetValueOne"] = float(hr_low)
        step["targetValueTwo"] = float(hr_high)
        step["zoneNumber"] = None
    return step


def build_zone2_run(name: str, warmup_min: int, main_min: int, cooldown_min: int,
                    hr_low: int, hr_high: int) -> dict:
    """Build a warmup -> Zone-2 HR-targeted block -> cooldown running workout."""
    steps = [
        _step(1, STEP_WARMUP, warmup_min * 60),
        _step(2, STEP_INTERVAL, main_min * 60, hr_low=hr_low, hr_high=hr_high),
        _step(3, STEP_COOLDOWN, cooldown_min * 60),
    ]
    total = (warmup_min + main_min + cooldown_min) * 60
    return {
        "sportType": SPORT_RUNNING,
        "workoutName": name,
        "estimatedDurationInSecs": total,
        "workoutSegments": [
            {
                "segmentOrder": 1,
                "sportType": SPORT_RUNNING,
                "workoutSteps": steps,
            }
        ],
    }


def get_client(tokens_dir: str, is_cn: bool):
    from garminconnect import Garmin

    api = Garmin(is_cn=is_cn)
    api.login(str(Path(tokens_dir).expanduser()))
    return api


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--tokens", default="~/.garminconnect",
                   help="dir holding garmin_tokens.json (default: ~/.garminconnect)")
    p.add_argument("--cn", action="store_true",
                   help="China-region account (connect.garmin.cn). Required for 国行.")
    p.add_argument("--name", default="Zone2 Easy Run")
    p.add_argument("--warmup", type=int, default=10, help="warmup minutes")
    p.add_argument("--main", type=int, default=30, help="Zone2 main-block minutes")
    p.add_argument("--cooldown", type=int, default=5, help="cooldown minutes")
    p.add_argument("--zone2-low", type=int, default=136, help="Zone2 HR low (bpm)")
    p.add_argument("--zone2-high", type=int, default=150, help="Zone2 HR high (bpm)")
    p.add_argument("--schedule", metavar="YYYY-MM-DD", default=None,
                   help="also schedule the workout for this date")
    p.add_argument("--dry-run", action="store_true",
                   help="print the workout JSON and exit without uploading")
    args = p.parse_args()

    workout = build_zone2_run(args.name, args.warmup, args.main, args.cooldown,
                              args.zone2_low, args.zone2_high)

    if args.dry_run:
        print(json.dumps(workout, indent=2, ensure_ascii=False))
        return 0

    try:
        api = get_client(args.tokens, args.cn)
    except Exception as e:  # noqa: BLE001 - surface any auth/token problem clearly
        print(f"✗ could not start Garmin session ({type(e).__name__}): {e}")
        print("  Make sure garmin_tokens.json exists and is valid; 国行 needs --cn.")
        return 2

    try:
        resp = api.upload_workout(workout)
    except Exception as e:  # noqa: BLE001
        print(f"✗ upload_workout failed ({type(e).__name__}): {e}")
        print("  The workout-service JSON schema is unofficial and may have shifted.")
        return 3

    workout_id = resp.get("workoutId") if isinstance(resp, dict) else None
    print(f"✓ uploaded workout '{args.name}'"
          + (f" (id={workout_id})" if workout_id else ""))

    if args.schedule and workout_id:
        try:
            api.schedule_workout(workout_id, args.schedule)
            print(f"✓ scheduled for {args.schedule}")
        except Exception as e:  # noqa: BLE001
            print(f"· upload ok but scheduling failed ({type(e).__name__}): {e}")
            return 4

    print("  Now sync your FR255 (open Garmin Connect on the phone) and the "
          "workout will appear under Training > Workouts on the watch.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
