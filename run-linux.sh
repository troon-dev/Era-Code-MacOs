#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [[ ! -f app/index.js || ! -f app/renderer/index.html ]]; then
  echo "Era application files were not found in: $ROOT" >&2
  exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is required. On CachyOS, install it with: sudo pacman -S python" >&2
  exit 2
fi
if ! command -v node >/dev/null 2>&1; then
  echo "Node.js is required. On CachyOS, install it with: sudo pacman -S nodejs npm" >&2
  exit 2
fi

# Electron needs the JavaScript dependencies already present in package-lock.json.
# Do not try to start a partially installed checkout: the resulting error is much
# harder to diagnose than a clear instruction here.
if [[ ! -d "$ROOT/node_modules" ]]; then
  echo "Dependencies are missing. Run: npm ci" >&2
  exit 2
fi

# Discord OAuth returns to fluxapp://. In Linux the browser resolves that URL
# through the per-user desktop entry, rather than through an unpackaged
# Electron process.
if command -v xdg-mime >/dev/null 2>&1; then
  FLUX_HANDLER="$(xdg-mime query default x-scheme-handler/fluxapp 2>/dev/null || true)"
  if [[ "$FLUX_HANDLER" != "era-code.desktop" ]]; then
    echo "Notice: the Discord callback is not registered. Run once: npm run install:linux-desktop" >&2
  fi
fi

URL="http://127.0.0.1:5173/"
SERVER_PID=""
SERVER_LOG="${TMPDIR:-/tmp}/era-code-renderer-server.log"
USE_EXISTING_RENDERER="${ERA_USE_EXISTING_RENDERER:-0}"

# A browser callback starts this script a second time through era-code.desktop.
# The existing Electron instance will receive the URL via `second-instance`,
# so it must be allowed to reuse the renderer server in this one case.
for argument in "$@"; do
  if [[ "$argument" == fluxapp://* ]]; then
    USE_EXISTING_RENDERER=1
    break
  fi
done
server_responds() {
  python3 -c 'import urllib.request; urllib.request.urlopen("http://127.0.0.1:5173/", timeout=0.5).read(1)' >/dev/null 2>&1
}
cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

if server_responds; then
  if [[ "$USE_EXISTING_RENDERER" != "1" ]]; then
    cat >&2 <<EOF
Port 5173 is already in use by another server.
To avoid loading an interface that does not belong to this directory, Era stopped.
Close that server and run Era again, or use ERA_USE_EXISTING_RENDERER=1 if you verified it.
EOF
    exit 1
  fi
  echo "Using the requested existing server at $URL"
else
  echo "Starting the local interface at 127.0.0.1:5173..."
  python3 -m http.server 5173 --bind 127.0.0.1 --directory "$ROOT/app/renderer" >"$SERVER_LOG" 2>&1 &
  SERVER_PID=$!
  ready=0
  for _ in $(seq 1 40); do
    if server_responds; then ready=1; break; fi
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
      echo "The local server could not start. Log: $SERVER_LOG" >&2
      cat "$SERVER_LOG" >&2 || true
      exit 1
    fi
    sleep 0.25
  done
  if [[ "$ready" != 1 ]]; then
    echo "The local interface did not respond at $URL. Log: $SERVER_LOG" >&2
    exit 1
  fi
fi

if [[ -n "${ERA_ELECTRON:-}" ]]; then
  if [[ ! -x "$ERA_ELECTRON" ]]; then
    echo "ERA_ELECTRON does not point to an executable: $ERA_ELECTRON" >&2
    exit 2
  fi
  "$ERA_ELECTRON" . "$@"
elif [[ -x "$ROOT/node_modules/.bin/electron" ]]; then
  "$ROOT/node_modules/.bin/electron" . "$@"
elif command -v electron >/dev/null 2>&1; then
  electron . "$@"
else
  echo "Electron is not installed locally; starting it with npx (the first run may take a moment)."
  npx --yes electron . "$@"
fi
