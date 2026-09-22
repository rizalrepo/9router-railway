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
