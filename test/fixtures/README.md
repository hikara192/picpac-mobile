# Media fixtures

Synthetic images for the import pipeline: HEIC/HEIF → JPEG on device, metadata
stripping, mime spoofing. **No photos of people, no real GPS** — the coordinates
are Minsk, written by the generator on purpose so the removal test has something
to detect.

Generated on macOS with `scripts/fixtures/make-heic.sh` (ImageIO + `sips`,
`scripts/fixtures/inject_metadata.swift` for the metadata). Commit the files:
`dart:ui` cannot encode HEIC, so a device test cannot produce them at runtime.

## Files

| File | Size | Pixels / orientation | Metadata | What it proves |
|---|---|---|---|---|
| `heic/gradient_640x480.heic` | 3 514 B | 640×480, orientation 1 | none | baseline HEIC → JPEG, dimensions kept |
| `heic/portrait_orientation6.heic` | 4 177 B | 640×480 pixels, orientation **6** | EXIF (make/model/date) | orientation is baked into pixels: output is **480×640** (portrait), the tag is gone |
| `heic/with_gps.heic` | 2 299 B | 320×240, orientation 1 | EXIF + **GPS** | GPS is removed |
| `jpeg/with_gps.jpg` | 6 246 B | 320×240 | EXIF + **GPS** | the JPEG branch strips GPS too (re-encode, not copy) |
| `jpeg/gradient_320x240.jpg` | 6 112 B | 320×240 | EXIF, no GPS | metadata-free JPEG used as the fake normaliser output in host tests |
| `png/gradient_320x240.png` | 2 584 B | 320×240 | none (no `eXIf`, no XMP) | PNG is copied byte for byte and keeps its hash |
| `heic/spoofed_heic.jpg` | 3 514 B | 640×480 HEIC bytes, name says `.jpg` | none | detection follows the magic bytes, not the extension |
| `heic/spoofed_jpeg.heic` | 6 112 B | 320×240 JPEG bytes, name says `.heic` | EXIF | the reverse spoof: a HEIC name is not a HEIC file |

`file(1)` output for the two spoofs is part of the contract:
`spoofed_heic.jpg` → `ISO Media, HEIF Image HEVC`, `spoofed_jpeg.heic` →
`JPEG image data`.

## SHA-256

```
411163a9ce06835d429abecc8ff81d5806e1aabf930948af000e2167c8d8d387  heic/gradient_640x480.heic
07b0241478d11def8cf845ecb964ce5f4f3f4ea2d76e190d0f84eee9eab86473  heic/portrait_orientation6.heic
411163a9ce06835d429abecc8ff81d5806e1aabf930948af000e2167c8d8d387  heic/spoofed_heic.jpg
7c8ac0e658dfe7d2f301fe920df1e0aa8cb6efeb6b114ad91b8f62617b2c2151  heic/spoofed_jpeg.heic
d0d3fd8e99349476a9228194fd4c7c39fe732d37052886d350851d5866d1d44d  heic/with_gps.heic
7c8ac0e658dfe7d2f301fe920df1e0aa8cb6efeb6b114ad91b8f62617b2c2151  jpeg/gradient_320x240.jpg
6ffdd8427cf6be0e35cf41fa2be3e6fcc18acd79c3118ff48e9d886716c9b9df  jpeg/with_gps.jpg
01387acd73b9d037ca7ae95442a4d5ee1af6a74c9c8b0dc7cff14aa71ca787cf  png/gradient_320x240.png
```

The HEIC encoder is the OS one, so a regenerated file on another macOS version
may differ byte-wise while staying equivalent. `scripts/fixtures/make-heic.sh
--check` reports such differences without failing: the committed files are the
reference, and only the PNG/JPEG geometry and metadata assertions are hard gates.

## Regenerating

```sh
scripts/fixtures/make-heic.sh          # rewrite test/fixtures/
scripts/fixtures/make-heic.sh --check  # regenerate in a temp dir, compare hashes
```

macOS only (ImageIO). CI and device tests never run the script — they read the
committed bytes.

## How they are used

* host tests (`flutter test`): mime sniffing, import policy, dedupe, and the
  fake normaliser (`test/features/support/design_harness.dart`);
* device tests (`integration_test/media_normalizer_test.dart`): the real
  platform channel converts the real HEIC and the test asserts magic bytes,
  dimensions and the absence of EXIF/GPS.
