import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/core/media/asset_cache.dart';
import 'package:picpac_mobile/render/asset_image_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late DesignAssetCache cache;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('picpac_decode_');
    cache = DesignAssetCache(rootDirectory: () async => root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<String> seedHash(String hash) async {
    final directory = await cache.directoryFor('dsg_decode');
    await directory.create(recursive: true);
    await File('${directory.path}/$hash')
        .writeAsBytes(List<int>.filled(16, 7), flush: true);
    return hash;
  }

  Future<ui.Image> image(int width, int height) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF335577),
    );
    final picture = recorder.endRecording();
    final result = await picture.toImage(width, height);
    picture.dispose();
    return result;
  }

  test('слот 30×45 просит печатный размер, а не 2048 px', () {
    final side = slotDecodeSidePx(widthMm: 457, heightMm: 305, dpi: 300);
    expect(side, greaterThanOrEqualTo(3543));
    expect(side, 5398);
  });

  test('zoom увеличивает запрос, но не выше оригинала', () {
    final base = slotDecodeSidePx(
      widthMm: 100,
      heightMm: 150,
      dpi: 300,
      zoom: 2,
    );
    expect(base, 3544); // 300 mm effective long side.
    expect(
      boundedDecodeSide(target: base, intrinsicSide: 3000),
      3000,
      reason: 'декодер не должен растягивать маленький оригинал',
    );
  });

  test('кеш декодирует в запрошенном размере и не апскейлит', () async {
    final hash = await seedHash('size_1');
    final store = AssetImageStore(
      cache: cache,
      designId: 'dsg_decode',
      decode: (String path, int maxSide) => image(8, 8),
    );
    addTearDown(store.dispose);

    store.request(hash, targetSide: 5398, intrinsicSide: 4000);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(store.requestedSideOf(hash), 4000);
    expect(store.decodedSides, contains(4000));
    expect(store.decodedSides, isNot(contains(5398)));
    expect(store.isLoaded(hash), isTrue);
  });
}
