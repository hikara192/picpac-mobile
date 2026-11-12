import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:design_core/design_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:picpac_mobile/core/media/asset_cache.dart';
import 'package:picpac_mobile/core/media/image_probe.dart';
import 'package:picpac_mobile/core/media/mime_sniffer.dart';
import 'package:picpac_mobile/core/media/photo_format.dart';
import 'package:picpac_mobile/core/media/photo_importer.dart';
import 'package:picpac_mobile/core/media/photo_normalizer.dart';
import 'package:picpac_mobile/core/media/photo_picker.dart';

import 'support/fixture_bytes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const normalizer = PlatformPhotoNormalizer();
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('picpac_media_it_');
  });

  tearDown(() async {
    if (await workspace.exists()) await workspace.delete(recursive: true);
  });

  Future<File> fixture(String relative, String name) async {
    final file = File('${workspace.path}/$name');
    await file.writeAsBytes(fixtureBytes(relative), flush: true);
    return file;
  }

  Future<NormalizedPhoto> normalize(
    File source, {
    required String sourceMime,
    String outputMime = PhotoFormats.jpeg,
  }) async {
    final output = File(
      '${workspace.path}/out_${DateTime.now().microsecondsSinceEpoch}.'
      '${outputMime == PhotoFormats.png ? 'png' : 'jpg'}',
    );
    final started = DateTime.now();
    final result = await normalizer.normalize(
      source: source,
      output: output,
      sourceMime: sourceMime,
      outputMime: outputMime,
    );
    final elapsed = DateTime.now().difference(started);
    switch (result) {
      case Err<NormalizedPhoto>(:final error):
        fail('normalize failed: ${error.code} ${error.message}');
      case Ok<NormalizedPhoto>(:final value):
        debugPrint(
          'normalize: ${source.uri.pathSegments.last} '
          '($sourceMime) -> ${value.mimeType} '
          '${value.widthPx}x${value.heightPx} ${value.bytes} B '
          'in ${elapsed.inMilliseconds} ms, converted=${value.converted}',
        );
        return value;
    }
  }

  testWidgets('HEIC → JPEG: magic bytes, размеры, отсутствие EXIF', (
    tester,
  ) async {
    final source = await fixture('heic/gradient_640x480.heic', 'plain.heic');
    expect(await MimeSniffer.detectFile(source), PhotoFormats.heic);

    final result = await normalize(source, sourceMime: PhotoFormats.heic);
    expect(result.mimeType, PhotoFormats.jpeg);
    expect(result.converted, isTrue);
    expect(result.sourceMime, PhotoFormats.heic);

    final bytes = await result.file.readAsBytes();
    expect(bytes.sublist(0, 3), <int>[
      0xFF,
      0xD8,
      0xFF,
    ], reason: 'the output must be a real JPEG, not renamed HEIC bytes');
    expect(sha256.convert(bytes).toString(), result.sha256);
    expect(result.bytes, bytes.length);
    expect(<int>[result.widthPx, result.heightPx], <int>[640, 480]);

    expect(
      jpegAppSegments(bytes),
      isNot(contains('APP1')),
      reason: 'EXIF envelope',
    );
    expect(asciiIndexOf(bytes, 'Exif'), -1);
    expect(asciiIndexOf(bytes, 'GPS'), -1);
    expect(asciiIndexOf(bytes, 'Fixture Camera'), -1);
    expect(asciiIndexOf(bytes, 'PicPac'), -1);
  });

  testWidgets('ориентация 6 запекается в пиксели: 480×640', (tester) async {
    final source = await fixture(
      'heic/portrait_orientation6.heic',
      'portrait.heic',
    );
    final result = await normalize(source, sourceMime: PhotoFormats.heic);

    expect(result.widthPx, lessThan(result.heightPx));
    expect(<int>[result.widthPx, result.heightPx], <int>[480, 640]);

    final bytes = await result.file.readAsBytes();
    expect(jpegAppSegments(bytes), isNot(contains('APP1')));
    expect(asciiIndexOf(bytes, 'GPS'), -1);
  });

  testWidgets('GPS вычищается и из HEIC, и из JPEG', (tester) async {
    for (final entry in <String, String>{
      'heic/with_gps.heic': PhotoFormats.heic,
      'jpeg/with_gps.jpg': PhotoFormats.jpeg,
    }.entries) {
      final source = await fixture(entry.key, 'gps_${entry.key.hashCode}.bin');
      final sourceBytes = await source.readAsBytes();
      expect(asciiIndexOf(sourceBytes, 'Exif'), isNot(-1), reason: entry.key);
      expect(
        asciiIndexOf(sourceBytes, 'Fixture Camera'),
        isNot(-1),
        reason: entry.key,
      );

      final result = await normalize(source, sourceMime: entry.value);
      final bytes = await result.file.readAsBytes();
      expect(bytes.sublist(0, 3), <int>[0xFF, 0xD8, 0xFF]);
      expect(
        jpegAppSegments(bytes),
        isNot(contains('APP1')),
        reason: entry.key,
      );
      expect(asciiIndexOf(bytes, 'GPS'), -1, reason: entry.key);
      expect(asciiIndexOf(bytes, 'Exif'), -1, reason: entry.key);
    }
  });

  testWidgets('PNG не перекодируется: те же байты и тот же хеш', (
    tester,
  ) async {
    final source = await fixture('png/gradient_320x240.png', 'shot.png');
    final cache = DesignAssetCache(rootDirectory: () async => workspace);
    final importer = PhotoImporter(
      picker: _NoPicker(),
      cache: cache,
      probe: const UiImageProbe(),
      normalizer: normalizer,
    );

    final batch = await importer.prepare(
      designId: 'dsg_it',
      files: <PickedFile>[
        PickedFile(
          path: source.path,
          name: 'shot.png',
          mimeType: PhotoFormats.png,
          bytes: await source.length(),
        ),
      ],
    );

    expect(batch.rejections, isEmpty);
    final prepared = batch.prepared.single;
    final sourceBytes = await source.readAsBytes();
    expect(prepared.mimeType, PhotoFormats.png);
    expect(prepared.sha256, sha256.convert(sourceBytes).toString());
    expect(prepared.bytes, sourceBytes.length);
    expect(prepared.widthPx, 320);
    expect(prepared.heightPx, 240);
    expect(await prepared.cachedFile.readAsBytes(), orderedEquals(sourceBytes));
    debugPrint(
      'png passthrough: ${prepared.bytes} B, sha256=${prepared.sha256}',
    );
  });

  testWidgets('HEIC через importer: в документ уходит JPEG', (tester) async {
    final source = await fixture('heic/gradient_640x480.heic', 'IMG_9001.heic');
    final cache = DesignAssetCache(rootDirectory: () async => workspace);
    final importer = PhotoImporter(
      picker: _NoPicker(),
      cache: cache,
      probe: const UiImageProbe(),
      normalizer: normalizer,
    );

    final batch = await importer.prepare(
      designId: 'dsg_it',
      files: <PickedFile>[
        PickedFile(
          path: source.path,
          name: 'IMG_9001.HEIC',
          mimeType: PhotoFormats.jpeg,
          bytes: await source.length(),
        ),
      ],
    );

    expect(batch.rejections, isEmpty);
    final prepared = batch.prepared.single;
    expect(prepared.mimeType, PhotoFormats.jpeg);
    final cached = await prepared.cachedFile.readAsBytes();
    expect(cached.sublist(0, 3), <int>[0xFF, 0xD8, 0xFF]);
    expect(cached.length, prepared.bytes);
    debugPrint(
      'importer: ${prepared.fileName} -> ${prepared.mimeType} '
      '${prepared.widthPx}x${prepared.heightPx} ${prepared.bytes} B',
    );
  });
}

final class _NoPicker implements PhotoPickerPort {
  @override
  Future<Result<List<PickedFile>>> pickImages({int? limit}) async =>
      const Ok<List<PickedFile>>(<PickedFile>[]);

  @override
  Future<Result<List<PickedFile>>> recoverLostSelection() async =>
      const Ok<List<PickedFile>>(<PickedFile>[]);
}

List<String> jpegAppSegments(Uint8List bytes) {
  final segments = <String>[];
  var offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] != 0xFF) break;
    final marker = bytes[offset + 1];
    if (marker == 0xDA) break; // start of scan: pixel data follows
    if (marker < 0xE0 || marker > 0xEF) {
      offset += 2;
      continue;
    }
    final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
    segments.add('APP${marker - 0xE0}');
    offset += 2 + length;
  }
  return segments;
}

int asciiIndexOf(List<int> bytes, String text) {
  final needle = text.codeUnits;
  outer:
  for (var i = 0; i + needle.length <= bytes.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}
