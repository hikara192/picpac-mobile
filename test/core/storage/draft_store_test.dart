import 'dart:convert';
import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/core/storage/app_database.dart';
import 'package:picpac_mobile/core/storage/draft_store.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late DraftStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('picpac_drafts_');
    database = AppDatabase(NativeDatabase.memory());
    store = DraftStore(
      database: database,
      rootDirectory: () async => root,
      debounce: const Duration(milliseconds: 20),
    );
  });

  tearDown(() async {
    await store.dispose();
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  DesignDocument documentAt(int revision) => DesignDocument(
    revision: revision,
    product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
    spreadsCount: revision,
  );

  Directory designDirectory(String designId) =>
      Directory('${root.path}/drafts/$designId');

  List<String> tempFiles(String designId) {
    final directory = designDirectory(designId);
    if (!directory.existsSync()) return const <String>[];
    return directory
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.tmp'))
        .toList();
  }

  test(
    '50 параллельных saveNow: файл валиден, ревизия максимальная, .tmp нет',
    () async {
      final writes = <Future<void>>[
        for (var revision = 1; revision <= 50; revision++)
          store.saveNow(
            documentAt(revision),
            designId: 'dsg_race',
            productId: 'photo_print',
          ),
      ];
      await Future.wait(writes);

      final raw = await File(
        '${designDirectory('dsg_race').path}/document.json',
      ).readAsString();
      final decoded = DesignDocument.fromJson(jsonDecode(raw));
      expect(decoded.isOk, isTrue, reason: '${decoded.failureOrNull}');
      expect(decoded.requireValue.revision, 50, reason: 'last writer wins');
      expect(tempFiles('dsg_race'), isEmpty);
    },
  );

  test(
    '50 scheduleSave одного дизайна: одно валидное тело, последняя ревизия',
    () async {
      for (var revision = 1; revision <= 50; revision++) {
        store.scheduleSave(
          documentAt(revision),
          designId: 'dsg_debounce',
          productId: 'photo_print',
        );
      }
      await store.flush();

      final raw = await File(
        '${designDirectory('dsg_debounce').path}/document.json',
      ).readAsString();
      final decoded = DesignDocument.fromJson(jsonDecode(raw));
      expect(decoded.isOk, isTrue, reason: '${decoded.failureOrNull}');
      expect(decoded.requireValue.revision, 50);
      expect(tempFiles('dsg_debounce'), isEmpty);
    },
  );

  test('разные дизайны пишутся параллельно и не мешают друг другу', () async {
    await Future.wait(<Future<void>>[
      for (var index = 0; index < 10; index++)
        store.saveNow(
          documentAt(index + 1),
          designId: 'dsg_$index',
          productId: 'photo_print',
        ),
    ]);

    for (var index = 0; index < 10; index++) {
      final loaded = await store.load('dsg_$index');
      expect(loaded?.revision, index + 1);
      expect(tempFiles('dsg_$index'), isEmpty);
    }
  });

  test('ошибка записи не оставляет .tmp и не блокирует следующие записи', () async {
    final directory = designDirectory('dsg_broken');
    await directory.create(recursive: true);
    await Directory('${directory.path}/document.json').create(recursive: true);

    await expectLater(
      store.saveNow(
        documentAt(1),
        designId: 'dsg_broken',
        productId: 'photo_print',
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      tempFiles('dsg_broken'),
      isEmpty,
      reason: 'a failed save must clean up its temp file',
    );

    await Directory('${directory.path}/document.json').delete(recursive: true);
    await store.saveNow(
      documentAt(2),
      designId: 'dsg_broken',
      productId: 'photo_print',
    );
    expect((await store.load('dsg_broken'))?.revision, 2);
    expect(tempFiles('dsg_broken'), isEmpty);
  });

  test('flush дожидается уже идущей записи, а не только дебаунса', () async {
    final write = store.saveNow(
      documentAt(7),
      designId: 'dsg_flush',
      productId: 'photo_print',
    );
    await store.flush();
    await write;
    expect((await store.load('dsg_flush'))?.revision, 7);
    expect(store.isWriting('dsg_flush'), isFalse);
  });

  test('dispose дожидается очереди и не пишет после себя', () async {
    store.scheduleSave(
      documentAt(9),
      designId: 'dsg_dispose',
      productId: 'photo_print',
    );
    await store.dispose();
    expect(store.isDisposed, isTrue);

    final loaded = await store.load('dsg_dispose');
    expect(loaded, isNull, reason: 'a cancelled debounce must not write late');

    await store.saveNow(
      documentAt(10),
      designId: 'dsg_dispose',
      productId: 'photo_print',
    );
    expect(await store.load('dsg_dispose'), isNull);
  });

  test(
    'ротация ревизий удаляет старые по номеру, а не по имени файла',
    () async {
      for (var revision = 1; revision <= 12; revision++) {
        await store.saveNow(
          documentAt(revision),
          designId: 'dsg_prune',
          productId: 'photo_print',
        );
      }
      final revisions = Directory(
        '${designDirectory('dsg_prune').path}/revisions',
      );
      final kept =
          revisions
              .listSync()
              .whereType<File>()
              .map((file) => file.uri.pathSegments.last)
              .toList()
            ..sort();
      expect(kept, <String>[
        'r10.json',
        'r11.json',
        'r12.json',
        'r8.json',
        'r9.json',
      ]);
    },
  );
}
