import 'dart:math' as math;
import 'dart:typed_data';

Uint8List encodeJpeg({
  required Uint8List rgba,
  required int width,
  required int height,
  int quality = 91,
}) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError.value(width, 'width', 'must be positive');
  }
  if (rgba.length < width * height * 4) {
    throw ArgumentError.value(
      rgba.length,
      'rgba',
      'must hold at least ${width * height * 4} bytes',
    );
  }
  final encoder = _JpegEncoder(
    rgba: rgba,
    width: width,
    height: height,
    quality: quality.clamp(1, 100),
  );
  return encoder.encode();
}

const int kExportJpegQuality = 91;

final class _JpegEncoder {
  _JpegEncoder({
    required this.rgba,
    required this.width,
    required this.height,
    required this.quality,
  });

  final Uint8List rgba;
  final int width;
  final int height;
  final int quality;

  final BytesBuilder _out = BytesBuilder(copy: false);
  final _BitWriter _bits = _BitWriter();

  final Int32List _previousDc = Int32List(3);
  final List<Int32List> _quant = <Int32List>[];
  final List<_HuffmanTable> _dcTables = <_HuffmanTable>[];
  final List<_HuffmanTable> _acTables = <_HuffmanTable>[];

  static final Float64List _cos = _buildCosTable();
  static final List<int> _zigZag = _buildZigZag();

  Uint8List encode() {
    _out.add(<int>[0xFF, 0xD8]); // SOI
    _writeApp0();
    _buildQuantTables();
    _writeQuantTables();
    _writeStartOfFrame();
    _buildHuffmanTables();
    _writeHuffmanTables();
    _writeStartOfScan();
    _encodeScan();
    _bits.flush();
    _out.add(_bits.takeBytes());
    _out.add(<int>[0xFF, 0xD9]); // EOI
    return _out.takeBytes();
  }

  void _writeApp0() {
    _out.add(<int>[
      0xFF, 0xE0, 0x00, 0x10, //
      0x4A, 0x46, 0x49, 0x46, 0x00, // "JFIF\0"
      0x01, 0x01, // version 1.1
      0x00, // aspect ratio units: none
      0x00, 0x01, 0x00, 0x01, // 1:1
      0x00, 0x00, // no thumbnail
    ]);
  }

  void _buildQuantTables() {
    final scale = quality < 50 ? 5000 ~/ quality : 200 - quality * 2;
    for (final base in <List<int>>[_lumaQuant, _chromaQuant]) {
      final table = Int32List(64);
      for (var i = 0; i < 64; i++) {
        final value = (base[i] * scale + 50) ~/ 100;
        table[i] = value.clamp(1, 255);
      }
      _quant.add(table);
    }
  }

  void _writeQuantTables() {
    for (var index = 0; index < 2; index++) {
      _out.add(<int>[0xFF, 0xDB, 0x00, 0x43, index]);
      final table = _quant[index];
      for (var i = 0; i < 64; i++) {
        _out.addByte(table[_zigZag[i]]);
      }
    }
  }

  void _writeStartOfFrame() {
    final length = 8 + 3 * 3;
    _out.add(<int>[
      0xFF, 0xC0, //
      (length >> 8) & 0xFF, length & 0xFF,
      0x08, // precision
      (height >> 8) & 0xFF, height & 0xFF,
      (width >> 8) & 0xFF, width & 0xFF,
      0x03, // components
      0x01, 0x11, 0x00, // Y, 1×1 sampling, quant table 0
      0x02, 0x11, 0x01, // Cb
      0x03, 0x11, 0x01, // Cr
    ]);
  }

  void _buildHuffmanTables() {
    _dcTables
      ..clear()
      ..add(_HuffmanTable(_dcLumaBits, _dcLumaValues))
      ..add(_HuffmanTable(_dcChromaBits, _dcChromaValues));
    _acTables
      ..clear()
      ..add(_HuffmanTable(_acLumaBits, _acLumaValues))
      ..add(_HuffmanTable(_acChromaBits, _acChromaValues));
  }

  void _writeHuffmanTables() {
    void write(int tableClass, int id, List<int> bits, List<int> values) {
      final length = 2 + 1 + 16 + values.length;
      _out.add(<int>[
        0xFF,
        0xC4,
        (length >> 8) & 0xFF,
        length & 0xFF,
        (tableClass << 4) | id,
        ...bits,
        ...values,
      ]);
    }

    write(0, 0, _dcLumaBits, _dcLumaValues);
    write(1, 0, _acLumaBits, _acLumaValues);
    write(0, 1, _dcChromaBits, _dcChromaValues);
    write(1, 1, _acChromaBits, _acChromaValues);
  }

