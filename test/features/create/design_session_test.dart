import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/core/media/photo_picker.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';
import 'package:picpac_mobile/features/create/application/import_controller.dart';

import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  group('сессия проекта', () {
    test('перезапуск восстанавливает документ и порядок фото', () async {
      final first = await DesignHarness.create();
      addTearDown(first.dispose);
      first.stubBasics();
      final container = first.mount();
      await container.read(designSessionProvider('dsg_1').future);

      final files = <File>[];
      for (var i = 0; i < 3; i++) {
        files.add(await writePng(first.root, 'restart_$i.png', width: 300 + i));
      }
      first.picker.queue(<PickedFile>[for (final f in files) pickedPng(f)]);
      await container
          .read(importControllerProvider('dsg_1').notifier)
          .pickAndImport();
      final before = container
          .read(designSessionProvider('dsg_1'))
          .value!
          .document
          .assets
          .map((asset) => asset.id)
          .toList();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      container.dispose();

      final second = await DesignHarness.create(rootDirectory: first.root);
      addTearDown(second.dispose);
      second.stubBasics(designFailure: ApiFailure.networkUnavailable());
      final restarted = second.mount();
      addTearDown(restarted.dispose);
      await restarted.read(designSessionProvider('dsg_1').future);

      final restored = restarted.read(designSessionProvider('dsg_1')).value!;
      expect(restored.restoredFromCache, isTrue);
      expect(restored.sync, DesignSyncStatus.offline);
      expect(
        restored.document.assets.map((asset) => asset.id).toList(),
        before,
        reason: 'порядок фото должен переживать перезапуск',
      );
    });

    test(
      'переупорядочивание меняет порядок и отменяется одним шагом',
      () async {
        final harness = await DesignHarness.create();
        addTearDown(harness.dispose);
        harness.stubBasics();
        final container = harness.mount();
        addTearDown(container.dispose);
        await container.read(designSessionProvider('dsg_1').future);
        await _importPhotos(harness, container, 3);

        final session = container.read(designSessionProvider('dsg_1').notifier);
        final ids = _order(container);

        session.reorderPhotos(0, 2);
        expect(_order(container), <String>[ids[1], ids[2], ids[0]]);

        session.undo();
        expect(_order(container), ids);
      },
    );

    test('удаление фото каскадно чистит слот и лист', () async {
      final harness = await DesignHarness.create();
      addTearDown(harness.dispose);
      harness.stubBasics();
      final container = harness.mount();
      addTearDown(container.dispose);
      await container.read(designSessionProvider('dsg_1').future);
      await _importPhotos(harness, container, 2);

      final session = container.read(designSessionProvider('dsg_1').notifier);
      final victim = container
          .read(designSessionProvider('dsg_1'))
          .value!
          .document
          .assets
          .first
          .id;

      session.removePhoto(victim);
      final state = container.read(designSessionProvider('dsg_1')).value!;
      expect(state.document.assetById(victim), isNull);
      expect(state.document.photoCount, 1);
      expect(state.spreads.length, 1);
      expect(
        state.document.photoPlacements.any((ref) => ref.photoId == victim),
        isFalse,
      );
      expect(state.document.emptySlotCount, 0);
    });

    test(
      '409 сохраняет локальную версию как конфликт, а не перезапись',
      () async {
        final harness = await DesignHarness.create();
        addTearDown(harness.dispose);
        harness.stubBasics();
        final container = harness.mount();
        addTearDown(container.dispose);
        await container.read(designSessionProvider('dsg_1').future);

        var conflicts = 1;
        when(
          () => harness.api.putDesign(
            any(),
            any(),
            ifMatchRevision: any(named: 'ifMatchRevision'),
          ),
        ).thenAnswer((invocation) async {
          if (conflicts-- > 0) {
            return Err<DesignDto>(
              const ApiFailure(
                code: ApiErrorCode.conflictRevision,
                message: 'newer revision on the server',
                statusCode: 409,
              ),
            );
          }
          final document = invocation.positionalArguments[1] as dynamic;
          return Ok<DesignDto>(
            DesignDto(
              id: 'dsg_1',
              revision: 7,
              document: document as dynamic,
              updatedAt: DateTime.utc(2026, 11, 11, 12, 30),
            ),
          );
        });

        await _importPhotos(harness, container, 1);
        await Future<void>.delayed(const Duration(seconds: 3));
        expect(
          container.read(designSessionProvider('dsg_1')).value!.sync,
          DesignSyncStatus.conflict,
        );

        final failure = await container
            .read(designSessionProvider('dsg_1').notifier)
            .keepLocalVersion();
        expect(failure, isNull);
        final state = container.read(designSessionProvider('dsg_1')).value!;
        expect(state.sync, DesignSyncStatus.synced);
        expect(state.serverRevision, 7);
      },
    );

    test('undo/redo возвращают документ к тому же состоянию', () async {
      final harness = await DesignHarness.create();
      addTearDown(harness.dispose);
      harness.stubBasics();
      final container = harness.mount();
      addTearDown(container.dispose);
      await container.read(designSessionProvider('dsg_1').future);
      await _importPhotos(harness, container, 2);

      final session = container.read(designSessionProvider('dsg_1').notifier);
      final before = container
          .read(designSessionProvider('dsg_1'))
          .value!
          .document;

      session.undo();
      expect(
        container
            .read(designSessionProvider('dsg_1'))
            .value!
            .document
            .photoCount,
        lessThan(before.photoCount),
      );

      session.redo();
      expect(
        container.read(designSessionProvider('dsg_1')).value!.document,
        before,
      );
    });
  });
}

List<String> _order(ProviderContainer container) => container
    .read(designSessionProvider('dsg_1'))
    .value!
    .document
    .assets
    .map((asset) => asset.id)
    .toList();

Future<void> _importPhotos(
  DesignHarness harness,
  ProviderContainer container,
  int count,
) async {
  final files = <PickedFile>[];
  for (var i = 0; i < count; i++) {
    final file = await writePng(
      harness.root,
      'batch_${DateTime.now().microsecondsSinceEpoch}_$i.png',
      width: 400 + i,
    );
    files.add(pickedPng(file));
  }
  harness.picker.queue(files);
  await container
      .read(importControllerProvider('dsg_1').notifier)
      .pickAndImport();
}
