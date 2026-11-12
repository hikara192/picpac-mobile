import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:picpac_mobile/core/media/asset_cache.dart';
import 'package:picpac_mobile/render/asset_image_store.dart';

final class RenderFixture {
  RenderFixture._({
    required this.root,
    required this.document,
    required this.store,
    required this.spec,
    required this.template,
    required this.photo,
    required this.photoSize,
  });

  final Directory root;

  final DesignDocument document;

  final AssetImageStore store;

  final PrintSpec spec;

  final PrintTemplate template;

  final PhotoAsset photo;

  final Size photoSize;

  static Future<RenderFixture> create({
    List<Color> colours = const <Color>[
      Color(0xFFFF0000),
      Color(0xFF00FF00),
      Color(0xFF0000FF),
      Color(0xFFFFFFFF),
    ],
    int width = 40,
    int height = 40,
    PrintSpec spec = const PrintSpec(widthMm: 25.4, heightMm: 25.4),
    PrintTemplate template = BuiltInTemplates.single10x15,
    List<Slot> Function(String photoId)? slots,
  }) async {
    final root = await Directory.systemTemp.createTemp('picpac_render_');
    final image = await _quadrants(colours, width, height);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final bytes = png!.buffer.asUint8List();
    final hash = sha256.convert(bytes).toString();

    final source = File('${root.path}/source.png');
    await source.writeAsBytes(bytes, flush: true);
    final cache = DesignAssetCache(rootDirectory: () async => root);
    await cache.store(designId: _designId, sha256: hash, source: source);

    final photo = PhotoAsset(
      id: 'p0',
      sha256: hash,
      widthPx: width,
      heightPx: height,
      mimeType: 'image/png',
      bytes: bytes.length,
    );
    final slotList =
        slots?.call(photo.id) ??
        <Slot>[Slot(id: template.slots.first.id, photoId: photo.id)];
    final document = DesignDocument(
      product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
      spreads: <Spread>[
        Spread(
          id: 'sheet_1',
          templateId: template.id,
          background: SpreadBackground.color('#FFFFFF'),
          slots: slotList,
        ),
      ],
      spreadsCount: 1,
      assets: <PhotoAsset>[photo],
    );

    final store = AssetImageStore(cache: cache, designId: _designId);
    await store.preload(<String>[hash]);

    return RenderFixture._(
      root: root,
      document: document,
      store: store,
      spec: spec,
      template: template,
      photo: photo,
      photoSize: Size(width.toDouble(), height.toDouble()),
    );
  }

  static const String _designId = 'render_fixture';

  Future<void> dispose() async {
    store.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  }

  Spread get spread => document.spreads.first;

  static Future<ui.Image> _quadrants(
    List<Color> colours,
    int width,
    int height,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final halfW = width / 2;
    final halfH = height / 2;
    final rects = <Rect>[
      Rect.fromLTWH(0, 0, halfW, halfH),
      Rect.fromLTWH(halfW, 0, halfW, halfH),
      Rect.fromLTWH(0, halfH, halfW, halfH),
      Rect.fromLTWH(halfW, halfH, halfW, halfH),
    ];
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(rects[i], Paint()..color = colours[i]);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  }
}

Future<Uint8List> rawPixels(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

Color pixelAt(Uint8List rgba, int width, int x, int y) {
  final offset = (y * width + x) * 4;
  return Color.fromARGB(
    rgba[offset + 3],
    rgba[offset],
    rgba[offset + 1],
    rgba[offset + 2],
  );
}

bool colorWithin(Color actual, Color expected, {int tolerance = 2}) {
  int channel(double value) => (value * 255).round();
  return (channel(actual.r) - channel(expected.r)).abs() <= tolerance &&
      (channel(actual.g) - channel(expected.g)).abs() <= tolerance &&
      (channel(actual.b) - channel(expected.b)).abs() <= tolerance;
}

({int maxDelta, double outliers}) compareBuffers(
  Uint8List a,
  Uint8List b, {
  int tolerance = 2,
}) {
  var maxDelta = 0;
  var outliers = 0;
  var pixels = 0;
  for (var i = 0; i + 3 < a.length; i += 4) {
    pixels++;
    var outside = false;
    for (var channel = 0; channel < 3; channel++) {
      final delta = (a[i + channel] - b[i + channel]).abs();
      if (delta > maxDelta) maxDelta = delta;
      if (delta > tolerance) outside = true;
    }
    if (outside) outliers++;
  }
  return (maxDelta: maxDelta, outliers: pixels == 0 ? 0 : outliers / pixels);
}
