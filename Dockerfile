# syntax=docker/dockerfile:1.7
#
# 9Router — Railway / container umum
# Upstream: https://github.com/decolua/9router (MIT License)
#
# Kenapa tidak `npm install` + `next build` seperti Dockerfile upstream:
# paket npm `9router` sudah memuat app YANG SUDAH TER-BUILD (server.js,
# .next-cli-build/, node_modules). Jadi image ini dibangun dalam hitungan detik,
# bukan 8-15 menit. Di Railway, build cepat berarti kredit trial Anda tidak
# habis untuk sekadar compile.
#
# Perbedaan penting dari versi Hugging Face:
#   * Railway memilih port lewat variabel $PORT, jadi kita tidak memaku 7860.
#   * Data diarahkan ke /data (titik mount volume Railway), bukan /app/data.

ARG NODE_IMAGE=node:22-alpine

FROM ${NODE_IMAGE}

LABEL org.opencontainers.image.title="9router" \
      org.opencontainers.image.source="https://github.com/decolua/9router" \
      org.opencontainers.image.licenses="MIT"

# `xz` dibutuhkan untuk mengekstrak runtime Node bila image tidak menyediakannya;
# `sqlite` untuk memeriksa DB; `curl` untuk healthcheck.
RUN apk add --no-cache xz curl sqlite tini

WORKDIR /app

# Skrip penyiapan: unduh tarball npm, ekstrak, jalankan Node.
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    HOSTNAME=0.0.0.0 \
    ROUTER_HOME=/app/router \
    DATA_DIR=/data \
    HOME=/data/home

# Railway me-mount volume di /data. Buat di sini supaya izinnya benar
# walaupun berjalan tanpa volume (saat pertama kali).
RUN mkdir -p /data/home /app/router && chown -R node:node /data /app

USER node

# Railway menimpa ini dengan $PORT-nya sendiri; 8080 hanya nilai wajar kalau
# dijalankan lokal.
ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT}/api/version" || exit 1

# tini sebagai PID 1: meneruskan sinyal dengan benar dan memungut proses zombie,
# penting karena kita menjalankan Node sebagai proses anak.
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/app/entrypoint.sh"]
