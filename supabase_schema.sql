-- Rüpü — esquema inicial para Supabase (Postgres + Auth + Storage)
-- Pegar completo en: Supabase → SQL Editor → New query → Run

-- 1) Perfiles (uno por usuario autenticado)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  name text not null,
  bio text default '',
  avatar_url text,
  level int default 1,
  xp int default 0,
  created_at timestamptz default now()
);

-- 2) Lugares (los curados de la app + los que creen los usuarios)
create table public.places (
  id text primary key,
  name text not null,
  cat text not null,
  cats text[] not null default '{}',
  city text,
  lat double precision not null,
  lon double precision not null,
  description text,
  photo_url text,
  created_by uuid references public.profiles(id),
  created_at timestamptz default now()
);

-- 3) Publicaciones
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  place_id text references public.places(id),
  location_text text,
  cat text,
  caption text,
  photo_url text,
  lat double precision,
  lon double precision,
  created_at timestamptz default now()
);

-- 4) Likes
create table public.likes (
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (post_id, user_id)
);

-- 5) Comentarios
create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz default now()
);

-- 6) Seguidores
create table public.follows (
  follower_id uuid references public.profiles(id) on delete cascade,
  followee_id uuid references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (follower_id, followee_id)
);

-- 7) Galería personal ("Mis fotos")
create table public.my_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  url text not null,
  created_at timestamptz default now()
);

-- ===================== SEGURIDAD (Row Level Security) =====================
alter table public.profiles enable row level security;
alter table public.places enable row level security;
alter table public.posts enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.follows enable row level security;
alter table public.my_photos enable row level security;

-- Perfiles: todos pueden leer (red social pública), cada uno edita solo el suyo
create policy "profiles_select_all" on public.profiles for select using (true);
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- Lugares: lectura pública; cualquier usuario autenticado puede crear; solo el creador edita/borra el suyo
create policy "places_select_all" on public.places for select using (true);
create policy "places_insert_auth" on public.places for insert with check (auth.uid() = created_by);
create policy "places_update_own" on public.places for update using (auth.uid() = created_by);
create policy "places_delete_own" on public.places for delete using (auth.uid() = created_by);

-- Publicaciones: lectura pública; cada usuario solo crea/edita/borra las suyas
create policy "posts_select_all" on public.posts for select using (true);
create policy "posts_insert_own" on public.posts for insert with check (auth.uid() = user_id);
create policy "posts_update_own" on public.posts for update using (auth.uid() = user_id);
create policy "posts_delete_own" on public.posts for delete using (auth.uid() = user_id);

-- Likes: lectura pública; cada usuario solo da/quita like como sí mismo
create policy "likes_select_all" on public.likes for select using (true);
create policy "likes_insert_own" on public.likes for insert with check (auth.uid() = user_id);
create policy "likes_delete_own" on public.likes for delete using (auth.uid() = user_id);

-- Comentarios: lectura pública; cada usuario solo comenta/borra como sí mismo
create policy "comments_select_all" on public.comments for select using (true);
create policy "comments_insert_own" on public.comments for insert with check (auth.uid() = user_id);
create policy "comments_delete_own" on public.comments for delete using (auth.uid() = user_id);

-- Seguidores
create policy "follows_select_all" on public.follows for select using (true);
create policy "follows_insert_own" on public.follows for insert with check (auth.uid() = follower_id);
create policy "follows_delete_own" on public.follows for delete using (auth.uid() = follower_id);

-- Mis fotos: cada usuario ve y gestiona solo las suyas
create policy "my_photos_select_own" on public.my_photos for select using (auth.uid() = user_id);
create policy "my_photos_insert_own" on public.my_photos for insert with check (auth.uid() = user_id);
create policy "my_photos_delete_own" on public.my_photos for delete using (auth.uid() = user_id);

-- ===================== STORAGE (fotos) =====================
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true);
insert into storage.buckets (id, name, public) values ('posts', 'posts', true);

create policy "avatars_public_read" on storage.objects for select using (bucket_id = 'avatars');
create policy "avatars_own_write" on storage.objects for insert with check (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "avatars_own_delete" on storage.objects for delete using (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "posts_photos_public_read" on storage.objects for select using (bucket_id = 'posts');
create policy "posts_photos_own_write" on storage.objects for insert with check (bucket_id = 'posts' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "posts_photos_own_delete" on storage.objects for delete using (bucket_id = 'posts' and auth.uid()::text = (storage.foldername(name))[1]);
