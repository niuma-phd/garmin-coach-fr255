# coach-tools — cloud-side customization

The watch face is installed over **USB** and is untouchable by any cloud API.
But the same Garmin account that feeds the face its data can also be scripted to
**push structured training to the watch**. That is what lives here.

| Script | What it does | API used |
|---|---|---|
| `push_workout.py` | Build a Zone-2 HR-targeted run (warmup / main / cooldown) and upload (optionally schedule) it to your watch | `garminconnect.upload_workout` / `schedule_workout` |

## Setup

```bash
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
```

You need a **saved Garmin token** (`garmin_tokens.json`). This repo does **not**
log in for you — create the token once on a machine where you can type your
password + MFA, then point `--tokens` at the directory holding it. China-region
(国行) accounts must pass `--cn` (they route through `connect.garmin.cn`).

```bash
# dry run — just see the workout JSON, upload nothing:
python push_workout.py --dry-run

# upload a 10/30/5 min Zone-2 run (HR 136–150) to a 国行 account:
python push_workout.py --cn --zone2-low 136 --zone2-high 150

# upload AND schedule for a date:
python push_workout.py --cn --schedule 2026-06-22
```

After upload, open Garmin Connect on your phone to sync; the workout then shows
up on the FR255 under **Training > Workouts**.

## Honest caveats

- **Unofficial API.** `garminconnect` wraps a reverse-engineered "workout-service"
  endpoint. It is not supported by Garmin and the JSON schema can change.
- **Tokens are on borrowed time.** New logins via `garth`/`garminconnect` have
  been broken since ~2026-03 (Cloudflare 429; 国行 SSO still hardcoded to `.com`).
  Your scripts keep working only while the saved token is valid (~1 year). **Back
  up `garmin_tokens.json` and do not loop the login endpoint** (that triggers a
  multi-hour account ban).
- **What the cloud API can / cannot do:** ✅ workouts (create/upload/schedule/
  delete), ✅ read all health data, ✅ `add_weigh_in`. ❌ create training plans
  (read-only), ❌ upload navigable courses, ❌ **anything to do with Connect IQ /
  watch faces** — those are USB-sideload / store only.
