#!/bin/sh
# Unduh 9Router (app sudah ter-build di dalam paket npm), lalu jalankan.
# Idempoten: kalau sudah ada di volume, pakai yang ada.
set -eu

ROUTER_HOME="${ROUTER_HOME:-/app/router}"
APP_DIR="$ROUTER_HOME/app"
PORT="${PORT:-8080}"
REGISTRY="${NPM_REGISTRY:-https://registry.npmjs.org}"

log() { echo "[entrypoint] $*"; }

# --------------------------------------------------------------------- Node ---
if ! command -v node >/dev/null 2>&1; then
  echo "[entrypoint] FATAL: node tidak ada di image" >&2
  exit 1
fi
log "node $(node --version) di $(command -v node)"

# ------------------------------------------------------- izin volume Railway ---
# Railway me-mount volume pada /data SAAT RUNTIME dengan kepemilikan root,
# sementara image ini berjalan sebagai user `node`.
#
# Strategi: simpan data di SUBDIREKTORI (/data/9router) yang sudah dibuat saat
# build dan dimiliki `node`. Mount Railway hanya menimpa /data itu sendiri,
# bukan isinya, sehingga subdirektori tetap dapat ditulis TANPA berjalan
# sebagai root. Bila tetap gagal, coba lokasi lain yang bisa ditulis; bila
# semuanya gagal, cetak instruksi RAILWAY_RUN_UID=0 dan berhenti.

pick_writable_dir() {
  for candidate in "$@"; do
    if mkdir -p "$candidate" 2>/dev/null && touch "$candidate/.write-test" 2>/dev/null; then
      rm -f "$candidate/.write-test"
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

HOME_DIR="$(pick_writable_dir "${HOME:-/data/home}" /tmp/9router-home || true)"
if [ -z "$HOME_DIR" ]; then
  echo "[entrypoint] FATAL: tidak ada direktori HOME yang bisa ditulis." >&2
  exit 1
fi
export HOME="$HOME_DIR"

DATA_DIR="$(pick_writable_dir "${DATA_DIR:-/data/9router}" /tmp/9router-data || true)"
if [ -z "$DATA_DIR" ]; then
  cat >&2 <<'MSG'
[entrypoint] FATAL: tidak ada lokasi data yang bisa ditulis.

Kalau Anda memasang volume Railway, set variabel ini pada service:
    RAILWAY_RUN_UID=0

Railway me-mount volume sebagai root, sementara image ini berjalan sebagai user
`node`. Dokumentasi Railway: "Docker images that run as a non-root UID by
default will have permissions issues when performing operations within an
attached volume."
MSG
  exit 1
fi
export DATA_DIR

if [ "$DATA_DIR" = "/tmp/9router-data" ]; then
  log "PERINGATAN: data disimpan di /tmp — TIDAK akan bertahan setelah restart."
  log "PERINGATAN: set RAILWAY_RUN_UID=0 atau perbaiki izin volume /data."
fi
log "data dapat ditulis: $DATA_DIR | home: $HOME_DIR"

# ----------------------------------------------------------------- 9Router ----
if [ -f "$APP_DIR/server.js" ] && [ -f "$APP_DIR/custom-server.js" ]; then
  log "9Router sudah ada di $APP_DIR (dari volume) — melewati unduhan"
else
  if [ -n "${ROUTER_VERSION:-}" ]; then
    VERSION="$ROUTER_VERSION"
    log "memakai versi yang dipatok: $VERSION"
  else
    log "mencari versi terbaru di $REGISTRY …"
    VERSION="$(curl -fsSL "$REGISTRY/9router" | sed -n 's/.*"latest":"\([^"]*\)".*/\1/p' | head -n1)"
    if [ -z "$VERSION" ]; then
      echo "[entrypoint] FATAL: gagal menentukan versi 9router dari registry" >&2
      exit 1
    fi
    log "versi terbaru: $VERSION"
  fi

  TARBALL="$REGISTRY/9router/-/9router-$VERSION.tgz"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT

  log "mengunduh $TARBALL"
  curl -fsSL --retry 3 --retry-delay 2 -o "$TMP/9router.tgz" "$TARBALL"

  log "mengekstrak …"
  tar -xzf "$TMP/9router.tgz" -C "$TMP"

  if [ ! -d "$TMP/package/app" ]; then
    echo "[entrypoint] FATAL: paket npm tidak memuat app/ — struktur paket berubah" >&2
    exit 1
  fi

  rm -rf "$APP_DIR"
  mkdir -p "$ROUTER_HOME"
  mv "$TMP/package/app" "$APP_DIR"
  # Simpan versi supaya build berikutnya bisa mendeteksi perubahan.
  echo "$VERSION" > "$ROUTER_HOME/VERSION"
  log "9Router $VERSION siap di $APP_DIR"
fi

log "data: $DATA_DIR | home: $HOME | port: $PORT"

# ------------------------------------------------------------------- start ---
cd "$APP_DIR"

# Paket npm memakai dist hasil build CLI, bukan .next biasa. Tanpa ini Next.js
# mencari direktori yang tidak ada.
export NEXT_DIST_DIR="${NEXT_DIST_DIR:-.next-cli-build}"
export PORT HOSTNAME DATA_DIR
export UPDATER_APP_PORT="${UPDATER_APP_PORT:-$PORT}"
export BASE_URL="${BASE_URL:-http://127.0.0.1:$PORT}"
export NEXT_PUBLIC_BASE_URL="${NEXT_PUBLIC_BASE_URL:-http://127.0.0.1:$PORT}"

log "menjalankan: node custom-server.js (NEXT_DIST_DIR=$NEXT_DIST_DIR)"
exec node custom-server.js
