# Teacher reviews (StudentSpace data) — Supabase setup

This adds a **Teachers** page to the app: photo, overall 0–5, separate
Grading / Leniency / Subject % dials, student comments, and a 1–5 rate flow.
Storage is Supabase (`teachers` + `teacher_reviews`), writes go through the
Node API which verifies `x-ucp-session` against Odoo.

## 1. Create tables

In Supabase Dashboard → SQL Editor, run **after** `schema.sql`:

```sql
-- paste supabase/teachers_schema.sql
```

It creates:

- `public.teachers` (pk `slug`, name, designation, dept code/name/id,
  `image_url` (UCP CDN), `overall_rating`, `review_count`,
  `grading_pct/leniency_pct/subject_pct`, `avg_*`, `profile_url`)
- `public.teacher_reviews` (fk `teacher_slug`, anonymous `student_name`,
  `comment` ≤2000, three 1–5 ratings, `is_blocked`, `source_id` = scraped id)
- Realtime added, RLS open-read/open-write (Node enforces auth, same as community)

## 2. Import the parsed 706 + 5102 rows

Files from the scrape (`teachers.json`, `reviews.json`) sit at repo root.

```bash
cd backend
npm install
SUPABASE_URL=https://xyz.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=... \
node scripts/import_teachers.js ../teachers.json ../reviews.json
```

Re-running is safe: teachers upsert on `slug`, reviews skip existing `source_id`.

## 3. Backend

`src/routes/teachers.js` is already mounted in `src/index.js`:

- `GET /api/teachers?dept=foit&q=usman&limit=50`
- `GET /api/teachers/:slug` → `{teacher, reviews[200]}`
- `POST /api/teachers/:slug/rate` (auth) `{grading,leniency,subject 1..5, comment}` —
  inserts + recomputes overall/count/dials.

Deploy the same Node API used for community (`NODE_API_URL`).

## 4. App

New option **Teacher reviews** in the drawer (`lib/app.dart` → `tab='teachers'`):

- `lib/teachers/teacher_models.dart` — `Teacher`, `TeacherReview`
- `lib/teachers/teacher_service.dart` — `NodeTeacherService` + `FakeTeacherService`
- `lib/screens/teachers.dart` — search, 10 faculty filters, Top/Most-reviewed/Name sort,
  photo cards with `Image.network`, detail with 3 dials, comments, `Rate` bottom sheet
  (3x 5-star pickers + optional 500-char comment)

No new permissions. Teacher photos stay on `ucp.edu.pk` CDN (no storage bucket needed).
