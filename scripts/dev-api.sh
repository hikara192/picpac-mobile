#!/usr/bin/env bash
# Отдельный stateful mock API (Dart Shelf). Порт по умолчанию 8080.
#   ./scripts/dev-api.sh            # 8080
#   PORT=9090 ./scripts/dev-api.sh
set -euo pipefail
cd "$(dirname "$0")/.."
PORT="${PORT:-8080}"
exec dart run packages/mock_server/bin/server.dart --port "${PORT}"
