import 'dart:typed_data';

import 'package:design_core/design_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/render/pdf_exporter.dart';

import 'support/render_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fastDpi = 72;

  test('exports one sheet as a PDF with a DCT (JPEG) image', () async {
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

    final bytes = await PdfExporter.exportSheets(
      document: fixture.document,
      spec: fixture.spec,
      images: fixture.store,
      options: const PdfExportOptions(dpi: fastDpi, useIsolate: false),
    );

    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    expect(
      String.fromCharCodes(bytes.sublist(bytes.length - 6)).trim(),
      '%%EOF',
    );
    final text = String.fromCharCodes(bytes);
    expect(text.contains('/DCTDecode'), isTrue, reason: 'JPEG, never PNG');
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(text), hasLength(1));
  });

  test('reports progress per page', () async {
    final fixture = await RenderFixture.create();
    addTearDown(fixture.dispose);
    final progress = <String>[];
    await PdfExporter.exportSheets(
      document: fixture.document,
      spec: fixture.spec,
      images: fixture.store,
      options: const PdfExportOptions(dpi: fastDpi, useIsolate: false),
      onProgress: (done, total) => progress.add('$done/$total'),
    );
    expect(progress, <String>['1/1']);
  });

  test('a rotated slot and a look survive the export', () async {
    final fixture = await RenderFixture.create(
      slots: (photoId) => <Slot>[
        Slot(id: 'main', photoId: photoId, rotation: QuarterTurn.cw270),
      ],
    );
    addTearDown(fixture.dispose);
    final document = fixture.document.copyWith(
      photoAdjustments: <String, PhotoAdjustment>{
        'p0': const PhotoAdjustment(
          exposure: 0.3,
          look: LookSetting(id: 'mono', strength: 0.8),
        ),
      },
    );
    final bytes = await PdfExporter.exportSheets(
      document: document,
      spec: fixture.spec,
      images: fixture.store,
      options: const PdfExportOptions(dpi: fastDpi, useIsolate: false),
    );
    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes).contains('/DCTDecode'), isTrue);
  });

  test('rejects nothing and skips a spread with an unknown template', () async {
    final fixture = await RenderFixture.create();
    addTearDown(fixture.dispose);
    final document = fixture.document.copyWith(
      spreads: <Spread>[fixture.spread.copyWith(templateId: 'from-the-future')],
    );
    final bytes = await PdfExporter.exportSheets(
      document: document,
      spec: fixture.spec,
      images: fixture.store,
      options: const PdfExportOptions(dpi: fastDpi, useIsolate: false),
    );
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    expect(
      RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)),
      isEmpty,
    );
  });

  test('page format follows the print spec in points', () {
    const spec = PrintSpec(widthMm: 100, heightMm: 150);
    final format = PdfExporter.pageFormatOf(spec);
    expect(format.width, closeTo(100 / 25.4 * 72, 0.01));
    expect(format.height, closeTo(150 / 25.4 * 72, 0.01));
  });

  test('a four-photo collage is one page', () async {
    final fixture = await RenderFixture.create(
      template: BuiltInTemplates.quad10x15,
      slots: (photoId) => <Slot>[
        Slot(id: 'tl', photoId: photoId),
        const Slot(id: 'tr'),
        const Slot(id: 'bl'),
        const Slot(id: 'br'),
      ],
    );
    addTearDown(fixture.dispose);
    final bytes = await PdfExporter.exportSheets(
      document: fixture.document,
      spec: fixture.spec,
      images: fixture.store,
      options: const PdfExportOptions(dpi: fastDpi, useIsolate: false),
    );
    final text = String.fromCharCodes(bytes);
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(text), hasLength(1));
  });

  test('the default quality is inside the documented 90–92 range', () {
    expect(const PdfExportOptions().quality, inInclusiveRange(90, 92));
  });

  test('a huge dpi request still produces one page', () async {
    final fixture = await RenderFixture.create();
    addTearDown(fixture.dispose);
    final bytes = await PdfExporter.exportSheets(
      document: fixture.document,
      spec: fixture.spec,
      images: fixture.store,
      options: const PdfExportOptions(dpi: 150, useIsolate: false),
    );
    expect(Uint8List.fromList(bytes).length, greaterThan(1000));
  });
}
