import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/render/jpeg_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List gradient({
    int width = 64,
    int height = 48,
    bool sharpBlock = true,
  }) {
    final rgba = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = (y * width + x) * 4;
        final inBlock = sharpBlock && x > width ~/ 2 && y > height ~/ 2;
        rgba[offset] = inBlock ? 220 : x * 255 ~/ width;
        rgba[offset + 1] = inBlock ? 40 : y * 255 ~/ height;
        rgba[offset + 2] = inBlock ? 30 : 128;
        rgba[offset + 3] = 255;
      }
    }
    return rgba;
  }

  test('produces a JFIF stream with SOI/EOI markers', () {
    final bytes = encodeJpeg(rgba: gradient(), width: 64, height: 48);
    expect(bytes.sublist(0, 2), <int>[0xFF, 0xD8]);
    expect(bytes.sublist(bytes.length - 2), <int>[0xFF, 0xD9]);
    expect(bytes.sublist(2, 6), <int>[0xFF, 0xE0, 0x00, 0x10]);
    expect(String.fromCharCodes(bytes.sublist(6, 10)), 'JFIF');
  });

  test('the engine can decode it back to the same size', () async {
    const width = 64;
    const height = 48;
    final bytes = encodeJpeg(rgba: gradient(), width: width, height: height);
    final image = await _decode(bytes);
    addTearDown(image.dispose);
    expect(image.width, width);
    expect(image.height, height);
  });

  test('pixels survive q91 within a few units', () async {
    const width = 64;
    const height = 48;
    final source = gradient(width: width, height: height, sharpBlock: false);
    final bytes = encodeJpeg(
      rgba: source,
      width: width,
      height: height,
      quality: 91,
    );
    final image = await _decode(bytes);
    addTearDown(image.dispose);
    final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    var worst = 0;
    for (var i = 0; i < pixels.length; i += 4) {
      for (var channel = 0; channel < 3; channel++) {
        final delta = (pixels[i + channel] - source[i + channel]).abs();
        if (delta > worst) worst = delta;
      }
    }
    expect(
      worst,
      lessThanOrEqualTo(6),
      reason: 'q91 keeps a smooth gradient within a few units',
    );
  });

  test('is byte-for-byte deterministic', () {
    final source = gradient();
    final first = encodeJpeg(rgba: source, width: 64, height: 48);
    final second = encodeJpeg(rgba: source, width: 64, height: 48);
    expect(second, first);
  });

  test('quality trades size for fidelity', () {
    final source = gradient(width: 128, height: 96);
    final low = encodeJpeg(rgba: source, width: 128, height: 96, quality: 50);
    final high = encodeJpeg(rgba: source, width: 128, height: 96, quality: 92);
    expect(high.length, greaterThan(low.length));
  });

  test('writes no EXIF, GPS or ICC metadata', () {
    final bytes = encodeJpeg(rgba: gradient(), width: 64, height: 48);
    final text = String.fromCharCodes(bytes);
    expect(text.contains('Exif'), isFalse);
    expect(text.contains('GPS'), isFalse);
    expect(text.contains('ICC_PROFILE'), isFalse);
    var appMarkers = 0;
    for (var i = 0; i + 1 < bytes.length; i++) {
      if (bytes[i] == 0xFF && bytes[i + 1] >= 0xE0 && bytes[i + 1] <= 0xEF) {
        appMarkers++;
      }
    }
    expect(appMarkers, 1);
  });

  test('rejects a buffer smaller than width × height × 4', () {
    expect(
      () => encodeJpeg(rgba: Uint8List(16), width: 8, height: 8),
      throwsArgumentError,
    );
  });

  test('handles a size that is not a multiple of eight', () {
    final source = gradient(width: 13, height: 7);
    final bytes = encodeJpeg(rgba: source, width: 13, height: 7);
    expect(bytes.length, greaterThan(100));
  });
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}
