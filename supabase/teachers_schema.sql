-- ============================================================
-- Teacher reviews (StudentSpace parsed data)
-- Run AFTER supabase/schema.sql in: Supabase Dashboard -> SQL Editor.
-- Stores 706 teachers + student ratings (grading/leniency/subject 1..5).
-- App identity is Odoo/Microsoft email (no Supabase Auth), same model
-- as community_* tables: open read, authenticated writes via Node API
-- which verifies x-ucp-session against Odoo.
-- ============================================================

create table if not exists public.teachers (
  slug text primary key,
  name text not null,
  designation text not null default '',
  department_code text not null default '',
  department_name text not null default '',
  department_id int not null default 0,
  image_url text not null default '',
  bio text not null default '',
  overall_rating double precision not null default 0,
  review_count int not null default 0,
  grading_pct int not null default 0,
  leniency_pct int not null default 0,
  subject_pct int not null default 0,
  avg_grading double precision not null default 0,
  avg_leniency double precision not null default 0,
  avg_subject double precision not null default 0,
  profile_url text not null default '',
  updated_at timestamptz not null default now()
);
create index if not exists teachers_dept_idx
  on public.teachers (department_code, overall_rating desc);
create index if not exists teachers_rating_idx
  on public.teachers (overall_rating desc, review_count desc);
create index if not exists teachers_name_idx
  on public.teachers using gin (to_tsvector('english', name));

create table if not exists public.teacher_reviews (
  id bigint generated always as identity primary key,
  teacher_slug text not null references public.teachers (slug)
    on delete cascade,
  student_name text not null default 'student',
  author_email text not null default '',
  comment text not null default '' check (char_length(comment) <= 2000),
  rating_grading smallint not null check (rating_grading between 1 and 5),
  rating_leniency smallint not null check (rating_leniency between 1 and 5),
  rating_subject smallint not null check (rating_subject between 1 and 5),
  is_blocked boolean not null default false,
  source_id bigint,
  created_at timestamptz not null default now()
);
create index if not exists teacher_reviews_slug_idx
  on public.teacher_reviews (teacher_slug, created_at desc);

-- Realtime for live rating updates.
alter publication supabase_realtime add table public.teachers;
alter publication supabase_realtime add table public.teacher_reviews;

-- RLS: same posture as community_* (open read, open write; Node API
-- enforces Odoo session + validation, anon key is rate-limited).
alter table public.teachers enable row level security;
alter table public.teacher_reviews enable row level security;

create policy "campus read teachers" on public.teachers
  for select using (true);
create policy "campus write teachers" on public.teachers
  for insert with check (true);
create policy "campus update teachers" on public.teachers
  for update using (true) with check (true);
create policy "campus delete teachers" on public.teachers
  for delete using (true);

create policy "campus read teacher reviews" on public.teacher_reviews
  for select using (true);
create policy "campus write teacher reviews" on public.teacher_reviews
  for insert with check (true);
create policy "campus update teacher reviews" on public.teacher_reviews
  for update using (true) with check (true);
create policy "campus delete teacher reviews" on public.teacher_reviews
  for delete using (true);
