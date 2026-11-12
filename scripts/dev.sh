#!/usr/bin/env bash
# Приложение + внешний mock API (два процесса).
#   ./scripts/dev.sh ios|android|<device>
# iOS-симулятор видит хост как 127.0.0.1, Android-эмулятор — как 10.0.2.2.
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="${1:-auto}"
PORT="${PORT:-8080}"

case "${TARGET}" in
  android|emulator-*) BASE="http://10.0.2.2:${PORT}" ;;
  *)                  BASE="http://127.0.0.1:${PORT}" ;;
esac

PORT="${PORT}" ./scripts/dev-api.sh &
API_PID=$!
trap 'kill ${API_PID} 2>/dev/null || true' EXIT INT TERM

for _ in $(seq 1 40); do
  if curl -sf "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then break; fi
  sleep 0.25
done

API_MODE=http API_BASE_URL="${BASE}" ./scripts/run.sh "${TARGET}"
