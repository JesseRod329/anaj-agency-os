#!/usr/bin/env zsh
set -euo pipefail

BACKEND_DIR="${OPENCLAW_BACKEND_DIR:-/Users/jesse/anaj/backend}"
HOST="${OPENCLAW_BRIDGE_HOST:-127.0.0.1}"
PORT="${OPENCLAW_BRIDGE_PORT:-18890}"
ANAJ_API_BASE="${ANAJ_API_BASE:-http://127.0.0.1:18790}"
ANAJ_WS_URL="${ANAJ_WS_URL:-ws://127.0.0.1:18791/ws/openclaw}"

if [[ ! -d "${BACKEND_DIR}" ]]; then
    echo "[openclaw-bridge] Backend directory not found: ${BACKEND_DIR}" >&2
    exit 1
fi

cd "${BACKEND_DIR}"

if [[ -x "${BACKEND_DIR}/venv/bin/python" ]]; then
    PYTHON_BIN="${BACKEND_DIR}/venv/bin/python"
elif command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
else
    echo "[openclaw-bridge] Python 3 is required but was not found." >&2
    exit 1
fi

echo "[openclaw-bridge] backend_dir=${BACKEND_DIR}"
echo "[openclaw-bridge] python=${PYTHON_BIN}"
echo "[openclaw-bridge] listen=http://${HOST}:${PORT}"
echo "[openclaw-bridge] anaj_api_base=${ANAJ_API_BASE}"
echo "[openclaw-bridge] anaj_ws_url=${ANAJ_WS_URL}"

exec "${PYTHON_BIN}" -m uvicorn main:app --host "${HOST}" --port "${PORT}"
