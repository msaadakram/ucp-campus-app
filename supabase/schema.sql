-- ============================================================
-- UCP Campus community backend (Supabase / Postgres)
-- Run this whole file once in: Supabase Dashboard -> SQL Editor.
-- Then follow supabase/README.md (bucket + anon key + realtime note).
-- ============================================================

-- UUIDs for primary keys (built into Postgres 13+).
-- No extension needed.

-- ---------- tables ----------
create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  author_email text not null,
  author_name text not null,
  title text not null check (char_length(title) between 1 and 120),
  body text not null default '',
  flair text not null default 'Study'
    check (flair in ('Study', 'Events', 'Help', 'Memes', 'Marketplace')),
  image_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.community_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts (id)
    on delete cascade,
  parent_id uuid references public.community_comments (id)
    on delete cascade,
  author_email text not null,
  author_name text not null,
  text text not null check (char_length(text) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists community_comments_post_idx
  on public.community_comments (post_id, created_at);

create table if not exists public.community_votes (
  post_id uuid not null references public.community_posts (id)
    on delete cascade,
  author_email text not null,
  value smallint not null check (value in (1, -1)),
  primary key (post_id, author_email)
);

create table if not exists public.community_comment_votes (
  comment_id uuid not null references public.community_comments (id)
    on delete cascade,
  author_email text not null,
  value smallint not null check (value in (1, -1)),
  primary key (comment_id, author_email)
);

-- ---------- realtime ----------
-- Live feed updates need these tables in the realtime publication.
-- (Also enable: Dashboard -> Database -> Replication for each table.)
alter publication supabase_realtime add table public.community_posts;
alter publication supabase_realtime add table public.community_comments;
alter publication supabase_realtime add table public.community_votes;
alter publication supabase_realtime add table public.community_comment_votes;

-- ---------- row level security ----------
-- The app signs users in via Odoo/Microsoft, NOT via Supabase Auth, so
-- there is no auth.uid() to check against. These policies keep the public
-- anon key to least privilege it can use: read everything, write rows
-- (abuse safety comes from the anon key being rate-limited + the app
-- tagging every row with the author's verified UCP email).
-- If you later add Supabase Auth, tighten these with auth.jwt() checks.
alter table public.community_posts enable row level security;
alter table public.community_comments enable row level security;
alter table public.community_votes enable row level security;
alter table public.community_comment_votes enable row level security;

create policy "campus read posts" on public.community_posts
  for select using (true);
create policy "campus write posts" on public.community_posts
  for insert with check (true);
create policy "campus update posts" on public.community_posts
  for update using (true) with check (true);
create policy "campus delete posts" on public.community_posts
  for delete using (true);

create policy "campus read comments" on public.community_comments
  for select using (true);
create policy "campus write comments" on public.community_comments
  for insert with check (true);
create policy "campus update comments" on public.community_comments
  for update using (true) with check (true);
create policy "campus delete comments" on public.community_comments
  for delete using (true);

create policy "campus read votes" on public.community_votes
  for select using (true);
create policy "campus write votes" on public.community_votes
  for insert with check (true);
create policy "campus update votes" on public.community_votes
  for update using (true) with check (true);
create policy "campus delete votes" on public.community_votes
  for delete using (true);

create policy "campus read comment votes" on public.community_comment_votes
  for select using (true);
create policy "campus write comment votes" on public.community_comment_votes
  for insert with check (true);
create policy "campus update comment votes" on public.community_comment_votes
  for update using (true) with check (true);
create policy "campus delete comment votes" on public.community_comment_votes
  for delete using (true);

-- ---------- storage ----------
-- Create the bucket in Dashboard -> Storage -> New bucket:
--   name: community-images, Public: ON.
-- Then run the policy below (storage.objects policies):
create policy "campus public read images"
  on storage.objects for select using (bucket_id = 'community-images');
create policy "campus upload images"
  on storage.objects for insert with check (bucket_id = 'community-images');
create policy "campus delete images"
  on storage.objects for delete using (bucket_id = 'community-images');
