import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/core/media/photo_format.dart';
import 'package:picpac_mobile/core/media/photo_picker.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';
import 'package:picpac_mobile/features/create/application/import_controller.dart';

import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  group('импорт фото', () {
    late DesignHarness harness;

    setUp(() async {
      harness = await DesignHarness.create();
    });

    tearDown(() async {
      harness.container.dispose();
      await harness.dispose();
    });

    test(
      '10 фото становятся 10 PhotoAsset и 10 листами в порядке выбора',
      () async {
        harness.stubBasics();
        final container = harness.mount();
        await container.read(designSessionProvider('dsg_1').future);

        final files = <File>[];
        for (var i = 0; i < 10; i++) {
          files.add(
            await writePng(
              harness.root,
              'photo_$i.png',
              width: 300 + i,
              height: 400,
            ),
          );
        }
        harness.picker.queue(<PickedFile>[
          for (final file in files) pickedPng(file),
        ]);

        await container
            .read(importControllerProvider('dsg_1').notifier)
            .pickAndImport();

        final state = container.read(designSessionProvider('dsg_1')).value!;
        expect(state.document.photoCount, 10);
        expect(state.spreads.length, 10);
        expect(state.document.filledSlotCount, 10);
        expect(
          <String>[
            for (final spread in state.spreads) spread.slots.single.photoId!,
          ],
          <String>[for (final asset in state.document.assets) asset.id],
        );
        expect(harness.storage.uploads, hasLength(10));
        expect(container.read(importControllerProvider('dsg_1')).added, 10);
      },
    );

    test('одно и то же фото дважды не загружается', () async {
      harness.stubBasics();
      final container = harness.mount();
      await container.read(designSessionProvider('dsg_1').future);

      final file = await writePng(harness.root, 'same.png');
      harness.picker.queue(<PickedFile>[pickedPng(file)]);
      await container
          .read(importControllerProvider('dsg_1').notifier)
          .pickAndImport();
      harness.picker.queue(<PickedFile>[pickedPng(file)]);
      await container
          .read(importControllerProvider('dsg_1').notifier)
          .pickAndImport();

      final state = container.read(designSessionProvider('dsg_1')).value!;
      expect(state.document.photoCount, 1);
      expect(harness.storage.uploads, hasLength(1));
      expect(container.read(importControllerProvider('dsg_1')).duplicates, 1);
    });

    test('имя .HEIC не делает файл HEIC: решает сигнатура байтов', () async {
      harness.stubBasics();
      final container = harness.mount();
      await container.read(designSessionProvider('dsg_1').future);

      final file = await writePng(harness.root, 'IMG_0001.HEIC');
      harness.picker.queue(<PickedFile>[
        PickedFile(
          path: file.path,
          name: 'IMG_0001.HEIC',
          mimeType: 'image/heic',
          bytes: file.lengthSync(),
        ),
      ]);
      await container
          .read(importControllerProvider('dsg_1').notifier)
          .pickAndImport();

      final importState = container.read(importControllerProvider('dsg_1'));
      expect(importState.rejections, isEmpty);
      expect(importState.added, 1);
      expect(
        harness.storage.uploads.single.url,
        isNotEmpty,
        reason: 'the PNG reached the transfer step',
      );
      expect(
        container
            .read(designSessionProvider('dsg_1'))
            .value!
            .document
            .photoCount,
        1,
      );
    });

    test(
      'файл больше входного лимита отклоняется с лимитом в аргументах',
      () async {
        harness.stubBasics();
        final container = harness.mount();
        await container.read(designSessionProvider('dsg_1').future);

        final file = File('${harness.root.path}/huge.png');
        final handle = await file.open(mode: FileMode.write);
        await handle.truncate(PhotoFormats.maxSourceBytes + 1);
        await handle.close();

        harness.picker.queue(<PickedFile>[
          PickedFile(
            path: file.path,
            name: 'huge.png',
            mimeType: 'image/png',
            bytes: PhotoFormats.maxSourceBytes + 1,
          ),
        ]);
        await container
            .read(importControllerProvider('dsg_1').notifier)
            .pickAndImport();

        final rejection = container
            .read(importControllerProvider('dsg_1'))
            .rejections
            .single;
        expect(rejection.code, PhotoRejectionCode.tooLarge);
        expect(rejection.args['limit'], PhotoFormats.maxSourceMegabytes);
        expect(
          PhotoFormats.maxSourceMegabytes,
          greaterThan(PhotoFormats.maxMegabytes),
        );
      },
    );

    test('обрыв загрузки не теряет выбор и повторяется по кнопке', () async {
      harness.stubBasics();
      final container = harness.mount();
      await container.read(designSessionProvider('dsg_1').future);

      final file = await writePng(harness.root, 'keep.png');
      harness.storage.failure = ApiFailure.networkUnavailable();
      harness.picker.queue(<PickedFile>[pickedPng(file)]);
      await container
          .read(importControllerProvider('dsg_1').notifier)
          .pickAndImport();

      var importState = container.read(importControllerProvider('dsg_1'));
      expect(importState.hasFailures, isTrue);
      expect(
        container
            .read(designSessionProvider('dsg_1'))
            .value!
            .document
            .photoCount,
        0,
      );
      final cached = await Directory('${harness.root.path}/drafts/dsg_1/assets')
          .list()
          .toList();
      expect(cached, hasLength(1));

      await container
          .read(importControllerProvider('dsg_1').notifier)
          .retryFailed();
      importState = container.read(importControllerProvider('dsg_1'));
      expect(importState.hasFailures, isFalse);
      expect(
        container
            .read(designSessionProvider('dsg_1'))
            .value!
            .document
            .photoCount,
        1,
      );
    });

    test('офлайн: изменение сохраняется в черновик даже без сервера', () async {
      harness.stubBasics(putFailure: ApiFailure.networkUnavailable());
      final container = harness.mount();
      await container.read(designSessionProvider('dsg_1').future);

      final file = await writePng(harness.root, 'offline.png');
      harness.picker.queue(<PickedFile>[pickedPng(file)]);
      await container
          .read(importControllerProvider('dsg_1').notifier)
          .pickAndImport();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final snapshot = File('${harness.root.path}/drafts/dsg_1/document.json');
      expect(await snapshot.exists(), isTrue);
      expect(
        await snapshot.readAsString(),
        contains('"assets"'),
        reason: 'снапшот должен содержать манифест фото',
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(
        container.read(designSessionProvider('dsg_1')).value!.sync,
        DesignSyncStatus.offline,
      );
    });
  });
}
