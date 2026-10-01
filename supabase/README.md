# Community backend setup (Supabase) — owner guide

The Community tab is live: posts, votes, nested comments and photo uploads
run on Supabase. The app ships with empty credentials, so until you do the
steps below it shows a "backend not connected" notice (tests use seeded
fake data and are unaffected).

You need: a free Supabase account (https://supabase.com) — ~15 minutes.

## 1. Create the project
1. Supabase Dashboard → **New project** (any name/region, free plan).
2. Wait for provisioning. Open **Project Settings → API** and keep this tab:
   you need the **Project URL** (`https://xyzcompany.supabase.co`) and the
   **anon public** key (`eyJhbG...`, the short one — NEVER the service_role
   secret).

## 2. Create tables + policies (copy-paste)
1. Open **SQL Editor → New query**.
2. Paste the entire contents of `supabase/schema.sql` from this repo.
3. **Run.** It creates `community_posts`, `community_comments`,
   `community_votes`, `community_comment_votes`, enables realtime on all
   four, and adds row-level policies (see security note below).

## 3. Create the image bucket
1. **Storage → New bucket**: name `community-images`, **Public: ON**.
2. The bucket policies are already in `schema.sql` (public read, app upload).

## 4. Confirm realtime
**Database → Replication**: the four `community_*` tables must show as
enabled (the SQL does this; verify the toggles are on, otherwise live
updates won't push and the app falls back to refetch-on-open).

## 5. Give the keys to the app (pick ONE)
- **Option A — no secrets in git (recommended):** build with
  ```
  flutter build apk --release \
    --dart-define=SUPABASE_URL=https://xyzcompany.supabase.co \
    --dart-define=SUPABASE_ANON_KEY=eyJhbG...
  ```
- **Option B — bake into source:** edit
  `lib/community/supabase_config.dart` defaults (anyone with the APK can
  read them back — acceptable for the anon key, it is public by design).

Rebuild + reinstall. Open Community → post something → watch it appear.

## 6. Verify it end to end
1. Post from the app (with and without a photo).
2. Open **Table Editor → community_posts**: your row is there with your
   UCP email as author.
3. Vote + comment from a second device/emulator: both screens update live
   without pull-to-refresh (realtime channel `campus-community`).
4. **Storage → community-images**: uploaded photos appear as public files.

## Security notes (read once)
- The app authenticates users via Odoo/Microsoft, NOT Supabase Auth, so
  the SQL policies allow the anon key to read/write community rows. Abuse
  safety = anon-key rate limits + every row tagged with the author's
  verified `@ucp.edu.pk` email. Good for a campus pilot.
- Later hardening path: add Supabase Auth (e.g. sign-in with the same
  Microsoft tenant) and tighten policies with `auth.jwt()`.
- Never put the `service_role` key in the app. Ever.

## If something doesn't work
| Symptom | Check |
|---|---|
| "backend not connected" notice | URL/key missing at build time |
| Empty feed, no error | RLS policies missing (re-run schema.sql) |
| Posts work, no live updates | Replication toggles off (step 4) |
| Photo upload fails | Bucket name must be exactly `community-images`, Public ON |
| `permission denied` in Table Editor | Policy for that table/operation missing |
