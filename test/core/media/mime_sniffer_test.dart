import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/core/media/mime_sniffer.dart';
import 'package:picpac_mobile/core/media/photo_format.dart';

void main() {
  File fixture(String relative) => File('test/fixtures/$relative');

  group('magic bytes', () {
    test('JPEG', () {
      expect(
        MimeSniffer.detect(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]),
        PhotoFormats.jpeg,
      );
    });

    test('PNG', () {
      expect(
        MimeSniffer.detect(<int>[
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0x00,
          0x00,
          0x00,
          0x0D,
        ]),
        PhotoFormats.png,
      );
    });

    test('HEIC brand, HEIF generic brand, AVIF, WebP', () {
      String iso(String brand) => MimeSniffer.detect(<int>[
        0x00, 0x00, 0x00, 0x18, // box size
        0x66, 0x74, 0x79, 0x70, // 'ftyp'
        ...brand.codeUnits,
        0x00, 0x00, 0x00, 0x00,
      ]);

      expect(iso('heic'), PhotoFormats.heic);
      expect(iso('heix'), PhotoFormats.heic);
      expect(iso('hevx'), PhotoFormats.heic);
      expect(iso('mif1'), PhotoFormats.heif);
      expect(iso('avif'), PhotoFormats.avif);
      expect(
        MimeSniffer.detect(<int>[
          0x52, 0x49, 0x46, 0x46, // 'RIFF'
          0x24, 0x00, 0x00, 0x00,
          0x57, 0x45, 0x42, 0x50, // 'WEBP'
        ]),
        PhotoFormats.webp,
      );
    });

    test('unknown and truncated headers are not guessed', () {
      expect(MimeSniffer.detect(const <int>[]), '');
      expect(MimeSniffer.detect(<int>[0xFF, 0xD8]), '');
      expect(MimeSniffer.detect(<int>[0xFF, 0xD8, 0x00]), '');
      expect(MimeSniffer.detect(<int>[0x00, 0x01, 0x02, 0x03, 0x04, 0x05]), '');
      expect(
        MimeSniffer.detect(<int>[
          0x00, 0x00, 0x00, 0x18,
          0x66, 0x74, 0x79, 0x70,
          0x71, 0x74, 0x20, 0x20, // 'qt  ' — a QuickTime container
        ]),
        '',
      );
    });
  });

  group('fixtures', () {
    test('every fixture is detected by content, never by name', () async {
      expect(
        await MimeSniffer.detectFile(fixture('heic/spoofed_heic.jpg')),
        PhotoFormats.heic,
      );
      expect(
        await MimeSniffer.detectFile(fixture('heic/spoofed_jpeg.heic')),
        PhotoFormats.jpeg,
      );
      expect(
        await MimeSniffer.detectFile(fixture('heic/gradient_640x480.heic')),
        PhotoFormats.heic,
      );
      expect(
        await MimeSniffer.detectFile(fixture('heic/with_gps.heic')),
        PhotoFormats.heic,
      );
      expect(
        await MimeSniffer.detectFile(fixture('jpeg/with_gps.jpg')),
        PhotoFormats.jpeg,
      );
      expect(
        await MimeSniffer.detectFile(fixture('png/gradient_320x240.png')),
        PhotoFormats.png,
      );
    });

    test('a missing file is unknown, not an exception', () async {
      expect(await MimeSniffer.detectFile(fixture('nope.heic')), '');
    });
  });

  group('PNG metadata', () {
    test('a metadata-free PNG is reported clean', () async {
      expect(
        await pngHasMetadata(fixture('png/gradient_320x240.png')),
        isFalse,
      );
    });

    test('an eXIf chunk is found before IDAT', () async {
      final source = await fixture('png/gradient_320x240.png').readAsBytes();
      final withExif = withPngChunk(source, 'eXIf', <int>[0x4D, 0x4D, 0x00]);
      final file = await _tempFile(withExif);
      expect(await pngHasMetadata(file), isTrue);
    });

    test('an XMP iTXt chunk is found', () async {
      final source = await fixture('png/gradient_320x240.png').readAsBytes();
      final keyword = 'XML:com.adobe.xmp'.codeUnits;
      final payload = <int>[
        ...keyword,
        0x00, // null separator
        0x00, // uncompressed
        0x00, 0x00, // empty language tag + null
        ...'<x:xmpmeta/>'.codeUnits,
      ];
      final file = await _tempFile(withPngChunk(source, 'iTXt', payload));
      expect(await pngHasMetadata(file), isTrue);
    });

    test('a non-PNG file is never walked', () async {
      expect(await pngHasMetadata(fixture('jpeg/with_gps.jpg')), isFalse);
    });
  });
}

Uint8List withPngChunk(Uint8List png, String type, List<int> data) {
  final ascii = String.fromCharCodes(png);
  final idat = ascii.indexOf('IDAT');
  expect(idat, greaterThan(0), reason: 'the fixture must contain IDAT');
  final insertAt = idat - 4;
  final length = ByteData(4)..setUint32(0, data.length);
  final chunk = <int>[
    ...length.buffer.asUint8List(),
    ...type.codeUnits,
    ...data,
    0,
    0,
    0,
    0,
  ];
  return Uint8List.fromList(<int>[
    ...png.sublist(0, insertAt),
    ...chunk,
    ...png.sublist(insertAt),
  ]);
}

Future<File> _tempFile(List<int> bytes) async {
  final directory = await Directory.systemTemp.createTemp('picpac_png_');
  addTearDown(() => directory.delete(recursive: true));
  final file = File('${directory.path}/probe.png');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}
