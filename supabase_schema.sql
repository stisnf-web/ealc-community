-- ============================================================================
--  ENGLISH ARABIC LANGUAGE COMMUNITY — "Learn Together, Speak Confidently,
--  Grow Together."
--  Supabase Database Setup untuk SQL Editor — Versi 1.0
-- ============================================================================
--
--  CARA PAKAI (Supabase):
--    1. Buka https://supabase.com/dashboard  ->  pilih project Anda
--    2. Menu sidebar kiri:  SQL Editor  ->  New query
--    3. Paste SELURUH isi file ini  ->  klik Run
--    4. Hasil verifikasi jumlah data muncul di tab "Results" (bagian bawah)
--
--  CATATAN PENTING:
--    - Skrip ini IDEMPOTEN: boleh dijalankan ulang. Tetapi menjalankan ulang
--      berarti SEMUA tabel & data komunitas dihapus lalu dibuat ulang.
--    - Akun login tetap ada di schema auth (tidak dihapus) — profilnya
--      dibuat ulang otomatis bila sudah ada di auth.users.
--    - RLS (Row Level Security) diaktifkan di SEMUA tabel: anon key yang
--      dipakai di frontend AMAN untuk dipublikasikan (mis. di GitHub).
--    - JANGAN PERNAH menyimpan service_role key di frontend / app_settings.
--
--  AKUN DEMO (dibuat di bagian SEED, bagian 9):
--    +----------------------+------------+-----------------------+
--    | Email                | Password   | Role                  |
--    +----------------------+------------+-----------------------+
--    | admin@demo.com       | admin123   | Super Administrator   |
--    | moderator@demo.com   | mod123     | Moderator             |
--    | member@demo.com      | member123  | Member                |
--    +----------------------+------------+-----------------------+
--
--  CONTOH KONEKSI DARI FRONTEND (index.html + supabase-js v2):
--    const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
--
--    // Baca postingan + nama pembuatnya (FK ke profiles):
--    const { data } = await supabase
--      .from('posts')
--      .select('*, profiles(full_name, avatar_url)')
--      .order('created_at', { ascending: false });
--
--    // Tambah poin (RPC — hanya bisa dipanggil oleh admin, dicek di dalam
--    // fungsi database, bukan di frontend):
--    await supabase.rpc('admin_add_points', { p_user_id: '...', p_points: 10 });
--
--    // Upload avatar (bucket 'avatars', wajib di dalam folder UUID user):
--    await supabase.storage.from('avatars')
--      .upload(`${userId}/${fileName}`, file);
-- ============================================================================


-- ============================================================================
--  BAGIAN 0 — PEMBERSIHAN (agar skrip bisa dijalankan ulang dari nol)
--  HATI-HATI: bagian ini menghapus seluruh tabel & data komunitas yang lama.
-- ============================================================================

drop view  if exists public.leaderboard cascade;

drop table if exists
  public.app_settings,
  public.speaking_records,
  public.learning_progress,
  public.user_achievements,
  public.achievements,
  public.notifications,
  public.event_participants,
  public.events,
  public.challenge_submissions,
  public.challenges,
  public.quiz_results,
  public.quiz_questions,
  public.quizzes,
  public.vocabulary,
  public.arabic_materials,
  public.english_materials,
  public.likes,
  public.comments,
  public.posts,
  public.profiles
cascade;

-- Tipe di-drop lebih dulu: cascade otomatis ikut menghapus fungsi yang
-- memakai tipe tersebut pada signature-nya (mis. admin_update_role).
drop type if exists public.user_role cascade;
drop type if exists public.language_type cascade;
drop type if exists public.english_level cascade;
drop type if exists public.arabic_level cascade;
drop type if exists public.material_type cascade;
drop type if exists public.event_type cascade;
drop type if exists public.challenge_type cascade;
drop type if exists public.submission_status cascade;
drop type if exists public.notification_type cascade;

drop function if exists public.set_updated_at() cascade;
drop function if exists public.is_super_admin() cascade;
drop function if exists public.is_admin() cascade;
drop function if exists public.is_staff() cascade;
drop function if exists public.award_points(uuid, int, text) cascade;
drop function if exists public.admin_add_points(uuid, int, text) cascade;
drop function if exists public.handle_new_user() cascade;
drop function if exists public.on_post_created() cascade;
drop function if exists public.sync_post_like_count() cascade;
drop function if exists public.on_comment_created() cascade;
drop function if exists public.sync_comment_count() cascade;
drop function if exists public.on_quiz_completed() cascade;
drop function if exists public.on_submission_reviewed() cascade;
drop function if exists public.on_speaking_recorded() cascade;

-- Trigger di auth.users dibuat ulang di Bagian 5
drop trigger if exists on_auth_user_created on auth.users;

-- Policy storage dibuat ulang di Bagian 8
drop policy if exists "avatars_public_read"        on storage.objects;
drop policy if exists "avatars_owner_insert"       on storage.objects;
drop policy if exists "avatars_owner_update"       on storage.objects;
drop policy if exists "avatars_owner_delete"       on storage.objects;
drop policy if exists "assets_public_read"         on storage.objects;
drop policy if exists "assets_admin_insert"        on storage.objects;
drop policy if exists "assets_admin_update"        on storage.objects;
drop policy if exists "assets_admin_delete"        on storage.objects;
drop policy if exists "materials_auth_read"        on storage.objects;
drop policy if exists "materials_staff_insert"     on storage.objects;
drop policy if exists "materials_staff_update"     on storage.objects;
drop policy if exists "materials_staff_delete"     on storage.objects;
drop policy if exists "speaking_auth_read"         on storage.objects;
drop policy if exists "speaking_owner_insert"      on storage.objects;
drop policy if exists "speaking_owner_update"      on storage.objects;
drop policy if exists "speaking_owner_delete"      on storage.objects;


-- ============================================================================
--  BAGIAN 1 — EXTENSION
--  gen_random_uuid() sudah bawaan PostgreSQL 13+ (Supabase memakai 15+),
--  jadi tidak perlu extension tambahan. Password demo memakai hash bcrypt
--  yang sudah jadi (lihat Bagian 9) sehingga tidak bergantung pada pgcrypto.
-- ============================================================================

-- pgcrypto opsional (tidak wajib — password demo memakai hash bcrypt siap
-- pakai dan gen_random_uuid() sudah bawaan PostgreSQL 13+)
do $$
begin
  create extension if not exists pgcrypto;
exception
  when others then
    raise notice 'pgcrypto tidak tersedia, dilewati (tidak wajib)';
end
$$;


-- ============================================================================
--  BAGIAN 2 — ENUM (tipe data terkontrol)
-- ============================================================================

create type public.user_role as enum (
  'super_admin',      -- akses penuh, mengatur admin lain
  'administrator',    -- mengelola seluruh konten & pengguna
  'moderator',        -- mengelola konten (material, kuis, tantangan, review)
  'member'            -- anggota biasa
);

create type public.language_type as enum ('english', 'arabic');

-- 5 level bahasa Inggris sesuai spesifikasi aplikasi
create type public.english_level as enum (
  'beginner', 'elementary', 'intermediate', 'upper_intermediate', 'advanced'
);

-- 3 level bahasa Arab sesuai spesifikasi aplikasi
create type public.arabic_level as enum ('mubtadi', 'mutawassith', 'mutaqaddim');

create type public.material_type as enum (
  'lesson', 'video', 'article', 'exercise', 'pdf', 'audio'
);

create type public.event_type as enum (
  'class', 'conversation_club', 'workshop', 'competition', 'meeting'
);

create type public.challenge_type as enum (
  'speaking', 'writing', 'vocabulary', 'grammar', 'listening'
);

create type public.submission_status as enum ('pending', 'approved', 'rejected');

create type public.notification_type as enum (
  'info', 'achievement', 'challenge', 'event', 'reply', 'system'
);


-- ============================================================================
--  BAGIAN 3 — TABEL (20 tabel)
-- ============================================================================

