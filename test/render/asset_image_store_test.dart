import 'dart:async';
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
    root = await Directory.systemTemp.createTemp('picpac_store_');
    cache = DesignAssetCache(rootDirectory: () async => root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<String> seedHash(String hash, {int bytes = 16}) async {
    final directory = await cache.directoryFor('dsg_store');
    await directory.create(recursive: true);
    final file = File('${directory.path}/$hash');
    await file.writeAsBytes(List<int>.filled(bytes, 7), flush: true);
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

  PreviewDecoder countingDecoder(
    void Function(int active, int peak) onSample, {
    Duration hold = const Duration(milliseconds: 10),
    Size size = const Size(8, 8),
  }) {
    var active = 0;
    var peak = 0;
    return (String path, int maxSide) async {
      active++;
      if (active > peak) peak = active;
      onSample(active, peak);
      await Future<void>.delayed(hold);
      active--;
      return image(size.width.round(), size.height.round());
    };
  }

  test('кеш держит бюджет 64 MiB', () {
    final store = AssetImageStore(cache: cache, designId: 'dsg_store');
    addTearDown(store.dispose);
    expect(store.budgetBytes, 64 * 1024 * 1024);
    expect(kAssetCacheBudgetBytes, 64 * 1024 * 1024);
  });

  test('10 запросов разом: одновременно декодируется не больше двух', () async {
    final hashes = <String>[for (var i = 0; i < 10; i++) await seedHash('a$i')];
    var peak = 0;
    final store = AssetImageStore(
      cache: cache,
      designId: 'dsg_store',
      decode: countingDecoder((active, max) => peak = max),
    );
    addTearDown(store.dispose);

    store.requestAll(hashes);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(peak, lessThanOrEqualTo(2), reason: 'семафор на два декода');
    expect(peak, 2, reason: 'два слота должны быть заняты, а не один');
    for (final hash in hashes) {
      expect(store.isLoaded(hash), isTrue, reason: hash);
    }
    expect(store.activeDecodes, 0);
  });

  test('prefetch: три одновременных декода, ни одного больше', () async {
    final hashes = <String>[for (var i = 0; i < 9; i++) await seedHash('p$i')];
    var peak = 0;
    final store = AssetImageStore(
      cache: cache,
      designId: 'dsg_store',
      decode: countingDecoder((active, max) => peak = max),
    );
    addTearDown(store.dispose);

    await store.preload(hashes);

    expect(peak, lessThanOrEqualTo(3));
    expect(peak, 3);
    expect(store.activeDecodes, 0);
    expect(store.cachedTextures, 9);
  });

  test('кеш не превышает бюджет и выбрасывает самый старый', () async {
    final hashes = <String>[for (var i = 0; i < 3; i++) await seedHash('b$i')];
    const budget = 9 * 1024 * 1024;
    final store = AssetImageStore(
      cache: cache,
      designId: 'dsg_store',
      budgetBytes: budget,
      decode: (String path, int maxSide) => image(1024, 1024),
    );
    addTearDown(store.dispose);

    await store.preload(hashes);

    expect(store.cachedBytes, lessThanOrEqualTo(budget));
    expect(store.cachedTextures, 2);
    expect(store.isLoaded(hashes.first), isFalse, reason: 'выброшен LRU');
    expect(store.isLoaded(hashes.last), isTrue);
  });

  test('декод получает путь файла, а не байты в куче', () async {
    final hash = await seedHash('c0');
    final paths = <String>[];
    final store = AssetImageStore(
      cache: cache,
      designId: 'dsg_store',
      decode: (String path, int maxSide) async {
        paths.add(path);
        return image(4, 4);
      },
    );
    addTearDown(store.dispose);

    await store.preload(<String>[hash]);

    expect(paths, hasLength(1));
    expect(paths.single, endsWith(hash));
    expect(File(paths.single).existsSync(), isTrue);
    expect(store.cachedBytes, 4 * 4 * 4);
  });

  test(
    'clear освобождает слоты: отменённые декоды не держат семафор',
    () async {
      final hashes = <String>[
        for (var i = 0; i < 6; i++) await seedHash('d$i'),
      ];
      final gates = <Completer<ui.Image?>>[];
      final store = AssetImageStore(
        cache: cache,
        designId: 'dsg_store',
        decode: (String path, int maxSide) {
          final gate = Completer<ui.Image?>();
          gates.add(gate);
          return gate.future;
        },
      );
      addTearDown(store.dispose);

      store.requestAll(hashes);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(store.activeDecodes, 2, reason: 'два слота заняты');
      expect(store.waitingDecodes, 4, reason: 'остальные ждут');

      store.clear();
      for (final gate in gates) {
        if (!gate.isCompleted) gate.complete(await image(2, 2));
      }
      gates.clear();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(store.activeDecodes, 0, reason: 'слоты свободны после отмены');
      expect(store.waitingDecodes, 0);
      expect(
        store.cachedTextures,
        0,
        reason: 'отменённые декоды ничего не пишут',
      );

      store.request(hashes.first);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(gates, hasLength(1), reason: 'слот свободен, декод начался');
      gates.single.complete(await image(2, 2));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(store.isLoaded(hashes.first), isTrue);
    },
  );

  test('dispose освобождает ожидающих и не пишет в кеш', () async {
    final hashes = <String>[for (var i = 0; i < 4; i++) await seedHash('e$i')];
    final store = AssetImageStore(
      cache: cache,
      designId: 'dsg_store',
      decode: (String path, int maxSide) => image(2, 2),
    );
    store.requestAll(hashes);
    store.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.cachedTextures, 0);
  });
}
