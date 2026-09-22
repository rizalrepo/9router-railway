# Provenance

Repo ini **packaging saja**. 9Router tidak dimodifikasi dan tidak di-fork.

| Field | Nilai |
| --- | --- |
| Proyek upstream | https://github.com/decolua/9router |
| Sumber kode runtime | paket npm `9router` (saat uji: 0.5.81) |
| Lisensi | MIT |
| Artifact resmi lain | image `decolua/9router`, `ghcr.io/decolua/9router` |

## Tidak ada kode sumber upstream di repo ini

Repo hanya berisi pembungkus container. Saat container mulai, `entrypoint.sh`
mengunduh tarball npm dan mengekstrak app yang sudah ter-build ke `/app/router`.
Jadi repo tetap kecil dan versi 9Router bisa dinaikkan lewat variabel
`ROUTER_VERSION` tanpa mengubah repo.

## File yang ditulis di sini

| File | Fungsi |
| --- | --- |
| `Dockerfile` | Image runtime `node:22-alpine` + `tini`. Tidak mem-build app. |
| `entrypoint.sh` | Mengunduh/mengekstrak 9Router, lalu menjalankan `node custom-server.js`. |
| `railway.json` | Konfigurasi build & healthcheck Railway. |
| `README.md` | Instruksi deploy dan catatan operator. |
| `PROVENANCE.md` | Berkas ini. |

## Cara 9Router disiapkan saat runtime

1. Baca `https://registry.npmjs.org/9router` untuk menentukan versi.
2. Unduh tarball (±13 MB) dan ekstrak `package/app/` ke `$ROUTER_HOME/app`.
3. Jalankan `node custom-server.js` dengan `NEXT_DIST_DIR=.next-cli-build`.

Langkah 3 penting: app npm memakai direktori dist hasil build CLI
(`.next-cli-build`), bukan `.next`. Tanpa variabel itu Next.js mencari dist yang
tidak ada.

Tidak ada `npm install` dan tidak ada `next build`. Ini terverifikasi: 9Router
hidup dan `/api/version` menjawab 200 dalam hitungan detik setelah container
mulai.

## Merek dagang

Nama dan logo 9Router milik penulis upstream. Repo ini deployment tidak resmi
dan tidak didukung proyek upstream.
