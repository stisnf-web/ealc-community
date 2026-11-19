-- ============================================================================
--  MIGRASI HAK AKSES SUPERADMIN — English Arabic Language Community
-- ============================================================================
--  Untuk proyek Supabase yang SUDAH menjalankan supabase_schema.sql versi lama.
--  Jalankan seluruh isi file ini SEKALI di Supabase Studio -> SQL Editor -> Run.
--
--  Hasil setelah migrasi (hierarki hak akses di aplikasi):
--    super_admin   -> akses penuh TERMASUK halaman Settings
--                     (identitas/logo, tema, koneksi Supabase, reset data,
--                      tautan berbagi Mode Online)
--    administrator -> Admin Dashboard + kelola konten & pengguna,
--                     TANPA halaman Settings
--    moderator     -> moderasi konten & review submission,
--                     TANPA halaman Settings
--    member        -> akses anggota biasa, TANPA halaman Settings
--
--  Akun demo setelah migrasi:
--    superadmin@demo.com / super123   (Super Admin - BARU)
--    admin@demo.com      / admin123   (Admin - turun dari Super Admin)
--    moderator@demo.com  / mod123
--    member@demo.com     / member123
--
--  Cukup jalankan SEKALI; aman dijalankan ulang (idempoten).
-- ============================================================================

-- 1) Turunkan admin@demo.com menjadi Administrator (tidak lagi memegang
--    Settings; posisi itu sekarang milik Super Admin).
update public.profiles set
  role = 'administrator',
  bio  = 'Administrator komunitas. Fasilitator English Conversation Club.'
where email = 'admin@demo.com'
  and role <> 'administrator';

-- 2) Buat akun Super Admin baru: superadmin@demo.com / super123
--    (id UUID tetap agar idempoten; akun dibuat terkonfirmasi agar bisa
--     langsung login tanpa verifikasi email).
insert into auth.users
  (id, aud, role, email, encrypted_password, email_confirmed_at,
   raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-4000-8000-000000000004'::uuid, 'authenticated', 'authenticated',
   'superadmin@demo.com',
   '$2a$10$2y2RUK1LEZKWa8nQhC.G0.695z3Exf4.M.mcbQwb9gC2wv3Ukt7ty',  -- super123
   now(), '{"provider":"email","providers":["email"]}',
   '{"full_name":"Farhan Hidayat"}', now(), now())
on conflict do nothing;

-- 3) Identitas auth untuk tampilan admin auth Supabase.
insert into auth.identities
  (user_id, provider, provider_id, identity_data, last_sign_in_at, created_at, updated_at)
select u.id, 'email', u.id::text,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       now(), now(), now()
from auth.users u
where u.email = 'superadmin@demo.com'
on conflict do nothing;

-- 4) Profil biasanya dibuat otomatis oleh trigger on_auth_user_created;
--    blok ini jaring pengaman bila trigger belum sempat berjalan.
insert into public.profiles (id, email, full_name)
select u.id, u.email,
       coalesce(u.raw_user_meta_data ->> 'full_name', split_part(u.email, '@', 1))
from auth.users u
where u.email = 'superadmin@demo.com'
  and not exists (select 1 from public.profiles p where p.id = u.id);

-- 5) Promosikan profil Super Admin (poin/level agar konsisten dengan demo).
update public.profiles set
  role = 'super_admin', points = 1500, level = 6, streak_days = 15,
  english_level = 'advanced', arabic_level = 'mutaqaddim',
  bio = 'Pemilik komunitas. Satu-satunya role yang dapat membuka halaman Settings.'
where email = 'superadmin@demo.com';

-- 6) PENTING — angkat akun ANDA sendiri menjadi Super Admin.
--    Ganti email di baris berikut dengan email yang Anda pakai login
--    (contoh di bawah memakai dheunzmk009@gmail.com):
update public.profiles set role = 'super_admin'
where email = 'dheunzmk009@gmail.com';

-- ============================================================================
--  VERIFIKASI — hasil tampil di tab Results. Kolom "role" harus sudah benar.
-- ============================================================================
select email, role, points, level from public.profiles order by role, email;
