import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/render/cpu_pipeline.dart';

import 'support/render_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sRGB lookup tables', () {
    test('decode/encode round-trips every byte within 1/255', () {
      final luts = SrgbLuts.standard;
      var worst = 0;
      for (var byte = 0; byte < 256; byte++) {
        final linear = luts.toLinear(byte);
        final reference = _srgbEncode(linear) * 255;
        final delta = (luts.toSrgbByte(linear) - reference).abs();
        if (delta > worst) worst = delta.round();
      }
      expect(worst, lessThanOrEqualTo(1));
    });

    test('clamps out-of-range and non-finite input instead of throwing', () {
      final luts = SrgbLuts.standard;
      expect(luts.toSrgbByte(-5), 0);
      expect(luts.toSrgbByte(5), 255);
      expect(luts.toSrgbByte(double.nan), 0);
    });
  });

  group('CpuPipeline.applyMatrix', () {
    Uint8List pixels() => Uint8List.fromList(<int>[
      10, 20, 30, 255, //
      200, 100, 50, 128, //
      0, 0, 0, 255, //
      255, 255, 255, 255, //
    ]);

    test('the identity matrix copies everything, alpha included', () {
      final source = pixels();
      final out = CpuPipeline.applyMatrix(
        rgba: source,
        matrix: AdjustmentMatrix.identity,
      );
      expect(out, source);
      expect(identical(out, source), isFalse, reason: 'must not alias input');
    });

    test('rejects a matrix that is not 4x5', () {
      expect(
        () => CpuPipeline.applyMatrix(
          rgba: pixels(),
          matrix: const <double>[1, 0, 0],
        ),
        throwsArgumentError,
      );
    });

    test('a +1 EV matrix doubles an encoded value and clamps at 255', () {
      const adjustment = PhotoAdjustment(exposure: 1);
      final out = CpuPipeline.applyAdjustment(
        rgba: pixels(),
        adjustment: adjustment,
      );
      expect(out[0], 20);
      expect(out[1], 40);
      expect(out[2], 60);
      expect(out[3], 255);
      for (var i = 0; i < 3; i++) {
        expect(out[4 + i], lessThanOrEqualTo(255));
      }
    });

    test('the mono look produces equal channels', () {
      final out = CpuPipeline.applyAdjustment(
        rgba: pixels(),
        adjustment: const PhotoAdjustment(
          look: LookSetting(id: 'mono', strength: 1),
        ),
      );
      for (var i = 0; i < 4; i++) {
        final offset = i * 4;
        expect(out[offset], out[offset + 1]);
        expect(out[offset + 1], out[offset + 2]);
      }
    });

    test('is deterministic', () {
      const adjustment = PhotoAdjustment(
        exposure: 0.4,
        contrast: 12,
        temperature: 15,
        saturation: -10,
      );
      final first = CpuPipeline.applyAdjustment(
        rgba: pixels(),
        adjustment: adjustment,
      );
      final second = CpuPipeline.applyAdjustment(
        rgba: pixels(),
        adjustment: adjustment,
      );
      expect(second, first);
    });

    test('the linear path is a real linear-light pass', () {
      final luts = SrgbLuts.standard;
      final grey = Uint8List.fromList(<int>[128, 128, 128, 255]);
      final out = CpuPipeline.applyAdjustment(
        rgba: grey,
        adjustment: const PhotoAdjustment(exposure: 1),
        space: CpuColorSpace.linear,
        luts: luts,
      );
      final expected = luts.toSrgbByte(luts.toLinear(128) * 2);
      expect((out[0] - expected).abs(), lessThanOrEqualTo(1));
      final encoded = CpuPipeline.applyAdjustment(
        rgba: grey,
        adjustment: const PhotoAdjustment(exposure: 1),
      );
      expect(encoded[0], greaterThan(out[0]));
    });
  });

  group('preview and export agree', () {
    test(
      'ColorFilter.matrix and the CPU pass differ by at most 2/255',
      () async {
        const width = 32;
        const height = 32;
        final source = Uint8List(width * height * 4);
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final offset = (y * width + x) * 4;
            source[offset] = (x * 255 ~/ width);
            source[offset + 1] = (y * 255 ~/ height);
            source[offset + 2] = ((x + y) * 255 ~/ (width + height));
            source[offset + 3] = 255;
          }
        }

        const adjustment = PhotoAdjustment(
          exposure: 0.35,
          contrast: 18,
          temperature: 12,
          saturation: -6,
          look: LookSetting(id: 'film', strength: 0.7),
        );
        final matrix = AdjustmentMatrix.encoded(adjustment);

        final preview = await _drawWithColorFilter(
          source,
          width,
          height,
          matrix,
        );
        final cpu = CpuPipeline.applyAdjustment(
          rgba: source,
          adjustment: adjustment,
        );
        final comparison = compareBuffers(preview, cpu);
        expect(
          comparison.maxDelta,
          lessThanOrEqualTo(2),
          reason: 'the same matrix must give the same pixels',
        );
        expect(comparison.outliers, lessThan(0.01));
      },
    );
  });
}

Future<Uint8List> _drawWithColorFilter(
  Uint8List rgba,
  int width,
  int height,
  List<double> matrix,
) async {
  final image = await _decode(rgba, width, height);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..colorFilter = ColorFilter.matrix(matrix),
  );
  final picture = recorder.endRecording();
  final rendered = await picture.toImage(width, height);
  picture.dispose();
  image.dispose();
  final bytes = await rawPixels(rendered);
  rendered.dispose();
  return bytes;
}

Future<ui.Image> _decode(Uint8List rgba, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

double _srgbEncode(double linear) => linear <= 0.0031308
    ? linear * 12.92
    : 1.055 * math.pow(linear, 1 / 2.4) - 0.055;