-- 3.1  PROFIL PENGGUNA — terhubung 1:1 dengan auth.users (Supabase Auth).
--      Data sensitif (password) dikelola Supabase Auth, bukan di sini.
create table public.profiles (
  id               uuid primary key references auth.users(id) on delete cascade,
  email            text unique not null,
  full_name        text not null,
  avatar_url       text,
  bio              text,
  role             public.user_role not null default 'member',
  native_language  text default 'Indonesian',
  target_languages public.language_type[] not null default '{english,arabic}',
  english_level    public.english_level not null default 'beginner',
  arabic_level     public.arabic_level  not null default 'mubtadi',
  points           integer not null default 0 check (points >= 0),
  level            integer not null default 1 check (level between 1 and 6),
  streak_days      integer not null default 0 check (streak_days >= 0),
  last_active_date date,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

comment on column public.profiles.level is
  'Gamifikasi 1-6: 1 Beginner(0-99), 2 Explorer(100-249), 3 Contributor(250-499), 4 Achiever(500-999), 5 Expert(1000-1999), 6 Master(2000+)';

-- 3.2  POSTINGAN DISKUSI KOMUNITAS
create table public.posts (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  title          text not null check (char_length(title) between 3 and 150),
  content        text not null check (char_length(content) between 5 and 10000),
  category       text not null default 'general',
  language       public.language_type not null default 'english',
  is_pinned      boolean not null default false,
  likes_count    integer not null default 0,
  comments_count integer not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- 3.3  KOMENTAR POSTINGAN
create table public.comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  content    text not null check (char_length(content) between 1 and 5000),
  created_at timestamptz not null default now()
);

-- 3.4  SUKA POSTINGAN (1 user maksimal 1 like per postingan)
create table public.likes (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

-- 3.5  MATERI BAHASA INGGRIS (5 level: beginner s/d advanced)
create table public.english_materials (
  id               uuid primary key default gen_random_uuid(),
  title            text not null,
  description      text,
  level            public.english_level not null default 'beginner',
  material_type    public.material_type not null default 'lesson',
  content          text,
  file_url         text,
  duration_minutes integer check (duration_minutes > 0),
  created_by       uuid references public.profiles(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- 3.6  MATERI BAHASA ARAB (3 level: mubtadi s/d mutaqaddim) — konten RTL
create table public.arabic_materials (
  id               uuid primary key default gen_random_uuid(),
  title            text not null,
  description      text,
  level            public.arabic_level not null default 'mubtadi',
  material_type    public.material_type not null default 'lesson',
  content          text,
  is_rtl           boolean not null default true,
  file_url         text,
  duration_minutes integer check (duration_minutes > 0),
  created_by       uuid references public.profiles(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- 3.7  BANK KOSAKATA (dua bahasa; kata Arab disimpan dengan teks Arab asli)
create table public.vocabulary (
  id                 uuid primary key default gen_random_uuid(),
  language           public.language_type not null,
  word               text not null,
  translation        text not null,
  transliteration    text,          -- untuk Arab: kitab, madrasah, dst.
  phonetic           text,          -- untuk Inggris: IPA, mis. /kəˈmjuːnəti/
  example_sentence   text,
  example_translation text,
  category           text default 'general',
  is_rtl             boolean not null default false,
  added_by           uuid references public.profiles(id) on delete set null,
  created_at         timestamptz not null default now()
);

-- 3.8  KUIS
create table public.quizzes (
  id                  uuid primary key default gen_random_uuid(),
  title               text not null,
  description         text,
  language            public.language_type not null,
  level               text,        -- 'beginner'...'advanced' atau 'mubtadi'...
  time_limit_minutes  integer default 10 check (time_limit_minutes > 0),
  points_reward       integer not null default 15,
  is_active           boolean not null default true,
  created_by          uuid references public.profiles(id) on delete set null,
  created_at          timestamptz not null default now()
);

-- 3.9  BUTIR SOAL KUIS — opsi & jawaban benar disimpan terstruktur
create table public.quiz_questions (
  id             uuid primary key default gen_random_uuid(),
  quiz_id        uuid not null references public.quizzes(id) on delete cascade,
  question       text not null,
  question_type  text not null default 'multiple_choice'
                 check (question_type in ('multiple_choice', 'true_false', 'translation')),
  options        jsonb not null default '[]'::jsonb,   -- ["opsi A","opsi B",...]
  correct_answer text not null,
  explanation    text,
  points         integer not null default 1,
  order_index    integer not null default 0,
  is_rtl         boolean not null default false
);

-- 3.10 HASIL KUIS PER USER (boleh beberapa percobaan; simpan semua)
create table public.quiz_results (
  id              uuid primary key default gen_random_uuid(),
  quiz_id         uuid not null references public.quizzes(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  score           numeric(5,2) not null default 0 check (score between 0 and 100),
  correct_answers integer not null default 0,
  total_questions integer not null default 0,
  points_earned   integer not null default 0,
  duration_seconds integer,
  completed_at    timestamptz not null default now()
);

-- 3.11 TANTANGAN HARIAN/MINGGUAN
create table public.challenges (
  id             uuid primary key default gen_random_uuid(),
  title          text not null,
  description    text not null,
  challenge_type public.challenge_type not null default 'vocabulary',
  language       public.language_type not null default 'english',
  difficulty     integer not null default 1 check (difficulty between 1 and 5),
  points_reward  integer not null default 20,
  start_date     date not null default current_date,
  end_date       date,
  is_active      boolean not null default true,
  created_by     uuid references public.profiles(id) on delete set null,
  created_at     timestamptz not null default now(),
  check (end_date is null or end_date >= start_date)
);

-- 3.12 PENGUMPULAN SUBMISSION TANTANGAN
create table public.challenge_submissions (
  id            uuid primary key default gen_random_uuid(),
  challenge_id  uuid not null references public.challenges(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  content       text,
  audio_url     text,               -- path di bucket 'speaking-audio'
  status        public.submission_status not null default 'pending',
  score         integer check (score between 0 and 100),
  feedback      text,
  reviewed_by   uuid references public.profiles(id) on delete set null,
  submitted_at  timestamptz not null default now(),
  reviewed_at   timestamptz,
  unique (challenge_id, user_id)    -- 1 submission per user per tantangan
);

-- 3.13 AGENDA EVENT / KEGIATAN
create table public.events (
  id               uuid primary key default gen_random_uuid(),
  title            text not null,
  description      text,
  event_type       public.event_type not null default 'class',
  language         public.language_type,      -- null = dua bahasa
  location         text,                      -- lokasi offline (jika ada)
  meeting_url      text,                      -- link online (jika ada)
  start_time       timestamptz not null,
  end_time         timestamptz,
  max_participants integer default 50 check (max_participants > 0),
  is_online        boolean not null default true,
  created_by       uuid references public.profiles(id) on delete set null,
  created_at       timestamptz not null default now(),
  check (end_time is null or end_time > start_time)
);

-- 3.14 PESERTA EVENT
create table public.event_participants (
  id        uuid primary key default gen_random_uuid(),
  event_id  uuid not null references public.events(id) on delete cascade,
  user_id   uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  unique (event_id, user_id)
);

-- 3.15 NOTIFIKASI (dibaca oleh pemiliknya saja — diatur RLS)
create table public.notifications (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles(id) on delete cascade,
  title             text not null,
  message           text,
  notification_type public.notification_type not null default 'info',
  link              text,             -- rute internal, mis. '#community'
  is_read           boolean not null default false,
  created_at        timestamptz not null default now()
);

-- 3.16 MASTER LENGBAGA (BADGE)
create table public.achievements (
  id              uuid primary key default gen_random_uuid(),
  code            text unique not null,          -- dipakai trigger otomatis
  name            text not null,
  description     text not null,
  icon            text not null default 'fa-medal',  -- class Font Awesome
  color           text default '#D4AF37',
  points_required integer not null default 0,
  created_at      timestamptz not null default now()
);

-- 3.17 LENGBAGA YANG DIRAIH USER
create table public.user_achievements (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  achievement_id uuid not null references public.achievements(id) on delete cascade,
  unlocked_at    timestamptz not null default now(),
  unique (user_id, achievement_id)
);

-- 3.18 PROGRES BELAJAR PER BAHASA PER SKILL
create table public.learning_progress (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references public.profiles(id) on delete cascade,
  language            public.language_type not null,
  skill               text not null check (skill in
                        ('reading','writing','listening','speaking','vocabulary','grammar')),
  progress_percentage integer not null default 0
                        check (progress_percentage between 0 and 100),
  materials_completed integer not null default 0,
  updated_at          timestamptz not null default now(),
  unique (user_id, language, skill)
);

-- 3.19 REKAMAN LATIHAN SPEAKING
create table public.speaking_records (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles(id) on delete cascade,
  language           public.language_type not null,
  title              text,
  text_content       text,            -- kalimat yang dilatih
  audio_url          text,            -- path di bucket 'speaking-audio'
  duration_seconds   integer check (duration_seconds >= 0),
  pronunciation_score integer check (pronunciation_score between 0 and 100),
  is_rtl             boolean not null default false,
  recorded_at        timestamptz not null default now()
);

-- 3.20 PENGATURAN APLIKASI (baris tunggal id=1) — identitas, tema, Supabase.
--      supabase_anon_key AMAN disimpan (by design bersifat publik + RLS).
--      JANGAN PERNAH menyimpan service_role key di kolom ini!
create table public.app_settings (
  id                   integer primary key default 1 check (id = 1),
  community_name       text not null default 'English Arabic Language Community',
  tagline              text not null default 'Learn Together, Speak Confidently, Grow Together.',
  description          text,
  logo_url             text,          -- path di bucket 'community-assets'
  favicon_url          text,
  contact_email        text,
  -- Tampilan / tema
  theme_mode           text not null default 'light'
                       check (theme_mode in ('light','dark','auto')),
  primary_color        text not null default '#1B2A4A',   -- navy blue
  accent_color         text not null default '#10B981',   -- emerald green
  gold_color           text not null default '#D4AF37',   -- gold accent
  -- Konfigurasi koneksi Supabase (hanya URL + ANON key — bukan service key)
  supabase_url         text,
  supabase_anon_key    text,
  -- Sakelar fitur
  enable_ai_assistant  boolean not null default true,
  enable_speaking_room boolean not null default true,
  enable_leaderboard   boolean not null default true,
  registration_open    boolean not null default true,
  -- Pengaturan poin gamifikasi
  points_post          integer not null default 10,
  points_comment       integer not null default 5,
  points_quiz          integer not null default 15,
  points_challenge     integer not null default 20,
  points_speaking      integer not null default 20,
  updated_by           uuid references public.profiles(id) on delete set null,
  updated_at           timestamptz not null default now()
);


-- ============================================================================
--  BAGIAN 4 — INDEX (performa query)
-- ============================================================================

create index idx_posts_user          on public.posts(user_id);
create index idx_posts_created       on public.posts(created_at desc);
create index idx_posts_language      on public.posts(language);
create index idx_comments_post       on public.comments(post_id);
create index idx_comments_user       on public.comments(user_id);
create index idx_likes_post          on public.likes(post_id);
create index idx_vocab_language      on public.vocabulary(language);
create index idx_vocab_word          on public.vocabulary(word);
create index idx_vocab_category      on public.vocabulary(category);
create index idx_quiz_questions_quiz on public.quiz_questions(quiz_id);
create index idx_quiz_results_user   on public.quiz_results(user_id);
create index idx_quiz_results_quiz   on public.quiz_results(quiz_id);
create index idx_submissions_challenge on public.challenge_submissions(challenge_id);
create index idx_submissions_user    on public.challenge_submissions(user_id);
create index idx_event_participants_event on public.event_participants(event_id);
create index idx_event_participants_user  on public.event_participants(user_id);
create index idx_notifications_user_read on public.notifications(user_id, is_read);
create index idx_learning_progress_user  on public.learning_progress(user_id);
create index idx_speaking_user       on public.speaking_records(user_id);
create index idx_user_achievements_user on public.user_achievements(user_id);


-- ============================================================================
--  BAGIAN 5 — FUNGSI & TRIGGER (otomatisasi: updated_at, poin, badge, notifikasi)
-- ============================================================================

-- 5.1  updated_at otomatis
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated     before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger trg_posts_updated        before update on public.posts
  for each row execute function public.set_updated_at();
create trigger trg_english_materials_updated before update on public.english_materials
  for each row execute function public.set_updated_at();
create trigger trg_arabic_materials_updated  before update on public.arabic_materials
  for each row execute function public.set_updated_at();
create trigger trg_learning_progress_updated before update on public.learning_progress
  for each row execute function public.set_updated_at();
create trigger trg_app_settings_updated before update on public.app_settings
  for each row execute function public.set_updated_at();

-- 5.2  Helper cek role (dipakai di policy RLS — security definer agar policy
--      dapat membaca profiles tanpa terpengaruh RLS itu sendiri)
create or replace function public.is_super_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'super_admin'
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('super_admin', 'administrator')
  );
$$;

create or replace function public.is_staff()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('super_admin', 'administrator', 'moderator')
  );
$$;

-- 5.3  Poin & level gamifikasi (hanya trigger/RPC internal yang boleh memanggil;
--      user TIDAK BISA memanggil ini lewat API untuk menaikkan poinnya sendiri)
create or replace function public.award_points(p_user_id uuid, p_points int, p_reason text default null)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if p_points = 0 or p_user_id is null then
    return;
  end if;
  update public.profiles
     set points = greatest(points + p_points, 0),
         level  = case
                    when greatest(points + p_points, 0) >= 2000 then 6
                    when greatest(points + p_points, 0) >= 1000 then 5
                    when greatest(points + p_points, 0) >= 500  then 4
                    when greatest(points + p_points, 0) >= 250  then 3
                    when greatest(points + p_points, 0) >= 100  then 2
                    else 1
                  end
   where id = p_user_id;
end;
$$;

revoke execute on function public.award_points(uuid, int, text)
  from public, anon, authenticated;

-- 5.4  RPC: admin mengubah role user (frontend memanggil via supabase.rpc)
create or replace function public.admin_update_role(p_user_id uuid, p_new_role public.user_role)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Hanya Administrator yang dapat mengubah role';
  end if;
  if p_new_role = 'super_admin' and not public.is_super_admin() then
    raise exception 'Hanya Super Administrator yang dapat menunjuk Super Administrator';
  end if;
  update public.profiles set role = p_new_role where id = p_user_id;
  insert into public.notifications (user_id, title, message, notification_type, link)
  values (p_user_id, 'Role Diperbarui',
          'Role akun Anda diubah menjadi: ' || p_new_role::text, 'system', '#profile');
end;
$$;

revoke execute on function public.admin_update_role(uuid, user_role) from public, anon;
grant  execute on function public.admin_update_role(uuid, user_role) to authenticated;

-- 5.5  RPC: admin menambah poin manual (bonus, penghargaan event, dll.)
create or replace function public.admin_add_points(p_user_id uuid, p_points int, p_reason text default 'Bonus dari admin')
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Hanya Administrator yang dapat menambah poin';
  end if;
  perform public.award_points(p_user_id, p_points, p_reason);
  insert into public.notifications (user_id, title, message, notification_type, link)
  values (p_user_id, 'Poin Tambahan',
          'Anda menerima ' || p_points || ' poin. ' || p_reason, 'system', '#leaderboard');
end;
$$;

revoke execute on function public.admin_add_points(uuid, int, text) from public, anon;
grant  execute on function public.admin_add_points(uuid, int, text) to authenticated;

-- 5.6  Trigger: user baru mendaftar lewat Supabase Auth -> profil dibuat otomatis
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;

  insert into public.notifications (user_id, title, message, notification_type, link)
  values (new.id, 'Selamat Datang!',
          'Selamat datang di English Arabic Language Community. Mulai perjalanan bahasa Anda sekarang!',
          'system', '#dashboard');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 5.7  Trigger: postingan baru -> +10 poin & buka badge "First Words"
create or replace function public.on_post_created()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  perform public.award_points(new.user_id, 10, 'Membuat postingan');

  insert into public.user_achievements (user_id, achievement_id)
  select new.user_id, a.id
  from public.achievements a
  where a.code = 'first_post'
    and not exists (
      select 1 from public.user_achievements ua
      where ua.user_id = new.user_id and ua.achievement_id = a.id
    );
  return null;
end;
$$;

create trigger trg_post_created
  after insert on public.posts
  for each row execute function public.on_post_created();

-- 5.8  Trigger: sinkronisasi jumlah like pada postingan
create or replace function public.sync_post_like_count()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.posts set likes_count = likes_count + 1 where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update public.posts set likes_count = greatest(likes_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end;
$$;

create trigger trg_like_count
  after insert or delete on public.likes
  for each row execute function public.sync_post_like_count();

-- 5.9  Trigger: komentar baru -> counter, +5 poin, notifikasi pemilik postingan
create or replace function public.on_comment_created()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  update public.posts set comments_count = comments_count + 1 where id = new.post_id;
  perform public.award_points(new.user_id, 5, 'Menulis komentar');

  insert into public.notifications (user_id, title, message, notification_type, link)
  select p.user_id, 'Komentar Baru',
         'Postingan Anda mendapat komentar baru dari seorang anggota.',
         'reply', '#community'
  from public.posts p
  where p.id = new.post_id and p.user_id <> new.user_id;
  return null;
end;
$$;

create trigger trg_comment_created
  after insert on public.comments
  for each row execute function public.on_comment_created();

create or replace function public.sync_comment_count()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  update public.posts set comments_count = greatest(comments_count - 1, 0)
  where id = old.post_id;
  return null;
end;
$$;

create trigger trg_comment_deleted
  after delete on public.comments
  for each row execute function public.sync_comment_count();

-- 5.10 Trigger: kuis selesai -> poin (skor >= 70) & badge "Quiz Ace" (skor 100)
create or replace function public.on_quiz_completed()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_reward int;
  v_title  text;
begin
  select q.points_reward, q.title into v_reward, v_title
  from public.quizzes q where q.id = new.quiz_id;

  if new.score >= 70 then
    perform public.award_points(new.user_id, coalesce(v_reward, 15), 'Menyelesaikan kuis');
    insert into public.notifications (user_id, title, message, notification_type, link)
    values (new.user_id, 'Kuis Selesai',
            'Skor kuis "' || coalesce(v_title, '') || '": ' || new.score::int || '%. Poin berhasil ditambahkan.',
            'achievement', '#quiz');
  end if;

  if new.score >= 100 then
    insert into public.user_achievements (user_id, achievement_id)
    select new.user_id, a.id
    from public.achievements a
    where a.code = 'quiz_ace'
      and not exists (
        select 1 from public.user_achievements ua
        where ua.user_id = new.user_id and ua.achievement_id = a.id
      );

    insert into public.notifications (user_id, title, message, notification_type, link)
    select new.user_id, 'Lencana Baru!',
           'Anda membuka lencana baru: ' || a.name, 'achievement', '#profile'
    from public.achievements a where a.code = 'quiz_ace';
  end if;
  return null;
end;
$$;

create trigger trg_quiz_completed
  after insert on public.quiz_results
  for each row execute function public.on_quiz_completed();

-- 5.11 Trigger: submission disetujui -> poin tantangan + notifikasi
create or replace function public.on_submission_reviewed()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_points int;
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
    select c.points_reward into v_points
    from public.challenges c where c.id = new.challenge_id;

    perform public.award_points(new.user_id, coalesce(v_points, 20), 'Submission tantangan disetujui');

    insert into public.notifications (user_id, title, message, notification_type, link)
    values (new.user_id, 'Submission Disetujui',
            'Kerja bagus! Submission tantangan Anda disetujui dan ' ||
            coalesce(v_points, 20) || ' poin ditambahkan.', 'challenge', '#challenge');
  end if;
  return null;
end;
$$;

create trigger trg_submission_reviewed
  after update on public.challenge_submissions
  for each row execute function public.on_submission_reviewed();

-- 5.12 Trigger: latihan speaking baru -> +20 poin
--      (catatan produksi: batasi 1x per hari per user agar tidak di-farming)
create or replace function public.on_speaking_recorded()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  perform public.award_points(new.user_id, 20, 'Latihan speaking');
  return null;
end;
$$;

create trigger trg_speaking_recorded
  after insert on public.speaking_records
  for each row execute function public.on_speaking_recorded();


-- ============================================================================
--  BAGIAN 6 — VIEW PAPAN PERINGKAT
--  View berjalan sebagai pemiliknya (default PostgreSQL) sehingga anggota
--  dapat melihat papan peringkat. Hanya kolom yang aman yang diekspos.
-- ============================================================================

create view public.leaderboard as
select p.id            as user_id,
       p.full_name,
       p.avatar_url,
       p.points,
       p.level,
       p.streak_days,
       (rank() over (order by p.points desc))::int as position
from public.profiles p
where p.is_active;

grant select on public.leaderboard to authenticated;


-- ============================================================================
--  BAGIAN 7 — ROW LEVEL SECURITY (RLS)
--  Prinsip: semua tabel terkunci; tiap policy menyebut role secara eksplisit.
-- ============================================================================

alter table public.profiles             enable row level security;
alter table public.posts                enable row level security;
alter table public.comments             enable row level security;
alter table public.likes                enable row level security;
alter table public.english_materials    enable row level security;
alter table public.arabic_materials     enable row level security;
alter table public.vocabulary           enable row level security;
alter table public.quizzes              enable row level security;
alter table public.quiz_questions       enable row level security;
alter table public.quiz_results         enable row level security;
alter table public.challenges           enable row level security;
alter table public.challenge_submissions enable row level security;
alter table public.events               enable row level security;
alter table public.event_participants   enable row level security;
alter table public.notifications        enable row level security;
alter table public.achievements         enable row level security;
alter table public.user_achievements    enable row level security;
alter table public.learning_progress    enable row level security;
alter table public.speaking_records     enable row level security;
alter table public.app_settings         enable row level security;

-- 7.1  PROFILES: profil publik untuk anggota; role & poin HANYA lewat RPC
create policy "profiles_select" on public.profiles
  for select to authenticated using (true);

create policy "profiles_insert" on public.profiles
  for insert to authenticated with check (auth.uid() = id);

create policy "profiles_update_self" on public.profiles
  for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);

create policy "profiles_update_staff" on public.profiles
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Proteksi kolom: member tidak bisa mengubah role/points/level sendiri
-- (kolom-kolom itu hanya bisa diubah via RPC 5.4/5.5 atau service_role).
revoke update on table public.profiles from authenticated;
grant update (full_name, avatar_url, bio, native_language, target_languages,
              english_level, arabic_level, streak_days, last_active_date, updated_at)
  on table public.profiles to authenticated;

-- 7.2  POSTS
create policy "posts_select" on public.posts
  for select to authenticated using (true);

create policy "posts_insert" on public.posts
  for insert to authenticated with check (auth.uid() = user_id);

create policy "posts_update" on public.posts
  for update to authenticated
  using (auth.uid() = user_id or public.is_staff())
  with check (auth.uid() = user_id or public.is_staff());

create policy "posts_delete" on public.posts
  for delete to authenticated
  using (auth.uid() = user_id or public.is_admin());

-- 7.3  COMMENTS
create policy "comments_select" on public.comments
  for select to authenticated using (true);

create policy "comments_insert" on public.comments
  for insert to authenticated with check (auth.uid() = user_id);

create policy "comments_delete" on public.comments
  for delete to authenticated
  using (auth.uid() = user_id or public.is_staff());

-- 7.4  LIKES
create policy "likes_select" on public.likes
  for select to authenticated using (true);

create policy "likes_insert" on public.likes
  for insert to authenticated with check (auth.uid() = user_id);

create policy "likes_delete" on public.likes
  for delete to authenticated using (auth.uid() = user_id);

-- 7.5  ENGLISH MATERIALS: dikelola staff, dibaca semua anggota
create policy "english_materials_select" on public.english_materials
  for select to authenticated using (true);

create policy "english_materials_insert" on public.english_materials
  for insert to authenticated with check (public.is_staff());

create policy "english_materials_update" on public.english_materials
  for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy "english_materials_delete" on public.english_materials
  for delete to authenticated using (public.is_admin());

-- 7.6  ARABIC MATERIALS
create policy "arabic_materials_select" on public.arabic_materials
  for select to authenticated using (true);

create policy "arabic_materials_insert" on public.arabic_materials
  for insert to authenticated with check (public.is_staff());

create policy "arabic_materials_update" on public.arabic_materials
  for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy "arabic_materials_delete" on public.arabic_materials
  for delete to authenticated using (public.is_admin());

-- 7.7  VOCABULARY: semua anggota boleh menambah kata (Vocabulary Bank komunitas)
create policy "vocabulary_select" on public.vocabulary
  for select to authenticated using (true);

create policy "vocabulary_insert" on public.vocabulary
  for insert to authenticated with check (auth.uid() = added_by);

create policy "vocabulary_update" on public.vocabulary
  for update to authenticated
  using (auth.uid() = added_by or public.is_staff())
  with check (auth.uid() = added_by or public.is_staff());

create policy "vocabulary_delete" on public.vocabulary
  for delete to authenticated
  using (auth.uid() = added_by or public.is_admin());

-- 7.8  QUIZZES & BUTIR SOAL
create policy "quizzes_select" on public.quizzes
  for select to authenticated using (true);

create policy "quizzes_insert" on public.quizzes
  for insert to authenticated with check (public.is_staff());

create policy "quizzes_update" on public.quizzes
  for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy "quizzes_delete" on public.quizzes
  for delete to authenticated using (public.is_admin());

create policy "quiz_questions_select" on public.quiz_questions
  for select to authenticated using (true);

create policy "quiz_questions_insert" on public.quiz_questions
  for insert to authenticated with check (public.is_staff());

create policy "quiz_questions_update" on public.quiz_questions
  for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy "quiz_questions_delete" on public.quiz_questions
  for delete to authenticated using (public.is_admin());

-- 7.9  QUIZ RESULTS: user melihat hasilnya sendiri, staff melihat semua
create policy "quiz_results_select" on public.quiz_results
  for select to authenticated
  using (auth.uid() = user_id or public.is_staff());

create policy "quiz_results_insert" on public.quiz_results
  for insert to authenticated with check (auth.uid() = user_id);

create policy "quiz_results_delete" on public.quiz_results
  for delete to authenticated using (public.is_admin());

-- 7.10 CHALLENGES
create policy "challenges_select" on public.challenges
  for select to authenticated using (true);

create policy "challenges_insert" on public.challenges
  for insert to authenticated with check (public.is_staff());

create policy "challenges_update" on public.challenges
  for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy "challenges_delete" on public.challenges
  for delete to authenticated using (public.is_admin());

-- 7.11 CHALLENGE SUBMISSIONS
create policy "submissions_select" on public.challenge_submissions
  for select to authenticated
  using (auth.uid() = user_id or public.is_staff());

create policy "submissions_insert" on public.challenge_submissions
  for insert to authenticated with check (auth.uid() = user_id);

create policy "submissions_update" on public.challenge_submissions
  for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy "submissions_delete_pending" on public.challenge_submissions
  for delete to authenticated
  using (auth.uid() = user_id and status = 'pending');

create policy "submissions_delete_admin" on public.challenge_submissions
  for delete to authenticated using (public.is_admin());

-- 7.12 EVENTS & PESERTA
create policy "events_select" on public.events
  for select to authenticated using (true);

create policy "events_insert" on public.events
  for insert to authenticated with check (public.is_staff());

create policy "events_update" on public.events
  for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy "events_delete" on public.events
  for delete to authenticated using (public.is_admin());

create policy "event_participants_select" on public.event_participants
  for select to authenticated using (true);

create policy "event_participants_insert" on public.event_participants
  for insert to authenticated with check (auth.uid() = user_id);

create policy "event_participants_delete" on public.event_participants
  for delete to authenticated using (auth.uid() = user_id);

-- 7.13 NOTIFICATIONS: milik pribadi; admin boleh menyiarkan pengumuman
create policy "notifications_select" on public.notifications
  for select to authenticated using (auth.uid() = user_id);

create policy "notifications_insert_self" on public.notifications
  for insert to authenticated with check (auth.uid() = user_id);

create policy "notifications_insert_admin" on public.notifications
  for insert to authenticated with check (public.is_admin());

create policy "notifications_update" on public.notifications
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "notifications_delete" on public.notifications
  for delete to authenticated using (auth.uid() = user_id);

-- 7.14 ACHIEVEMENTS (master) & USER_ACHIEVEMENTS
create policy "achievements_select" on public.achievements
  for select to authenticated using (true);

create policy "achievements_insert" on public.achievements
  for insert to authenticated with check (public.is_admin());

create policy "achievements_update" on public.achievements
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "achievements_delete" on public.achievements
  for delete to authenticated using (public.is_admin());

create policy "user_achievements_select" on public.user_achievements
  for select to authenticated using (true);

create policy "user_achievements_insert" on public.user_achievements
  for insert to authenticated with check (auth.uid() = user_id);

create policy "user_achievements_delete" on public.user_achievements
  for delete to authenticated using (auth.uid() = user_id or public.is_admin());

-- 7.15 LEARNING PROGRESS: pribadi, staff dapat memantau
create policy "learning_progress_select" on public.learning_progress
  for select to authenticated
  using (auth.uid() = user_id or public.is_staff());

create policy "learning_progress_insert" on public.learning_progress
  for insert to authenticated with check (auth.uid() = user_id);

create policy "learning_progress_update" on public.learning_progress
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "learning_progress_delete" on public.learning_progress
  for delete to authenticated using (auth.uid() = user_id);

-- 7.16 SPEAKING RECORDS: pribadi, staff dapat memantau/menilai
create policy "speaking_records_select" on public.speaking_records
  for select to authenticated
  using (auth.uid() = user_id or public.is_staff());

create policy "speaking_records_insert" on public.speaking_records
  for insert to authenticated with check (auth.uid() = user_id);

create policy "speaking_records_update" on public.speaking_records
  for update to authenticated
  using (auth.uid() = user_id or public.is_staff())
  with check (auth.uid() = user_id or public.is_staff());

create policy "speaking_records_delete" on public.speaking_records
  for delete to authenticated
  using (auth.uid() = user_id or public.is_admin());

-- 7.17 APP SETTINGS: semua anggota membaca (config publik), admin mengubah
create policy "app_settings_select" on public.app_settings
  for select to authenticated using (true);

create policy "app_settings_insert" on public.app_settings
  for insert to authenticated with check (public.is_admin());

create policy "app_settings_update" on public.app_settings
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());


-- ============================================================================
--  BAGIAN 8 — STORAGE (logo, avatar, materi, audio speaking)
-- ============================================================================

insert into storage.buckets (id, name, public) values
  ('avatars',          'avatars',          true),   -- foto profil (URL publik)
  ('community-assets', 'community-assets', true),   -- logo & identitas komunitas
  ('materials',        'materials',        false),  -- file materi (terlindungi)
  ('speaking-audio',   'speaking-audio',   false)   -- rekaman latihan speaking
on conflict (id) do nothing;

-- 8.1  AVATARS: publik dibaca; user hanya boleh menulis di folder UUID-nya
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

create policy "avatars_owner_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars'
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars_owner_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars'
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars_owner_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = auth.uid()::text);

-- 8.2  COMMUNITY-ASSETS (logo/identitas): publik dibaca, hanya admin menulis
create policy "assets_public_read" on storage.objects
  for select using (bucket_id = 'community-assets');

create policy "assets_admin_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'community-assets' and public.is_admin());

create policy "assets_admin_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'community-assets' and public.is_admin())
  with check (bucket_id = 'community-assets' and public.is_admin());

create policy "assets_admin_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'community-assets' and public.is_admin());

-- 8.3  MATERIALS: dibaca anggota, ditulis staff (akses via signed URL)
create policy "materials_auth_read" on storage.objects
  for select to authenticated using (bucket_id = 'materials');

create policy "materials_staff_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'materials' and public.is_staff());

create policy "materials_staff_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'materials' and public.is_staff())
  with check (bucket_id = 'materials' and public.is_staff());

create policy "materials_staff_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'materials' and public.is_staff());

-- 8.4  SPEAKING-AUDIO: user membaca/menulis folder miliknya, staff dapat
--      mendengarkan untuk penilaian (akses via createSignedUrl di frontend)
create policy "speaking_auth_read" on storage.objects
  for select to authenticated
  using (bucket_id = 'speaking-audio'
         and ((storage.foldername(name))[1] = auth.uid()::text or public.is_staff()));

create policy "speaking_owner_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'speaking-audio'
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy "speaking_owner_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'speaking-audio'
         and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'speaking-audio'
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy "speaking_owner_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'speaking-audio'
         and (storage.foldername(name))[1] = auth.uid()::text);


-- ============================================================================
--  BAGIAN 9 — SEED DATA DEMO
-- ============================================================================

-- 9.1  AKUN DEMO (schema auth milik Supabase — password bcrypt siap pakai)
--
--  PENTING: kolom `id` di auth.users TIDAK punya nilai default (Supabase Auth
--  selalu mengisi UUID dari sisi aplikasi), jadi id WAJIB diisi eksplisit.
--  Memakai UUID tetap juga membuat seed idempoten: menjalankan ulang skrip
--  tidak mengubah identitas akun (email unik + on conflict do nothing).
--  aud & role diisi 'authenticated' persis seperti akun yang dibuat lewat
--  Dashboard/Auth Admin Supabase.
insert into auth.users
  (id, aud, role, email, encrypted_password, email_confirmed_at,
   raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-4000-8000-000000000001'::uuid, 'authenticated', 'authenticated',
   'admin@demo.com',
   '$2a$10$wd0dmOIGSXToFRoQQABkDeCt3w08HqBPgpsnBMQhutBpBbXMQatjC',  -- admin123
   now(), '{"provider":"email","providers":["email"]}',
   '{"full_name":"Ahmad Fauzi"}', now(), now()),
  ('00000000-0000-4000-8000-000000000002'::uuid, 'authenticated', 'authenticated',
   'moderator@demo.com',
   '$2a$10$.sJT9Afvu5i7EBZDdAaRHO8F8nroUldUvZKmz4VUThSlmKcV10lKi',  -- mod123
   now(), '{"provider":"email","providers":["email"]}',
   '{"full_name":"Siti Rahma"}', now(), now()),
  ('00000000-0000-4000-8000-000000000003'::uuid, 'authenticated', 'authenticated',
   'member@demo.com',
   '$2a$10$93eufRPRFHzfgwpAw/taHe6Ly7EsT8hBhL/K5dp3I1S23OfmO.Yg2',  -- member123
   now(), '{"provider":"email","providers":["email"]}',
   '{"full_name":"Budi Santoso"}', now(), now())
on conflict do nothing;

-- Identitas auth (diperlukan tampilan admin auth Supabase)
insert into auth.identities
  (user_id, provider, provider_id, identity_data, last_sign_in_at, created_at, updated_at)
select u.id, 'email', u.id::text,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       now(), now(), now()
from auth.users u
where u.email in ('admin@demo.com', 'moderator@demo.com', 'member@demo.com')
on conflict do nothing;

-- Profil dibuat otomatis oleh trigger 5.6. Blok ini jaring pengaman bila
-- skrip dijalankan ulang dan akun sudah ada di auth.users:
insert into public.profiles (id, email, full_name)
select u.id, u.email,
       coalesce(u.raw_user_meta_data ->> 'full_name', split_part(u.email, '@', 1))
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

-- 9.2  MASTER LENCAGA (8 badge sesuai spesifikasi aplikasi)
insert into public.achievements (code, name, description, icon, color, points_required) values
  ('first_post',         'First Words',        'Membuat postingan pertama di forum komunitas',      'fa-feather-pointed', '#1B2A4A', 10),
  ('chatty',             'Chatty Friend',      'Menulis 5 komentar di diskusi komunitas',           'fa-comments',        '#10B981', 25),
  ('word_collector',     'Word Collector',     'Menambahkan 50 kata ke Vocabulary Bank',            'fa-book',            '#D4AF37', 50),
  ('quiz_ace',           'Quiz Ace',           'Meraih skor sempurna 100 pada sebuah kuis',         'fa-award',           '#10B981', 15),
  ('streak_7',           'On Fire',            'Aktif belajar 7 hari berturut-turut',               'fa-fire',            '#EF4444', 70),
  ('challenge_champion', 'Challenge Champion', 'Submission tantangan yang disetujui mentor',        'fa-trophy',          '#D4AF37', 20),
  ('silver_tongue',      'Silver Tongue',      'Menyelesaikan 10 latihan speaking',                 'fa-microphone',      '#1B2A4A', 200),
  ('polyglot',           'Polyglot',           'Aktif belajar dua bahasa sekaligus',                'fa-language',        '#10B981', 500)
on conflict (code) do nothing;

-- 9.3  MATERI BAHASA INGGRIS
insert into public.english_materials (title, description, level, material_type, content, duration_minutes, created_by) values
  ('Basic Greetings & Introductions',
   'Pelajari sapaan dan perkenalan dasar untuk pemula.',
   'beginner', 'lesson',
   'Materi: Greetings & Introductions. Kosakata inti: Hello, Good morning, Good evening, How are you?, My name is..., Nice to meet you. Pola kalimat perkenalan: Subject + verb + complement. Latihan: perkenalkan diri Anda dalam 3 kalimat, lalu rekam di Speaking Practice Room.',
   15, (select id from public.profiles where email = 'admin@demo.com')),
  ('Present Perfect vs Simple Past',
   'Memahami perbedaan dua tense yang paling sering tertukar.',
   'intermediate', 'lesson',
   'Materi: Present Perfect vs Simple Past. Gunakan Simple Past untuk kejadian yang selesai pada waktu tertentu (yesterday, last week). Gunakan Present Perfect untuk pengalaman tanpa waktu spesifik (ever, never, already, yet). Rumus: have/has + past participle. Latihan: ubah 5 kalimat Simple Past menjadi Present Perfect.',
   25, (select id from public.profiles where email = 'admin@demo.com')),
  ('Academic Writing Essentials',
   'Menulis akademik yang runtut untuk level lanjutan.',
   'advanced', 'article',
   'Materi: Academic Writing Essentials. Struktur paragraf akademik: topic sentence, supporting details, concluding sentence. Hindari kontraksi dan bahasa gaul. Gunakan linking words: furthermore, however, in contrast, therefore. Latihan: tulis paragraf argumentasi 150 kata tentang pentingnya belajar bahasa asing.',
   40, (select id from public.profiles where email = 'moderator@demo.com'));

-- 9.4  MATERI BAHASA ARAB (konten RTL)
insert into public.arabic_materials (title, description, level, material_type, content, duration_minutes, created_by) values
  ('Huruf Hijaiyah dan Sambutan Dasar',
   'Untuk pemula (Mubtadi): mengenal 28 huruf dan sapaan dasar.',
   'mubtadi', 'lesson',
   'Materi: الحروف الهجائية والتحيات. Mengenal 28 huruf hijaiyah beserta harakat, serta sapaan dasar: السلام عليكم (salam), مرحبا (hai), اسمي... (nama saya...). Latihan: tulis 10 huruf dan ucapkan perlahan-lahan.',
   20, (select id from public.profiles where email = 'admin@demo.com')),
  ('Nahw Dasar: Mubtada dan Khabar',
   'Untuk level menengah (Mutawassith): kalimat nominal.',
   'mutawassith', 'lesson',
   'Materi: Nahw Dasar. Kalimat nominal (jumlah ismiyyah) terdiri dari مبتدأ (mubtada) dan خبر (khabar). Contoh: اللغةُ جميلةٌ. Bahas juga isim isyarah: هذا / هذه. Latihan: susun 5 kalimat nominal sederhana.',
   30, (select id from public.profiles where email = 'admin@demo.com')),
  ('Pengantar Ilmu Balaghah',
   'Untuk level lanjut (Mutaqaddim): pengantar majas Arab.',
   'mutaqaddim', 'article',
   'Materi: Pengantar Balaghah. Kenali tasybih, istighnah, dan kinayah. Contoh tasybih: العلمُ كالنورِ (ilmu ibarat cahaya). Latihan: temukan 2 majas dalam Al-Quran dan jelaskan maknanya dengan bahasa Anda sendiri.',
   45, (select id from public.profiles where email = 'moderator@demo.com'));

-- 9.5  BANK KOSAKATA (6 Inggris + 6 Arab)
insert into public.vocabulary
  (language, word, translation, phonetic, transliteration, example_sentence, example_translation, category, is_rtl, added_by) values
  ('english', 'Community',  'komunitas',     '/kəˈmjuːnəti/', null,
   'Our community grows every day.', 'Komunitas kami bertumbuh setiap hari.', 'general', false,
   (select id from public.profiles where email = 'admin@demo.com')),
  ('english', 'Practice',   'latihan',       '/ˈpræktɪs/', null,
   'Practice makes perfect.', 'Latihan membuat sempurna.', 'general', false,
   (select id from public.profiles where email = 'admin@demo.com')),
  ('english', 'Confident',  'percaya diri',  '/ˈkɒnfɪdənt/', null,
   'Speak with confidence.', 'Berbicaralah dengan percaya diri.', 'speaking', false,
   (select id from public.profiles where email = 'moderator@demo.com')),
  ('english', 'Vocabulary', 'kosakata',      '/vəˈkæbjʊləri/', null,
   'Learn ten new words every day.', 'Pelajari sepuluh kata baru setiap hari.', 'vocabulary', false,
   (select id from public.profiles where email = 'moderator@demo.com')),
  ('english', 'Question',   'pertanyaan',    '/ˈkwestʃən/', null,
   'Do not be afraid to ask questions.', 'Jangan takut untuk bertanya.', 'general', false,
   (select id from public.profiles where email = 'member@demo.com')),
  ('english', 'Answer',     'jawaban',       '/ˈɑːnsə/', null,
   'Your answer is correct.', 'Jawaban Anda benar.', 'general', false,
   (select id from public.profiles where email = 'member@demo.com')),
  ('arabic',  'كتاب',   'buku',   null, 'kitāb',
   'هذا كتابٌ جديدٌ', 'Ini buku baru.', 'pendidikan', true,
   (select id from public.profiles where email = 'admin@demo.com')),
  ('arabic',  'مدرسة',  'sekolah', null, 'madrasah',
   'المدرسةُ قريبةٌ', 'Sekolah itu dekat.', 'pendidikan', true,
   (select id from public.profiles where email = 'admin@demo.com')),
  ('arabic',  'معلّم',  'guru',   null, 'muallim',
   'المعلّمُ صبورٌ', 'Guru itu sabar.', 'pendidikan', true,
   (select id from public.profiles where email = 'admin@demo.com')),
  ('arabic',  'طالب',   'pelajar', null, 'talib',
   'الطالبُ مجتهدٌ', 'Pelajar itu rajin.', 'pendidikan', true,
   (select id from public.profiles where email = 'moderator@demo.com')),
  ('arabic',  'سلام',   'damai / salam', null, 'salam',
   'السلامُ عليكم', 'Semoga keselamatan atasmu.', 'sapaan', true,
   (select id from public.profiles where email = 'moderator@demo.com')),
  ('arabic',  'لغة',    'bahasa', null, 'lughah',
   'العربيةُ لغةٌ جميلةٌ', 'Bahasa Arab adalah bahasa yang indah.', 'general', true,
   (select id from public.profiles where email = 'admin@demo.com'));

-- 9.6  KUIS #1 (Inggris) + butir soal
with new_quiz as (
  insert into public.quizzes (title, description, language, level, time_limit_minutes, points_reward, created_by)
  values ('English Grammar Basics',
          'Uji pemahaman grammar dasar: simple present, plural, dan perfect tense.',
          'english', 'beginner', 10, 15,
          (select id from public.profiles where email = 'admin@demo.com'))
  returning id
)
insert into public.quiz_questions (quiz_id, question, question_type, options, correct_answer, explanation, points, order_index, is_rtl)
select q.id, v.question, 'multiple_choice', v.options::jsonb, v.correct, v.explanation, 1, v.ord, false
from new_quiz q,
     (values
       ('She ___ to school every day.',
        '["go","goes","going","gone"]', 'goes',
        'Subjek orang ketiga tunggal (she) memakai verb + es.', 1),
       ('Choose the correct plural form of child.',
        '["childs","childes","children","childrens"]', 'children',
        'Child adalah kata benda tidak beraturan: jamaknya children.', 2),
       ('I have ___ my homework.',
        '["finish","finishes","finished","finishing"]', 'finished',
        'Setelah have/has gunakan past participle (verb 3).', 3)
     ) as v(question, options, correct, explanation, ord);

-- 9.7  KUIS #2 (Arab, RTL) + butir soal
with new_quiz as (
  insert into public.quizzes (title, description, language, level, time_limit_minutes, points_reward, created_by)
  values ('Kuis Kosakata Arab Dasar',
          'Uji kosakata dasar bahasa Arab untuk level Mubtadi.',
          'arabic', 'mubtadi', 8, 15,
          (select id from public.profiles where email = 'admin@demo.com'))
  returning id
)
insert into public.quiz_questions (quiz_id, question, question_type, options, correct_answer, explanation, points, order_index, is_rtl)
select q.id, v.question, 'multiple_choice', v.options::jsonb, v.correct, v.explanation, 1, v.ord, true
from new_quiz q,
     (values
       ('Apa arti kata «كتاب»؟',
        '["Buku","Pena","Meja","Kursi"]', 'Buku',
        'كتاب dibaca kitāb dan berarti buku.', 1),
       ('«مدرسة» berarti...',
        '["Sekolah","Pasar","Rumah Sakit","Kantor"]', 'Sekolah',
        'مدرسة dibaca madrasah dan berarti sekolah.', 2),
       ('Bahasa Arab untuk guru adalah...',
        '["معلّم","طالب","كتاب","لغة"]', 'معلّم',
        'معلّم dibaca muallim dan berarti guru.', 3)
     ) as v(question, options, correct, explanation, ord);

-- 9.8  TANTANGAN (aktif minggu ini)
insert into public.challenges (title, description, challenge_type, language, difficulty, points_reward, start_date, end_date, created_by) values
  ('Tantangan Menulis: Hari-Hariku',
   'Tulis 5 kalimat tentang aktivitas harian Anda dalam bahasa Inggris pada kolom submission. Tulisan paling kreatif mendapat masukan dari mentor.',
   'writing', 'english', 2, 20, current_date, current_date + 7,
   (select id from public.profiles where email = 'admin@demo.com')),
  ('Tantangan Berbicara: Perkenalan Diri',
   'Rekam perkenalan diri Anda dalam bahasa Arab minimal 4 kalimat (انا اسمي...، اسكن في...، ادرس...، اهتمامي...), lalu unggah rekamannya.',
   'speaking', 'arabic', 2, 20, current_date, current_date + 10,
   (select id from public.profiles where email = 'admin@demo.com'));

-- 9.9  SUBMISSION DEMO (menunggu review moderator)
insert into public.challenge_submissions (challenge_id, user_id, content, status)
select c.id, p.id,
       'My name is Budi. I usually wake up at five in the morning, pray Subuh, and read the Quran. After that I go to campus by motorcycle. In the afternoon I study English with this community. At night I review my lessons before sleeping.',
       'pending'
from public.challenges c, public.profiles p
where c.title = 'Tantangan Menulis: Hari-Hariku'
  and p.email = 'member@demo.com';

-- 9.10 EVENT & PESERTA
insert into public.events (title, description, event_type, language, meeting_url, start_time, end_time, max_participants, is_online, created_by) values
  ('English Conversation Club #12',
   'Sesi praktik berbicara bahasa Inggris bebas dengan tema Traveling. Pemula dipersilakan bergabung dan hanya mendengarkan.',
   'conversation_club', 'english', 'https://meet.jit.si/eacc-club-12',
   now() + interval '7 days', now() + interval '7 days' + interval '90 minutes',
   30, true, (select id from public.profiles where email = 'admin@demo.com')),
  ('Workshop Nahw: Mubtada dan Khabar',
   'Workshop tata bahasa Arab untuk pemula: membedakan mubtada dan khabar beserta latihan i-rab.',
   'workshop', 'arabic', 'https://meet.jit.si/eacc-nahw-01',
   now() + interval '14 days', now() + interval '14 days' + interval '2 hours',
   50, true, (select id from public.profiles where email = 'admin@demo.com'));

insert into public.event_participants (event_id, user_id)
select e.id, p.id
from public.events e, public.profiles p
where e.title = 'English Conversation Club #12'
  and p.email = 'member@demo.com'
on conflict do nothing;

-- 9.11 DISKUSI KOMUNITAS (postingan, komentar, suka)
insert into public.posts (user_id, title, content, category, language) values
  ((select id from public.profiles where email = 'admin@demo.com'),
   'Tips Meningkatkan Kepercayaan Diri Saat Speaking',
   'Halo semuanya! Banyak anggota yang bertanya cara mengatasi gugup saat berbicara bahasa Inggris. Tips saya: 1) Mulai dari topik yang paling Anda kuasai; 2) Rekam suara Anda lalu dengarkan kembali untuk evaluasi; 3) Gunakan Speaking Practice Room minimal 10 menit setiap hari. Konsistensi jauh lebih penting daripada durasi panjang. Selamat berlatih!',
   'speaking', 'english'),
  ((select id from public.profiles where email = 'member@demo.com'),
   'Perbedaan used to dan be used to?',
   'Selama ini saya sering tertukar antara used to dan be used to. Kalimat I used to wake up early dan I am used to waking up early itu beda maknanya bagaimana ya? Mohon pencerahan teman-teman yang lebih paham grammar.',
   'grammar', 'english'),
  ((select id from public.profiles where email = 'admin@demo.com'),
   'Kosakata Arab Seputar Perjalanan',
   'Berikut kosakata penting seputar perjalanan: المطار (bandara), جواز السفر (paspor), تذكرة (tiket), فندق (hotel). Silakan tambahkan kosakata lain yang Anda ketahui di Vocabulary Bank. بالتوفيق!',
   'vocabulary', 'arabic');

insert into public.comments (post_id, user_id, content)
select p.id, pr.id,
       'Pertanyaan bagus! Used to + infinitive berarti kebiasaan di masa lalu yang sudah tidak dilakukan sekarang, sedangkan be used to + verb-ing berarti sudah terbiasa dengan sesuatu. Contoh: I used to live in Jakarta berarti dulu pernah tinggal, sedangkan I am used to living in Jakarta berarti sudah terbiasa tinggal di Jakarta. Semoga membantu!'
from public.posts p, public.profiles pr
where p.title = 'Perbedaan used to dan be used to?'
  and pr.email = 'admin@demo.com';

insert into public.likes (post_id, user_id)
select p.id, pr.id
from public.posts p, public.profiles pr
where p.title = 'Tips Meningkatkan Kepercayaan Diri Saat Speaking'
  and pr.email = 'member@demo.com'
on conflict do nothing;

insert into public.likes (post_id, user_id)
select p.id, pr.id
from public.posts p, public.profiles pr
where p.title = 'Kosakata Arab Seputar Perjalanan'
  and pr.email = 'member@demo.com'
on conflict do nothing;

-- 9.12 HASIL KUIS DEMO (memicu trigger poin & badge secara otomatis)
insert into public.quiz_results (quiz_id, user_id, score, correct_answers, total_questions, points_earned, duration_seconds)
select q.id, p.id, 100.00, 3, 3, 15, 95
from public.quizzes q, public.profiles p
where q.title = 'English Grammar Basics'
  and p.email = 'member@demo.com';

insert into public.quiz_results (quiz_id, user_id, score, correct_answers, total_questions, points_earned, duration_seconds)
select q.id, p.id, 66.67, 2, 3, 0, 120
from public.quizzes q, public.profiles p
where q.title = 'English Grammar Basics'
  and p.email = 'moderator@demo.com';

-- 9.13 PROGRES BELAJAR DEMO
insert into public.learning_progress (user_id, language, skill, progress_percentage, materials_completed) values
  ((select id from public.profiles where email = 'member@demo.com'),    'english', 'speaking',   45, 3),
  ((select id from public.profiles where email = 'member@demo.com'),    'english', 'grammar',    60, 5),
  ((select id from public.profiles where email = 'member@demo.com'),    'english', 'vocabulary', 55, 6),
  ((select id from public.profiles where email = 'member@demo.com'),    'arabic',  'vocabulary', 30, 2),
  ((select id from public.profiles where email = 'member@demo.com'),    'arabic',  'reading',    20, 1),
  ((select id from public.profiles where email = 'admin@demo.com'),     'english', 'speaking',   80, 10),
  ((select id from public.profiles where email = 'admin@demo.com'),     'arabic',  'reading',    65, 8)
on conflict (user_id, language, skill) do nothing;

-- 9.14 REKAMAN SPEAKING DEMO
insert into public.speaking_records (user_id, language, title, text_content, duration_seconds, pronunciation_score, is_rtl) values
  ((select id from public.profiles where email = 'member@demo.com'), 'english',
   'My Daily Routine',
   'I usually wake up at five in the morning and study English before going to campus.',
   34, 82, false),
  ((select id from public.profiles where email = 'member@demo.com'), 'arabic',
   'Perkenalan Diri',
   'انا اسمي بدي. اسكن في جاكرتا. ادرس في الجامعة. احب اللغة العربية.',
   41, 75, true),
  ((select id from public.profiles where email = 'admin@demo.com'), 'english',
   'Why I Love This Community',
   'I love this community because everyone learns together and grows together every single day.',
   58, 90, false);

-- 9.15 LENCBAGA TAMBAHAN (streak admin)
insert into public.user_achievements (user_id, achievement_id)
select pr.id, a.id
from public.profiles pr, public.achievements a
where pr.email = 'admin@demo.com' and a.code = 'streak_7'
on conflict do nothing;

-- 9.16 PENGATURAN APLIKASI (identitas komunitas — dapat diubah di halaman Settings)
insert into public.app_settings
  (id, community_name, tagline, description, contact_email, updated_by)
values (1,
        'English Arabic Language Community',
        'Learn Together, Speak Confidently, Grow Together.',
        'Komunitas belajar bahasa Inggris dan Arab: materi terstruktur, diskusi, latihan speaking, tantangan harian, dan event bersama.',
        'admin@demo.com',
        (select id from public.profiles where email = 'admin@demo.com'))
on conflict (id) do nothing;

-- 9.17 PROFIL AKHIR (poin/level eksplisit menimpa hasil trigger seed agar konsisten)
update public.profiles set
  role = 'super_admin', points = 1240, level = 5, streak_days = 12,
  english_level = 'advanced', arabic_level = 'mutawassith',
  bio = 'Super Administrator komunitas. Fasilitator English Conversation Club.'
where email = 'admin@demo.com';

update public.profiles set
  role = 'moderator', points = 520, level = 4, streak_days = 8,
  english_level = 'upper_intermediate', arabic_level = 'mutaqaddim',
  bio = 'Moderator konten bahasa Arab. Pengajar Nahw dasar.'
where email = 'moderator@demo.com';

update public.profiles set
  points = 380, level = 3, streak_days = 5,
  english_level = 'intermediate',
  bio = 'Mahasiswa yang sedang belajar bahasa Inggris dan Arab setiap hari.'
where email = 'member@demo.com';


-- ============================================================================
--  BAGIAN 10 — VERIFIKASI
--  Hasilnya tampil di tab "Results" setelah Run. Pastikan tidak ada nilai 0
--  pada tabel yang memang berisi seed.
-- ============================================================================

select 'Tabel profiles'            as komponen, count(*) as jumlah from public.profiles
union all select 'Auth users demo',            count(*) from auth.users
union all select 'Posts',                      count(*) from public.posts
union all select 'Comments',                   count(*) from public.comments
union all select 'Likes',                      count(*) from public.likes
union all select 'English materials',          count(*) from public.english_materials
union all select 'Arabic materials',           count(*) from public.arabic_materials
union all select 'Vocabulary',                 count(*) from public.vocabulary
union all select 'Quizzes',                    count(*) from public.quizzes
union all select 'Quiz questions',             count(*) from public.quiz_questions
union all select 'Quiz results',               count(*) from public.quiz_results
union all select 'Challenges',                 count(*) from public.challenges
union all select 'Challenge submissions',      count(*) from public.challenge_submissions
union all select 'Events',                     count(*) from public.events
union all select 'Event participants',         count(*) from public.event_participants
union all select 'Notifications',              count(*) from public.notifications
union all select 'Achievements',               count(*) from public.achievements
union all select 'User achievements',          count(*) from public.user_achievements
union all select 'Learning progress',          count(*) from public.learning_progress
union all select 'Speaking records',           count(*) from public.speaking_records
union all select 'App settings',               count(*) from public.app_settings
union all select 'Storage buckets',            count(*) from storage.buckets
union all select 'RLS policies (public)',      count(*) from pg_policies where schemaname = 'public'
order by 1 asc;

-- ============================================================================
--  SELESAI. Langkah berikutnya:
--  1. Menu Authentication -> URL Configuration -> set Site URL ke aplikasi Anda
--  2. Copy Project URL + anon key dari Settings -> API
--  3. Isi di halaman Settings aplikasi (atau langsung di kode frontend)
--  4. Buat user asli lewat Authentication -> Add user (profilnya otomatis
--     dibuat oleh trigger on_auth_user_created)
-- ============================================================================
