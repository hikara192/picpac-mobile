import 'dart:ui' as ui;

import 'package:api_contract/api_contract.dart' show ProductFormat;
import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/core/media/asset_cache.dart';
import 'package:picpac_mobile/render/asset_image_store.dart';
import 'package:picpac_mobile/render/sheet_layout.dart';
import 'package:picpac_mobile/render/sheet_painter.dart';

import '../features/support/design_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const goldenSize = Size(600, 894);

  test('golden: лист 10×15 с одним фото', () async {
    final harness = await DesignHarness.create();
    addTearDown(harness.dispose);
    final document = await harness.seedPhotos(
      count: 1,
      designId: 'golden_single',
    );
    final images = await _storeFor(harness, document, 'golden_single');
    addTearDown(images.dispose);

    final layout = _layoutFor(harness.format, document, goldenSize);
    final png = await _render(layout, document, images, goldenSize);

    await expectLater(png, matchesGoldenFile('goldens/sheet_10x15.png'));
  });

  test('golden: коллаж quad_10x15 на четырёх фото', () async {
    final harness = await DesignHarness.create();
    addTearDown(harness.dispose);
    final quad = harness.format.templates
        .firstWhere((template) => template.id == 'quad_10x15')
        .toPrintTemplate();
    final seeded = await harness.seedPhotos(count: 4, designId: 'golden_quad');
    final document = AutoLayoutSheets(template: quad).applyCore(seeded);
    expect(document.spreads.single.slots, hasLength(4));
    final images = await _storeFor(harness, document, 'golden_quad');
    addTearDown(images.dispose);

    final layout = _layoutFor(
      harness.format,
      document,
      goldenSize,
      templateId: 'quad_10x15',
    );
    final png = await _render(layout, document, images, goldenSize);

    await expectLater(png, matchesGoldenFile('goldens/collage_quad_10x15.png'));
  });
}

Future<AssetImageStore> _storeFor(
  DesignHarness harness,
  DesignDocument document,
  String designId,
) async {
  final cache = DesignAssetCache(rootDirectory: () async => harness.root);
  final store = AssetImageStore(cache: cache, designId: designId);
  await store.preload(document.assets.map((asset) => asset.sha256));
  return store;
}

SheetLayout _layoutFor(
  ProductFormat format,
  DesignDocument document,
  Size size, {
  String? templateId,
}) {
  final spread = document.spreads.first;
  final template = format.templates
      .firstWhere(
        (candidate) => candidate.id == (templateId ?? spread.templateId),
      )
      .toPrintTemplate();
  return SheetLayout(
    spread: spread,
    template: template,
    spec: format.toPrintSpec(),
    area: size,
  );
}

Future<Future<List<int>>> _render(
  SheetLayout layout,
  DesignDocument document,
  AssetImageStore images,
  Size size,
) async {
  final image = await renderSheetToImage(
    layout: layout,
    document: document,
    images: images,
    pixelSize: size,
  );
  final data = await image!.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return Future<List<int>>.value(data!.buffer.asUint8List());
}