  void _writeStartOfScan() {
    _out.add(<int>[
      0xFF, 0xDA, 0x00, 0x0C,
      0x03, // components
      0x01, 0x00, // Y: DC table 0, AC table 0
      0x02, 0x11, // Cb: DC 1, AC 1
      0x03, 0x11, // Cr
      0x00, 0x3F, 0x00, // baseline, no restart interval
    ]);
  }

  void _encodeScan() {
    final coefficients = Int32List(64);
    final yBlock = Int32List(64);
    final cbBlock = Int32List(64);
    final crBlock = Int32List(64);
    for (var top = 0; top < height; top += 8) {
      for (var left = 0; left < width; left += 8) {
        _readBlock(left, top, yBlock, cbBlock, crBlock);
        _transform(yBlock, 0, coefficients);
        _encodeBlock(component: 0, tableIndex: 0, coefficients: coefficients);
        _transform(cbBlock, 1, coefficients);
        _encodeBlock(component: 1, tableIndex: 1, coefficients: coefficients);
        _transform(crBlock, 1, coefficients);
        _encodeBlock(component: 2, tableIndex: 1, coefficients: coefficients);
      }
    }
  }

  void _readBlock(int left, int top, Int32List y, Int32List cb, Int32List cr) {
    for (var row = 0; row < 8; row++) {
      final y0 = math.min(top + row, height - 1);
      for (var column = 0; column < 8; column++) {
        final x0 = math.min(left + column, width - 1);
        final offset = (y0 * width + x0) * 4;
        final r = rgba[offset];
        final g = rgba[offset + 1];
        final b = rgba[offset + 2];
        final index = row * 8 + column;
        y[index] = ((0.299 * r + 0.587 * g + 0.114 * b) - 128).round();
        cb[index] = (-0.168736 * r - 0.331264 * g + 0.5 * b).round();
        cr[index] = (0.5 * r - 0.418688 * g - 0.081312 * b).round();
      }
    }
  }

  void _transform(Int32List samples, int tableIndex, Int32List coefficients) {
    final quant = _quant[tableIndex];
    final temp = Float64List(64);
    for (var row = 0; row < 8; row++) {
      for (var u = 0; u < 8; u++) {
        var sum = 0.0;
        for (var x = 0; x < 8; x++) {
          sum += samples[row * 8 + x] * _cos[u * 8 + x];
        }
        temp[row * 8 + u] = sum;
      }
    }
    for (var v = 0; v < 8; v++) {
      for (var u = 0; u < 8; u++) {
        var sum = 0.0;
        for (var y = 0; y < 8; y++) {
          sum += temp[y * 8 + u] * _cos[v * 8 + y];
        }
        coefficients[v * 8 + u] = (sum / quant[v * 8 + u]).round();
      }
    }
  }

  void _encodeBlock({
    required int component,
    required int tableIndex,
    required Int32List coefficients,
  }) {
    final dcTable = _dcTables[tableIndex];
    final acTable = _acTables[tableIndex];

    final dc = coefficients[0];
    final diff = dc - _previousDc[component];
    _previousDc[component] = dc;
    final dcSize = _category(diff);
    final dcCode = dcTable.codeFor(dcSize);
    _bits.write(dcCode.code, dcCode.length);
    if (dcSize > 0) _bits.write(_magnitude(diff, dcSize), dcSize);

    var run = 0;
    for (var k = 1; k < 64; k++) {
      final value = coefficients[_zigZag[k]];
      if (value == 0) {
        run++;
        continue;
      }
      while (run > 15) {
        final zrl = acTable.codeFor(0xF0);
        _bits.write(zrl.code, zrl.length);
        run -= 16;
      }
      final size = _category(value);
      final entry = acTable.codeFor((run << 4) | size);
      _bits.write(entry.code, entry.length);
      _bits.write(_magnitude(value, size), size);
      run = 0;
    }
    if (run > 0) {
      final eob = acTable.codeFor(0x00);
      _bits.write(eob.code, eob.length);
    }
  }

  static List<int> _buildZigZag() => const <int>[
    0, 1, 8, 16, 9, 2, 3, 10, //
    17, 24, 32, 25, 18, 11, 4, 5, //
    12, 19, 26, 33, 40, 48, 41, 34, //
    27, 20, 13, 6, 7, 14, 21, 28, //
    35, 42, 49, 56, 57, 50, 43, 36, //
    29, 22, 15, 23, 30, 37, 44, 51, //
    58, 59, 52, 45, 38, 31, 39, 46, //
    53, 60, 61, 54, 47, 55, 62, 63, //
  ];

  static Float64List _buildCosTable() {
    final table = Float64List(64);
    for (var u = 0; u < 8; u++) {
      final cu = u == 0 ? 1 / math.sqrt2 : 1.0;
      for (var x = 0; x < 8; x++) {
        table[u * 8 + x] = cu / 2 * math.cos((2 * x + 1) * u * math.pi / 16);
      }
    }
    return table;
  }
}

