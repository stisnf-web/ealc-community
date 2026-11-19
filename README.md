# English Arabic Language Community

**Learn Together, Speak Confidently, Grow Together.**

Aplikasi web komunitas belajar bahasa Inggris & Arab dalam **satu file** `index.html`
(HTML5 + CSS3 + Vanilla JavaScript — tanpa framework, tanpa build step).

---

## 1. Cara Menjalankan (Run Instructions)

### Opsi A — Langsung buka file (paling cepat)
1. Download / salin `index.html`.
2. Klik dua kali file tersebut (terbuka di Chrome / Edge / Firefox).
3. Selesai. Tidak perlu install apa pun.

### Opsi B — Lewat local server (disarankan untuk fitur mikrofon)
Fitur **rekaman suara (MediaRecorder)** dan **speech-to-text** butuh *secure context*.
Buka lewat salah satu cara ini agar mikrofon aktif:

```bash
# Python 3 (tersedia di semua OS)
python3 -m http.server 8080
# lalu buka http://localhost:8080

# atau dengan Node.js
npx serve .
```

### Catatan koneksi internet
Butuh internet saat pertama kali load untuk CDN: Google Fonts (Poppins & Cairo),
Font Awesome, dan Chart.js. Jika CDN gagal, aplikasi tetap jalan — hanya grafik
Chart.js yang ditampilkan sebagai pesan fallback.

---

## 2. Akun Demo

| Peran | Email | Password | Keterangan |
|---|---|---|---|
| Super Administrator | `admin@demo.com` | `admin123` | Akses penuh termasuk Admin Dashboard & manajemen user |
| Moderator | `moderator@demo.com` | `mod123` | Moderasi konten, akses Admin Dashboard terbatas |
| Member | `member@demo.com` | `member123` | Akun contoh anggota biasa |
| Member (2) | `siti@demo.com` | `member123` | Data demo tambahan |
| Member (3) | `abdullah@demo.com` | `member123` | Data demo tambahan |
| Member (4) | `maria@demo.com` | `member123` | Data demo tambahan |

Di halaman login tersedia tombol cepat **"Login as Admin"** dan **"Login as Member"**.
Registrasi akun baru otomatis berperan sebagai Member.

> **Demo only:** autentikasi disimulasikan dan disimpan di `localStorage` browser —
> bukan keamanan produksi. Untuk produksi, hubungkan Supabase Auth melalui backend.

---

## 3. Fitur Utama

- **Dashboard** — statistik, streak, grafik aktivitas mingguan (Chart.js), aksi cepat
- **English Learning Center** — materi 5 level (Beginner → Advanced) + tombol pengucapan
- **Arabic Learning Center** — 3 level (Mubtadi' / Mutawassith / Mutaqaddim), teks Arab
  RTL dengan font Cairo, alfabet interaktif 28 huruf
- **Community Discussion** — posting, komentar, like, kategori, pencarian (+10/+5 poin)
- **Speaking Practice Room** — rekaman audio (MediaRecorder), speech-to-text
  (Web Speech API), latihan pengucapan EN/AR
- **Vocabulary Bank** — 12+ kosakata dwibahasa, tandai "learned", TTS
- **Daily Challenge** — tantangan harian otomatis berdasarkan tanggal (+20 poin)
- **Quiz & Assessment** — 4 kuis siap pakai, review jawaban, riwayat hasil (+15 poin)
- **Leaderboard** — podium + tabel, mode All-time / Weekly
- **Events** — ikut acara (+5 poin), admin bisa buat/hapus event + broadcast
- **Member Profile** — avatar, bio, grafik progres, 8 lencana, timeline aktivitas
- **AI Language Assistant** — mode DEMO (jawaban simulasi, tanpa API key di frontend)
- **Notification Center** — filter All/Unread, tandai dibaca, broadcast admin
- **Admin Dashboard** — 11 panel: overview+grafik, manajemen user (role/ban/hapus),
  moderasi, materi EN/AR, vocabulary, kuis, challenge, event, broadcast, laporan
- **Settings** — 6 tab:
  1. **Identity & Logo** — upload logo (base64, maks 300 KB), nama, tagline, email
  2. **Appearance** — 6 tema warna (Navy/Emerald/Ocean/Royal/Sunset/Midnight Dark),
     tersimpan & otomatis dipakai ulang
  3. **Supabase Connection** — simpan Project URL + anon key (hanya di browser),
     tombol Test Connection, catatan integrasi backend
  4. **Notifications** — preferensi notifikasi
  5. **Data Management** — export/import JSON, reset ke data demo
  6. **About** — informasi aplikasi

**Data disimpan di `localStorage`** (19 key berawalan `ealc_*`): users, profiles (bio &
poin di users), posts, comments, likes, english_materials, arabic_materials, vocabulary,
quizzes, quiz_results, challenges, challenge_submissions, events, notifications,
achievements, learning_progress, speaking_records, settings, session.
Struktur siap dipindahkan ke Supabase di masa depan.

---

## 4. Upload ke GitHub — Apakah Aman?

**Ya, aman.** File `index.html` tidak berisi rahasia apa pun:

- Tidak ada API key, token, atau credentials di dalam kode
- Konfigurasi Supabase diisi admin saat aplikasi berjalan dan **hanya disimpan di
  localStorage browser masing-masing** — tidak pernah tertulis ke file
- Password akun demo sengaja bersifat publik (hanya data demo)
- Data pengguna tidak ikut ke repo karena tersimpan di browser, bukan di file

**Yang perlu diingat:**
1. Jangan pernah menambahkan *service_role key* Supabase atau API key LLM ke file
   frontend ini — key sensitif harus selalu di backend (Edge Function).
2. Jika nanti menambahkan kredensial nyata, simpan di environment variable / file yang
   di-`.gitignore`, bukan di `index.html`.
3. Repo bisa dibuat **Private** jika ingin membatasi siapa yang melihat kode.

### Deploy gratis via GitHub Pages
1. Push `index.html` ke repo GitHub.
2. **Settings → Pages → Source: deploy from branch → `main` / root.**
3. Aplikasi live di `https://<username>.github.io/<repo>/` — dan karena sudah HTTPS,
   fitur mikrofon langsung berfungsi.

---

## 5. Poin & Gamifikasi

| Aksi | Poin |
|---|---|
| Posting diskusi | +10 |
| Komentar | +5 |
| Selesaikan quiz | +15 |
| Daily challenge | +20 |
| Speaking practice | +20 |
| Join event | +5 |
| Kata baru dipelajari | +2 |

Level: New Member → Explorer (100) → Learner (300) → Achiever (600) → Expert (1000) →
Legend (1500). Badge: First Post, Vocabulary Builder, Quiz Master, Challenge Champion,
Streak Star, Speaking Star, Social Butterfly, Event Enthusiast.

---

## 6. Struktur Proyek

```
.
├── index.html   # seluruh aplikasi (CSS + JS inline, ~3.200 baris)
└── README.md    # dokumen ini
```

Versi 1.0.0 — dibuat untuk komunitas pembelajar bahasa.
