import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/render/pdf_exporter.dart';
import 'package:picpac_mobile/render/sheet_layout.dart';
import 'package:picpac_mobile/render/sheet_painter.dart';

import 'support/render_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dpi = 150;
  const pageSide = 150.0;

  Uint8List embeddedJpeg(Uint8List pdf) {
    var start = -1;
    for (var index = 0; index + 2 < pdf.length; index++) {
      if (pdf[index] == 0xFF &&
          pdf[index + 1] == 0xD8 &&
          pdf[index + 2] == 0xFF) {
        start = index;
        break;
      }
    }
    expect(start, isNonNegative, reason: 'the page must embed a JPEG');
    var end = -1;
    for (var index = pdf.length - 2; index > start; index--) {
      if (pdf[index] == 0xFF && pdf[index + 1] == 0xD9) {
        end = index + 2;
        break;
      }
    }
    expect(end, greaterThan(start), reason: 'the JPEG must be terminated');
    return Uint8List.sublistView(pdf, start, end);
  }

  Future<Uint8List> decode(Uint8List jpeg) async {
    final codec = await ui.instantiateImageCodec(jpeg);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    codec.dispose();
    return data!.buffer.asUint8List();
  }

  const samples = <Offset>[
    Offset(20, 20),
    Offset(55, 20),
    Offset(95, 20),
    Offset(130, 20),
    Offset(20, 55),
    Offset(130, 55),
    Offset(20, 95),
    Offset(130, 95),
    Offset(20, 130),
    Offset(55, 130),
    Offset(95, 130),
    Offset(130, 130),
  ];

  test('повёрнутый слот в PDF совпадает с превью (≤2/255)', () async {
    final fixture = await RenderFixture.create(
      slots: (photoId) => <Slot>[
        Slot(
          id: 'main',
          photoId: photoId,
          rotation: QuarterTurn.cw90,
          flipH: true,
        ),
      ],
    );
    addTearDown(fixture.dispose);

    final started = DateTime.now();
    final pdf = await PdfExporter.exportSheets(
      document: fixture.document,
      spec: fixture.spec,
      images: fixture.store,
      options: const PdfExportOptions(dpi: dpi, useIsolate: false),
    );
    final elapsed = DateTime.now().difference(started);
    debugPrint('pdf: one 150 px page in ${elapsed.inMilliseconds} ms');

    final layout = SheetLayout(
      spread: fixture.spread,
      template: fixture.template,
      spec: fixture.spec,
      area: const Size(pageSide, pageSide),
    );
    final preview = await renderSheetToImage(
      layout: layout,
      document: fixture.document,
      images: fixture.store,
      pixelSize: const Size(pageSide, pageSide),
    );
    addTearDown(preview!.dispose);
    final previewPixels = await rawPixels(preview);
    final pdfPixels = await decode(embeddedJpeg(pdf));

    var maxDelta = 0;
    for (final point in samples) {
      final x = point.dx.round();
      final y = point.dy.round();
      final fromPdf = pixelAt(pdfPixels, pageSide.round(), x, y);
      final fromPreview = pixelAt(previewPixels, pageSide.round(), x, y);
      for (final pair in <(double, double)>[
        (fromPdf.r, fromPreview.r),
        (fromPdf.g, fromPreview.g),
        (fromPdf.b, fromPreview.b),
      ]) {
        final delta = ((pair.$1 - pair.$2) * 255).abs().round();
        if (delta > maxDelta) maxDelta = delta;
      }
    }
    expect(
      maxDelta,
      lessThanOrEqualTo(2),
      reason: 'the printed page must be the preview, not a re-interpretation',
    );

    expect(
      colorWithin(
        pixelAt(pdfPixels, pageSide.round(), 20, 20),
        const Color(0xFFFFFFFF),
      ),
      isTrue,
    );
  });

  test('10 листов с поворотами: постранично, без падения, с прогрессом', () async {
    final fixture = await RenderFixture.create(
      slots: (photoId) => <Slot>[
        Slot(id: 'main', photoId: photoId, rotation: QuarterTurn.cw90),
      ],
    );
    addTearDown(fixture.dispose);
    final base = fixture.spread;
    final document = fixture.document.copyWith(
      spreads: <Spread>[
        for (var index = 0; index < 10; index++)
          base.copyWith(
            id: 'sheet_${index + 1}',
            slots: <Slot>[
              base.slots.single.copyWith(
                rotation: QuarterTurn.fromDegrees((index * 90) % 360),
                flipH: index.isOdd,
              ),
            ],
          ),
      ],
      spreadsCount: 10,
    );

    final progress = <int>[];
    final stopwatch = Stopwatch()..start();
    final pdf = await PdfExporter.exportSheets(
      document: document,
      spec: fixture.spec,
      images: fixture.store,
      options: const PdfExportOptions(dpi: dpi, useIsolate: false),
      onProgress: (done, total) {
        expect(total, 10);
        progress.add(done);
      },
    );
    stopwatch.stop();

    expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
    expect(
      RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(pdf)),
      hasLength(10),
    );
    expect(progress, <int>[for (var index = 1; index <= 10; index++) index]);
    debugPrint(
      'pdf: 10 sheets @ $dpi dpi in ${stopwatch.elapsedMilliseconds} ms, '
      '${(pdf.length / 1024).toStringAsFixed(1)} KiB',
    );
    expect(pdf.length, greaterThan(10 * 1024));
  });
}
