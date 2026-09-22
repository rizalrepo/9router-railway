# 9Router di Railway

[9Router](https://github.com/decolua/9router) — router AI kompatibel OpenAI yang
menghubungkan CLI coding (Claude Code, Codex, Cursor, Cline, Copilot, …) ke 40+
provider, dengan fallback otomatis dan penghemat token RTK.

> Proyek upstream oleh [decolua](https://github.com/decolua) — Lisensi MIT.
> Repo ini **hanya packaging**; tidak memodifikasi atau mendistribusikan ulang
> kode sumber 9Router. Lihat `PROVENANCE.md`.

## Deploy

1. Buat project baru di Railway → **Deploy from GitHub repo** (atau `railway up`
   dari direktori ini).
2. Railway membaca `railway.json` dan memakai `Dockerfile`.
3. **Tambahkan volume** (langkah wajib kalau ingin data bertahan):
   Service → Variables → **Volumes** → New Volume → mount path **`/data`**.
4. Set variabel berikut (Service → Variables):

| Variabel | Nilai | Kenapa |
| --- | --- | --- |
| `DATA_DIR` | `/data` | Titik mount volume. Tanpa ini data hilang tiap redeploy. |
| `HOME` | `/data/home` | `~/.9router` harus bisa ditulis. |
| `JWT_SECRET` | string acak panjang | Menandatangani sesi dashboard. |
| `API_KEY_SECRET` | string acak panjang | Kunci pembuatan API key. |
| `MACHINE_ID_SALT` | string acak panjang | Salt identitas mesin. |
| `ROUTER_VERSION` | opsional, mis. `0.5.81` | Paku versi. Kosongkan untuk selalu terbaru. |

Buat rahasia acak dengan:
```sh
openssl rand -hex 32
```

5. Setelah deploy, ambil domain publik: Service → Settings → **Networking** →
   **Generate Domain**.

## Kenapa build-nya cepat

Paket npm `9router` **sudah memuat app yang ter-build** (`server.js`,
`.next-cli-build/`, `node_modules`). Image ini tidak menjalankan
`npm install`/`next build`; `entrypoint.sh` mengunduh tarball npm (±13 MB) saat
container mulai. Build selesai dalam hitungan detik, bukan 8–15 menit — penting
karena build yang lama membakar kredit trial Anda.

## Pentingnya volume

Tanpa volume di `/data`:

- Kredensial provider dan API key Anda **hilang** setiap redeploy.
- Railway menghapus volume milik akun Trial **30 hari** setelah kredit habis.

Dengan volume, `/data` bertahan melintasi redeploy.

## Keamanan

9Router menyimpan kredensial provider dan menyajikan `/v1` terbuka. Setelah
Anda men-generate domain publik, siapa pun yang tahu URL-nya bisa mencapai
dashboard. Langkah wajib:

1. Saat pertama membuka dashboard, **set password admin yang kuat.**
2. Biarkan `REQUIRE_API_KEY=true` supaya `/v1` menolak permintaan tanpa key.
3. Jangan bagikan domain publik ke orang lain.

## Menghemat kredit trial

Kredit trial $5 habis dalam ~3 minggu kalau container jalan 24/7. Kalau dipakai
sendiri dan tidak terus-menerus:

- Hapus/hentikan service saat tidak dipakai (data tetap di volume).
- Atau turunkan resource: RAM 0,5 GB cukup untuk pemakaian pribadi.
- Pantau pemakaian di dashboard Railway → Usage.
