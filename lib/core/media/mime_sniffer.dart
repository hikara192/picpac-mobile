import 'dart:io';
import 'dart:typed_data';

import 'photo_format.dart';

abstract final class MimeSniffer {
  static String detect(List<int> header) {
    if (header.length < 3) return '';
    if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) {
      return PhotoFormats.jpeg;
    }
    if (_startsWith(header, _pngSignature)) return PhotoFormats.png;
    if (header.length >= 12) {
      if (_ascii(header, 0, 4) == 'RIFF' && _ascii(header, 8, 4) == 'WEBP') {
        return PhotoFormats.webp;
      }
      if (_ascii(header, 4, 4) == 'ftyp') {
        return _isoBrand(_ascii(header, 8, 4));
      }
    }
    return '';
  }

  static Future<String> detectFile(File file) async {
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      final header = await handle.read(PhotoFormats.headerBytes);
      return detect(header);
    } on Object {
      return '';
    } finally {
      try {
        await handle?.close();
      } on Object {
      }
    }
  }

  static String _isoBrand(String brand) => switch (brand) {
    'avif' || 'avis' => PhotoFormats.avif,
    'heic' ||
    'heix' ||
    'heim' ||
    'heis' ||
    'hevc' ||
    'hevx' => PhotoFormats.heic,
    'mif1' || 'msf1' => PhotoFormats.heif,
    _ => '',
  };

  static const List<int> _pngSignature = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ];

  static bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static String _ascii(List<int> bytes, int offset, int length) {
    if (bytes.length < offset + length) return '';
    return String.fromCharCodes(bytes, offset, offset + length);
  }
}

Future<bool> pngHasMetadata(File file) async {
  RandomAccessFile? handle;
  try {
    handle = await file.open();
    final signature = await handle.read(8);
    if (MimeSniffer.detect(signature) != PhotoFormats.png) return false;
    var offset = 8;
    for (var chunk = 0; chunk < 64; chunk++) {
      await handle.setPosition(offset);
      final header = await handle.read(8);
      if (header.length < 8) return false;
      final length = _uint32(header, 0);
      final type = String.fromCharCodes(header, 4, 8);
      if (type == 'IDAT' || type == 'IEND') return false;
      if (type == 'eXIf') return true;
      if (type == 'tEXt' || type == 'iTXt' || type == 'zTXt') {
        final payload = await handle.read(length.clamp(0, 4096));
        if (String.fromCharCodes(payload).contains('XML:com.adobe.xmp')) {
          return true;
        }
      }
      offset += 12 + length;
    }
    return false;
  } on Object {
    return false;
  } finally {
    try {
      await handle?.close();
    } on Object {
    }
  }
}

int _uint32(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes).getUint32(offset);
