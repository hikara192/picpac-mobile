#!/usr/bin/env bash
# Proves the HEIC → JPEG path on this Mac without building the app.
#
# Compiles the same `MediaConverter.swift` the iOS app links (it has no Flutter
# imports on purpose) together with a small driver, converts the committed
# fixtures and prints: magic bytes, geometry, EXIF/GPS presence, size, time.
#
# Usage: scripts/fixtures/verify-conversion.sh
# Exit code 1 when a conversion does not produce a JPEG or leaves metadata behind.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/picpac-verify.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# Top-level code is only allowed in a file called main.swift when several files
# are compiled together, so the driver is copied under that name.
cp "$here/verify_conversion.swift" "$work/main.swift"
swiftc -O -o "$work/verify" \
  "$root/ios/Runner/MediaConverter.swift" \
  "$work/main.swift"

status=0
for fixture in \
  "heic/gradient_640x480.heic" \
  "heic/portrait_orientation6.heic" \
  "heic/with_gps.heic" \
  "jpeg/with_gps.jpg" \
  "heic/spoofed_heic.jpg"; do
  echo "--- $fixture"
  out="$work/$(basename "$fixture").jpg"
  if ! "$work/verify" "$root/test/fixtures/$fixture" "$out"; then
    status=1
  fi
  # Independently of the framework: does the file still contain EXIF or GPS?
  if grep -a -q "Exif" "$out"; then
    echo "FAIL: the output still contains an Exif marker"
    status=1
  fi
  if grep -a -q "GPS" "$out"; then
    echo "FAIL: the output still contains GPS text"
    status=1
  fi
  if grep -a -q "Fixture Camera" "$out"; then
    echo "FAIL: the output still contains the camera model"
    status=1
  fi
  echo "output: file(1) => $(file -b "$out")"
  echo "output: xxd     => $(xxd -l 3 -p "$out")"
done

echo "--- PNG is not converted by the platform (Dart copies the bytes)"
echo "input png sha256: $(shasum -a 256 "$root/test/fixtures/png/gradient_320x240.png" | cut -d' ' -f1)"

exit "$status"
