#!/usr/bin/env bash
# PicPac Mobile — запуск приложения одной командой.
#
#   ./scripts/run.sh            # авто-выбор: iOS-симулятор → Android-эмулятор → телефон
#   ./scripts/run.sh ios        # iPhone/iPad-симулятор
#   ./scripts/run.sh android    # Android-эмулятор
#   ./scripts/run.sh <device>   # конкретный id из `flutter devices`
#
# По умолчанию приложение поднимает mock API ВНУТРИ себя (in-process HTTP на 127.0.0.1),
# поэтому внешний сервер не нужен: UI всё равно ходит через настоящий HTTP-адаптер.
# Для отдельного сервера см. ./scripts/dev.sh
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:-auto}"
# Первый аргумент — селектор устройства, а не флаг `flutter run`: без сдвига
# `./scripts/run.sh ios` передавал бы "ios" в flutter и падал на разборе аргументов.
if [[ $# -gt 0 ]]; then shift; fi

# Список устройств в машинном виде.
#
# `id` у iOS-симулятора — UUID (`69B0595B-…`), а у физического iPhone — UDID
# (`00008110-…`), поэтому фильтровать по префиксу id нельзя. Платформа и признак
# симулятора лежат в `targetPlatform`/`emulator`/`sdk`.
devices_json() {
  flutter devices --machine 2>/dev/null || true
}

booted_simulator() {
  xcrun simctl list devices booted 2>/dev/null \
    | sed -n 's/.*(\([0-9A-F-]\{36\}\)) (Booted).*/\1/p' \
    | head -1 || true
}

pick_device() {
  local kind="${1:-auto}"
  local picked
  picked="$(
    devices_json | KIND="${kind}" python3 -c '
import json, os, sys

kind = os.environ.get("KIND", "auto")
raw = sys.stdin.read().strip()
try:
    devices = json.loads(raw) if raw else []
except json.JSONDecodeError:
    devices = []

def platform(device):
    return (device.get("targetPlatform") or "").lower()

def sdk(device):
    return (device.get("sdk") or "").lower()

def is_apple(device):
    return platform(device).startswith("ios") or sdk(device).startswith("ios")

def is_android(device):
    return platform(device).startswith("android") or (device.get("id") or "").startswith("emulator-")

def usable(device):
    return device.get("isSupported", True)

apple_sims = [d for d in devices if usable(d) and is_apple(d) and d.get("emulator")]
apple_phys = [d for d in devices if usable(d) and is_apple(d)]
android_emus = [d for d in devices if usable(d) and is_android(d) and d.get("emulator")]
android_phys = [d for d in devices if usable(d) and is_android(d) and not d.get("emulator")]

order = {
    "ios": apple_sims + apple_phys,
    # Эмулятор удобнее для демо; подключённый телефон — запасной вариант.
    "android": android_emus + android_phys,
    "auto": apple_sims + android_emus + apple_phys + android_phys,
}.get(kind, [])

print(order[0]["id"] if order else "")
'
  )"
  if [[ -z "${picked}" && "${kind}" == "ios" ]]; then
    # `flutter devices` не видит симулятор, если он не поднят: simctl всё равно
    # знает booted-устройство и его UDID.
    picked="$(booted_simulator)"
  fi
  printf '%s' "${picked}"
}

case "${TARGET}" in
  ios|iphone|ipad) DEVICE="$(pick_device ios)" ;;
  android)         DEVICE="$(pick_device android)" ;;
  auto)            DEVICE="$(pick_device auto)" ;;
  *)               DEVICE="${TARGET}" ;;
esac

if [[ -z "${DEVICE}" ]]; then
  echo "Не найдено устройство." >&2
  echo "iOS-симулятор: откройте его (open -a Simulator) или запустите" >&2
  echo "  xcrun simctl boot 'iPhone 18 Pro'" >&2
  echo "Android: создайте AVD и запустите эмулятор." >&2
  echo >&2
  echo "Доступные устройства:" >&2
  flutter devices >&2
  exit 1
fi

echo "→ device: ${DEVICE} (API_MODE=${API_MODE:-embedded})"
# `dev.sh` поднимает внешний mock и передаёт API_MODE/API_BASE_URL в окружении:
# уважаем их, иначе приложение молча ушло бы в in-process mock на другом порту.
API_MODE="${API_MODE:-embedded}"
APP_ENV="${APP_ENV:-dev}"
DART_DEFINES=(--dart-define="API_MODE=${API_MODE}" --dart-define="APP_ENV=${APP_ENV}")
if [[ -n "${API_BASE_URL:-}" ]]; then
  DART_DEFINES+=(--dart-define="API_BASE_URL=${API_BASE_URL}")
fi
exec flutter run -d "${DEVICE}" "${DART_DEFINES[@]}" "$@"
