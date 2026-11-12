import 'dart:io';
import 'dart:typed_data';

import 'package:api_contract/api_contract.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/core/media/photo_format.dart';
import 'package:picpac_mobile/core/media/photo_picker.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';
import 'package:picpac_mobile/features/create/application/import_controller.dart';

import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  group('HEIC импорт', () {
    late DesignHarness harness;

    setUp(() async {
      harness = await DesignHarness.create();
    });

    tearDown(() async {
      harness.container.dispose();
      await harness.dispose();
    });

    Future<File> fixtureFile(String fixture, String name) async {
      final bytes = await File('test/fixtures/$fixture').readAsBytes();
      final file = File('${harness.root.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    }

    PickedFile picked(File file, {String? name, String? mimeType}) =>
        PickedFile(
          path: file.path,
          name: name ?? file.uri.pathSegments.last,
          mimeType: mimeType,
          bytes: file.lengthSync(),
        );

    test(
      'HEIC конвертируется в JPEG: документ, кеш и загрузка видят JPEG',
      () async {
        harness.stubBasics();
        final container = harness.mount();
        await container.read(designSessionProvider('dsg_1').future);

        final source = await fixtureFile(
          'heic/gradient_640x480.heic',
          'IMG_0001.heic',
        );
        final jpeg = await FakePhotoNormalizer.defaultJpegBytes();
        harness.picker.queue(<PickedFile>[
          picked(source, name: 'IMG_0001.HEIC', mimeType: 'image/heic'),
        ]);

        await container
            .read(importControllerProvider('dsg_1').notifier)
            .pickAndImport();

        final state = container.read(designSessionProvider('dsg_1')).value!;
        expect(state.document.photoCount, 1);
        final asset = state.document.assets.single;

        expect(asset.mimeType, PhotoFormats.jpeg);
        expect(asset.bytes, jpeg.length);
        expect(asset.sha256, sha256.convert(jpeg).toString());
        expect(harness.normalizer.calls, <String>[PhotoFormats.heic]);

        final cached = File(
          '${harness.root.path}/drafts/dsg_1/assets/${asset.sha256}',
        );
        final cachedBytes = await cached.readAsBytes();
        expect(cachedBytes, orderedEquals(jpeg));
        expect(cachedBytes.sublist(0, 3), <int>[0xFF, 0xD8, 0xFF]);

        expect(harness.storage.uploads, hasLength(1));
        verify(
          () => harness.api.presignUpload(
            any(
              that: isA<PresignUploadRequest>()
                  .having((r) => r.mimeType, 'mimeType', PhotoFormats.jpeg)
                  .having((r) => r.sha256, 'sha256', asset.sha256)
                  .having((r) => r.bytes, 'bytes', jpeg.length),
            ),
          ),
        ).called(1);
      },
    );

    test(
      'размеры берутся из нормализованного файла, а не из исходника',
      () async {
        harness.stubBasics();
        final container = harness.mount();
        await container.read(designSessionProvider('dsg_1').future);

        final source = await fixtureFile(
          'heic/gradient_640x480.heic',
          'IMG_0002.heic',
        );
        harness.picker.queue(<PickedFile>[picked(source)]);
        await container
            .read(importControllerProvider('dsg_1').notifier)
            .pickAndImport();

        final asset = container
            .read(designSessionProvider('dsg_1'))
            .value!
            .document
            .assets
            .single;
        expect(<int>[asset.widthPx, asset.heightPx], <int>[320, 240]);
      },
    );

    test('два одинаковых HEIC дают одну загрузку и один дубль', () async {
      harness.stubBasics();
      final container = harness.mount();
      await container.read(designSessionProvider('dsg_1').future);

      final source = await fixtureFile('heic/with_gps.heic', 'IMG_0003.heic');
      harness.picker.queue(<PickedFile>[picked(source), picked(source)]);
      await container
          .read(importControllerProvider('dsg_1').notifier)
          .pickAndImport();

      final importState = container.read(importControllerProvider('dsg_1'));
      expect(importState.duplicates, 1);
      expect(importState.added, 1);
      expect(harness.storage.uploads, hasLength(1));
      expect(
        container
            .read(designSessionProvider('dsg_1'))
            .value!
            .document
            .photoCount,
        1,
      );
    });

    test('повторный импорт после рестарта не создаёт дубль', () async {
      harness.stubBasics();
      final container = harness.mount();
      await container.read(designSessionProvider('dsg_1').future);

      final source = await fixtureFile('heic/with_gps.heic', 'IMG_0004.heic');
      harness.picker.queue(<PickedFile>[picked(source)]);
      await container
          .read(importControllerProvider('dsg_1').notifier)
          .pickAndImport();

      harness.picker.queue(<PickedFile>[picked(source)]);
      await container
          .read(importControllerProvider('dsg_1').notifier)
          .pickAndImport();

      expect(harness.storage.uploads, hasLength(1));
      expect(container.read(importControllerProvider('dsg_1')).duplicates, 1);
    });

    test(
      'устройство без HEVC-декодера отклоняет HEIC понятным кодом',
      () async {
        harness.stubBasics();
        final container = harness.mount();
        await container.read(designSessionProvider('dsg_1').future);

        final source = await fixtureFile('heic/with_gps.heic', 'IMG_0005.heic');
        harness.normalizer.failure = const MediaFailure(
          code: MediaErrorCode.decodeFailed,
          message: 'the decoder is not available on this device',
        );
        harness.picker.queue(<PickedFile>[picked(source)]);
        await container
            .read(importControllerProvider('dsg_1').notifier)
            .pickAndImport();

        final importState = container.read(importControllerProvider('dsg_1'));
        expect(
          importState.rejections.single.code,
          PhotoRejectionCode.heicUnsupported,
        );
        expect(harness.storage.uploads, isEmpty);
        expect(
          container
              .read(designSessionProvider('dsg_1'))
              .value!
              .document
              .photoCount,
          0,
        );
      },
    );

    test('HEIC с именем .jpg всё равно конвертируется', () async {
      harness.stubBasics();
      final container = harness.mount();
      await container.read(designSessionProvider('dsg_1').future);

      final source = await fixtureFile('heic/spoofed_heic.jpg', 'IMG_0006.jpg');
      harness.picker.queue(<PickedFile>[
        picked(source, mimeType: PhotoFormats.jpeg),
      ]);
      await container
          .read(importControllerProvider('dsg_1').notifier)
          .pickAndImport();

      final asset = container
          .read(designSessionProvider('dsg_1'))
          .value!
          .document
          .assets
          .single;
      expect(harness.normalizer.calls, <String>[PhotoFormats.heic]);
      expect(asset.mimeType, PhotoFormats.jpeg);
    });
  });

  group('PNG и отказы', () {
    late DesignHarness harness;

    setUp(() async {
      harness = await DesignHarness.create();
    });

    tearDown(() async {
      harness.container.dispose();
      await harness.dispose();
    });

    Future<File> fixtureFile(String fixture, String name) async {
      final bytes = await File('test/fixtures/$fixture').readAsBytes();
      final file = File('${harness.root.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    }

    test(
      'PNG копируется побайтово: хеш исходных байтов, без перекодирования',
      () async {
        harness.stubBasics();
        final container = harness.mount();
        await container.read(designSessionProvider('dsg_1').future);

        final source = await fixtureFile(
          'png/gradient_320x240.png',
          'shot.png',
        );
        harness.picker.queue(<PickedFile>[pickedPng(source)]);
        await container
            .read(importControllerProvider('dsg_1').notifier)
            .pickAndImport();

        final asset = container
            .read(designSessionProvider('dsg_1'))
            .value!
            .document
            .assets
            .single;
        final sourceBytes = await source.readAsBytes();
        expect(asset.sha256, sha256.convert(sourceBytes).toString());
        expect(asset.bytes, sourceBytes.length);
        expect(asset.mimeType, PhotoFormats.png);
        expect(harness.normalizer.calls, isEmpty);

        final cached = File(
          '${harness.root.path}/drafts/dsg_1/assets/${asset.sha256}',
        );
        expect(await cached.readAsBytes(), orderedEquals(sourceBytes));
      },
    );

    test('файл больше входного лимита отклоняется до декодирования', () async {
      harness.stubBasics();
      final container = harness.mount();
      await container.read(designSessionProvider('dsg_1').future);

      final huge = File('${harness.root.path}/huge.jpg');
      final handle = await huge.open(mode: FileMode.write);
      await handle.truncate(PhotoFormats.maxSourceBytes + 1);
      await handle.close();

      harness.picker.queue(<PickedFile>[
        PickedFile(
          path: huge.path,
          name: 'huge.jpg',
          mimeType: PhotoFormats.jpeg,
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
      expect(harness.normalizer.calls, isEmpty);
    });

    test('WebP отклоняется как неподдерживаемый формат', () async {
      harness.stubBasics();
      final container = harness.mount();
      await container.read(designSessionProvider('dsg_1').future);

      final webp = File('${harness.root.path}/anim.webp');
      await webp.writeAsBytes(<int>[
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x24, 0x00, 0x00, 0x00,
        0x57, 0x45, 0x42, 0x50, // WEBP
        0x56, 0x50, 0x38, 0x20,
        ...List<int>.filled(64, 0),
      ], flush: true);

      harness.picker.queue(<PickedFile>[
        PickedFile(
          path: webp.path,
          name: 'anim.webp',
          mimeType: 'image/webp',
          bytes: webp.lengthSync(),
        ),
      ]);
      await container
          .read(importControllerProvider('dsg_1').notifier)
          .pickAndImport();

      expect(
        container
            .read(importControllerProvider('dsg_1'))
            .rejections
            .single
            .code,
        PhotoRejectionCode.unsupportedFormat,
      );
    });

    test('выход больше 25 МБ отклоняется с лимитом в аргументах', () async {
      harness.stubBasics();
      final container = harness.mount();
      await container.read(designSessionProvider('dsg_1').future);

      harness.normalizer.outputBytes = Uint8List(PhotoFormats.maxBytes + 1);
      final source = await fixtureFile('heic/with_gps.heic', 'big.heic');
      harness.picker.queue(<PickedFile>[
        PickedFile(
          path: source.path,
          name: 'big.heic',
          mimeType: PhotoFormats.heic,
          bytes: source.lengthSync(),
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
      expect(rejection.args['limit'], PhotoFormats.maxMegabytes);
      expect(harness.storage.uploads, isEmpty);
    });

    test('битый файл не отменяет остальные фото в пачке', () async {
      harness.stubBasics();
      final container = harness.mount();
      await container.read(designSessionProvider('dsg_1').future);

      final broken = File('${harness.root.path}/broken.heic')
        ..writeAsBytesSync(List<int>.filled(64, 0x2A));
      final heic = await fixtureFile('heic/with_gps.heic', 'IMG_0007.heic');
      final png = await fixtureFile('png/gradient_320x240.png', 'ok.png');

      harness.picker.queue(<PickedFile>[
        PickedFile(
          path: broken.path,
          name: 'broken.heic',
          mimeType: 'image/heic',
          bytes: broken.lengthSync(),
        ),
        PickedFile(
          path: heic.path,
          name: 'IMG_0007.heic',
          mimeType: 'image/heic',
          bytes: heic.lengthSync(),
        ),
        pickedPng(png),
      ]);
      await container
          .read(importControllerProvider('dsg_1').notifier)
          .pickAndImport();

      final importState = container.read(importControllerProvider('dsg_1'));
      expect(
        importState.rejections.single.code,
        PhotoRejectionCode.unsupportedFormat,
      );
      expect(importState.added, 2);
      expect(harness.storage.uploads, hasLength(2));
    });
  });
}
