#!/usr/bin/env bash
# Regenerates the media fixtures in test/fixtures/.
#
# Synthetic only: a colour gradient, never a photo of a person. macOS-only
# (ImageIO + sips); the files themselves are committed, so CI and every device
# test work without this script. See test/fixtures/README.md for sizes, contents
# and SHA-256.
#
# Usage: scripts/fixtures/make-heic.sh [--check]
#   --check  regenerate into a temporary directory and compare SHA-256 with the
#            committed files (encoder changes across macOS versions are expected,
#            so this is a report, not a gate).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
check=0
[[ "${1:-}" == "--check" ]] && check=1

out="$root/test/fixtures"
work="$(mktemp -d "${TMPDIR:-/tmp}/picpac-fixtures.XXXXXX")"
trap 'rm -rf "$work"' EXIT
if [[ $check -eq 1 ]]; then
  out="$work/out"
  mkdir -p "$out"
fi

mkdir -p "$out/heic" "$out/jpeg" "$out/png"

# 1. Deterministic gradients. Written with the Python standard library so the
#    script needs no third-party package (Pillow is not a project dependency).
python3 - "$work" <<'PY'
import struct, sys, zlib

def png(path, width, height):
    rows = bytearray()
    for y in range(height):
        # Filter "Sub" on every row: a horizontal gradient becomes almost
        # constant, so the fixture stays a few kilobytes instead of hundreds.
        rows.append(1)
        previous = (0, 0, 0)
        for x in range(width):
            # A smooth diagonal gradient: printable, and a single pixel can be
            # checked against sRGB on a device.
            r = (x * 255) // max(1, width - 1)
            g = (y * 255) // max(1, height - 1)
            b = ((x + y) * 255) // max(1, width + height - 2)
            rows += bytes(
                ((r - previous[0]) & 0xFF, (g - previous[1]) & 0xFF, (b - previous[2]) & 0xFF)
            )
            previous = (r, g, b)

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    raw = zlib.compress(bytes(rows), 9)
    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n")
        handle.write(chunk(b"IHDR", ihdr))
        handle.write(chunk(b"IDAT", raw))
        handle.write(chunk(b"IEND", b""))

work = sys.argv[1]
png(f"{work}/gradient_640x480.png", 640, 480)
png(f"{work}/gradient_320x240.png", 320, 240)
PY

# 2. HEIC/JPEG/PNG encoding and metadata injection through ImageIO. `sips` alone
#    cannot write GPS or an EXIF orientation, so one small Swift helper does it;
#    it is compiled on the fly by `swift` and needs no Xcode project.
swiftc -O -o "$work/inject" "$here/inject_metadata.swift"

# HEIC without any metadata: the plain sips path documented in the research.
sips -s format heic "$work/gradient_640x480.png" --out "$work/gradient_640x480.heic" >/dev/null

# HEIC with EXIF orientation 6 (display is portrait although the pixels are
# landscape): the transform must be baked into the output pixels.
"$work/inject" "$work/gradient_640x480.png" "$work/portrait_orientation6.heic" heic 6 0

# HEIC with an EXIF block and a GPS dictionary: the PII fixture.
"$work/inject" "$work/gradient_320x240.png" "$work/with_gps.heic" heic 1 1

# JPEG with GPS: the same leak on the second input format.
"$work/inject" "$work/gradient_320x240.png" "$work/with_gps.jpg" jpeg 1 1

# Metadata-free JPEG: the output bytes the fake normaliser writes in host tests.
"$work/inject" "$work/gradient_320x240.png" "$work/gradient_320x240.jpg" jpeg 1 0

# MIME spoof: HEIC bytes behind a `.jpg` name.
cp "$work/gradient_640x480.heic" "$work/spoofed_heic.jpg"

cp "$work/gradient_640x480.heic" "$out/heic/gradient_640x480.heic"
cp "$work/portrait_orientation6.heic" "$out/heic/portrait_orientation6.heic"
cp "$work/with_gps.heic" "$out/heic/with_gps.heic"
# MIME spoof, both directions: detection must follow the bytes, not the name.
cp "$work/gradient_640x480.heic" "$out/heic/spoofed_heic.jpg"
cp "$work/with_gps.jpg" "$out/jpeg/with_gps.jpg"
cp "$work/gradient_320x240.jpg" "$out/jpeg/gradient_320x240.jpg"
cp "$work/gradient_320x240.png" "$out/png/gradient_320x240.png"
# A JPEG named `.heic`: the other spoof direction.
cp "$work/gradient_320x240.jpg" "$out/heic/spoofed_jpeg.heic"

if [[ $check -eq 1 ]]; then
  echo "Regenerated into $out; comparing with the committed fixtures:"
  status=0
  while IFS= read -r file; do
    rel="${file#"$out"/}"
    committed="$root/test/fixtures/$rel"
    if [[ ! -f "$committed" ]]; then
      echo "MISSING  $rel"
      status=1
      continue
    fi
    a="$(shasum -a 256 "$file" | cut -d' ' -f1)"
    b="$(shasum -a 256 "$committed" | cut -d' ' -f1)"
    if [[ "$a" == "$b" ]]; then
      echo "SAME     $rel"
    else
      echo "DIFFERS  $rel ($a vs $b)"
    fi
  done < <(find "$out" -type f | sort)
  exit 0
fi

echo "Fixtures written to $out"
find "$out" -type f -exec shasum -a 256 {} \; | sort -k2
