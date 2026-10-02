# Community backend setup (Supabase) — owner guide

> Current architecture: the app talks ONLY to the Node API in `backend/`
> (direct app→Supabase access was retired). This Supabase project still
> provides the database, realtime-less storage and the image bucket — the
> Node server holds the keys. Keep this project; the app needs nothing
> from it directly anymore.

The Community tab is live through the Node API: posts, votes, nested
comments and photo uploads. Until the Node URL is baked in, the tab shows
a "backend not connected" notice (tests use seeded fake data and are
unaffected).

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

## 5. Give the keys to the backend (NOT the app)
Put them in the Node server's `.env` (see `backend/README.md`) —
`SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` — then give the *app* only
the Node public base URL (next section). Rebuild + reinstall. Open
Community → post something → watch it appear.

## 5b. Point the app at your Node server
Build with your server's public HTTPS URL (or run a local one for tests):
```
flutter build apk --release --dart-define=NODE_API_URL=https://api.yourdomain.xyz
```
For the Android emulator against a laptop server: `http://10.0.2.2:3001`.
Deploy, verify and troubleshoot steps live in `backend/README.md`.

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