int _category(int value) {
  var magnitude = value.abs();
  var bits = 0;
  while (magnitude != 0) {
    magnitude >>= 1;
    bits++;
  }
  return bits;
}

int _magnitude(int value, int size) =>
    value >= 0 ? value : value + (1 << size) - 1;

final class _BitWriter {
  final BytesBuilder _bytes = BytesBuilder(copy: false);
  int _buffer = 0;
  int _count = 0;

  void write(int code, int length) {
    if (length <= 0) return;
    _buffer = ((_buffer << length) | (code & ((1 << length) - 1))) & 0xFFFFFF;
    _count += length;
    while (_count >= 8) {
      _count -= 8;
      final byte = (_buffer >> _count) & 0xFF;
      _bytes.addByte(byte);
      if (byte == 0xFF) _bytes.addByte(0);
    }
  }

  void flush() {
    if (_count == 0) return;
    final pad = 8 - _count;
    write((1 << pad) - 1, pad);
  }

  Uint8List takeBytes() => _bytes.takeBytes();
}

final class _HuffmanCode {
  const _HuffmanCode(this.code, this.length);

  final int code;
  final int length;
}

final class _HuffmanTable {
  _HuffmanTable(List<int> bits, List<int> values) {
    var code = 0;
    var index = 0;
    for (var length = 1; length <= 16; length++) {
      final count = bits[length - 1];
      for (var i = 0; i < count; i++) {
        _codes[values[index]] = _HuffmanCode(code, length);
        index++;
        code++;
      }
      code <<= 1;
    }
  }

  final Map<int, _HuffmanCode> _codes = <int, _HuffmanCode>{};

  _HuffmanCode codeFor(int symbol) {
    final entry = _codes[symbol];
    if (entry == null) {
      throw StateError('JPEG Huffman symbol 0x${symbol.toRadixString(16)}');
    }
    return entry;
  }
}


const List<int> _lumaQuant = <int>[
  16, 11, 10, 16, 24, 40, 51, 61, //
  12, 12, 14, 19, 26, 58, 60, 55, //
  14, 13, 16, 24, 40, 57, 69, 56, //
  14, 17, 22, 29, 51, 87, 80, 62, //
  18, 22, 37, 56, 68, 109, 103, 77, //
  24, 35, 55, 64, 81, 104, 113, 92, //
  49, 64, 78, 87, 103, 121, 120, 101, //
  72, 92, 95, 98, 112, 100, 103, 99, //
];

const List<int> _chromaQuant = <int>[
  17, 18, 24, 47, 99, 99, 99, 99, //
  18, 21, 26, 66, 99, 99, 99, 99, //
  24, 26, 56, 99, 99, 99, 99, 99, //
  47, 66, 99, 99, 99, 99, 99, 99, //
  99, 99, 99, 99, 99, 99, 99, 99, //
  99, 99, 99, 99, 99, 99, 99, 99, //
  99, 99, 99, 99, 99, 99, 99, 99, //
  99, 99, 99, 99, 99, 99, 99, 99, //
];

const List<int> _dcLumaBits = <int>[
  0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, //
];

const List<int> _dcLumaValues = <int>[
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, //
];

const List<int> _dcChromaBits = <int>[
  0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, //
];

const List<int> _dcChromaValues = <int>[
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, //
];

const List<int> _acLumaBits = <int>[
  0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7D, //
];

const List<int> _acLumaValues = <int>[
  0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, //
  0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07, //
  0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08, //
  0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, //
  0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0A, 0x16, //
  0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28, //
  0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, //
  0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, //
  0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, //
  0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, //
  0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, //
  0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, //
  0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, //
  0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, //
  0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, //
  0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, //
  0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, //
  0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2, //
  0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, //
  0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, //
  0xF9, 0xFA, //
];

const List<int> _acChromaBits = <int>[
  0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77, //
];

const List<int> _acChromaValues = <int>[
  0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, //
  0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71, //
  0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91, //
  0xA1, 0xB1, 0xC1, 0x09, 0x23, 0x33, 0x52, 0xF0, //
  0x15, 0x62, 0x72, 0xD1, 0x0A, 0x16, 0x24, 0x34, //
  0xE1, 0x25, 0xF1, 0x17, 0x18, 0x19, 0x1A, 0x26, //
  0x27, 0x28, 0x29, 0x2A, 0x35, 0x36, 0x37, 0x38, //
  0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, //
  0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, //
  0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, //
  0x69, 0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, //
  0x79, 0x7A, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, //
  0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, //
  0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, //
  0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, //
  0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, //
  0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, //
  0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, //
  0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, //
  0xEA, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, //
  0xF9, 0xFA, //
];
