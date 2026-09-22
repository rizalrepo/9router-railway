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
# Railway me-mount volume sebagai root. Image ini berjalan sebagai user `node`,
# dan dokumentasi Railway mencatat masalah izin ini secara eksplisit. Kalau kita
# tidak bisa menulis, jangan mati begitu saja: beri pesan yang bisa ditindak.
DATA_DIR="${DATA_DIR:-/data}"
HOME_DIR="${HOME:-/data/home}"

if ! mkdir -p "$DATA_DIR" "$HOME_DIR" 2>/dev/null; then
  cat >&2 <<'MSG'
[entrypoint] FATAL: tidak bisa menulis ke DATA_DIR/HOME.

Kalau Anda memasang volume Railway, set variabel ini pada service:
    RAILWAY_RUN_UID=0

Railway me-mount volume sebagai root, sementara image ini berjalan sebagai user
`node`, jadi penulisan ditolak. Dokumentasi Railway: "Docker images that run as
a non-root UID by default will have permissions issues when performing
operations within an attached volume."
MSG
  exit 1
fi

# Kalau bisa ditulis tapi bukan milik kita (kasus volume baru tanpa
# RAILWAY_RUN_UID), coba ambil alih; abaikan bila tidak punya hak.
chown -R "$(id -u):$(id -g)" "$DATA_DIR" "$HOME_DIR" 2>/dev/null || true

if ! touch "$DATA_DIR/.write-test" 2>/dev/null; then
  echo "[entrypoint] FATAL: DATA_DIR ($DATA_DIR) tidak bisa ditulis. Set RAILWAY_RUN_UID=0." >&2
  exit 1
fi
rm -f "$DATA_DIR/.write-test"
log "data dapat ditulis: $DATA_DIR"


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

mkdir -p "$DATA_DIR" "$HOME"
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
