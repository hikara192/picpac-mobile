import 'package:meta/meta.dart';

import '../core/json_read.dart';
import '../document/design_format_exception.dart';

@immutable
final class PrintSpec {
  const PrintSpec({
    required this.widthMm,
    required this.heightMm,
    this.bleedMm = 0,
    this.safeMm = 0,
    this.dpi = defaultDpi,
    this.spreadWidthMm,
    this.spreadHeightMm,
    this.coverWidthMm,
    this.coverHeightMm,
  });

  static const int defaultDpi = 300;

  static const double mmPerInch = 25.4;

  final double widthMm;

  final double heightMm;

  final double bleedMm;

  final double safeMm;

  final int dpi;

  final double? spreadWidthMm;

  final double? spreadHeightMm;

  final double? coverWidthMm;

  final double? coverHeightMm;

  double get effectiveSpreadWidthMm => spreadWidthMm ?? widthMm;

  double get effectiveSpreadHeightMm => spreadHeightMm ?? heightMm;

  double requiredPx(double mm) => mm / mmPerInch * dpi;

  int requiredPxFor(double mm) => requiredPx(mm).round();

  int get targetPxWidth => requiredPxFor(widthMm);

  int get targetPxHeight => requiredPxFor(heightMm);

  int get spreadTargetPxWidth => requiredPxFor(effectiveSpreadWidthMm);

  int get spreadTargetPxHeight => requiredPxFor(effectiveSpreadHeightMm);

  double get safeWidthFraction =>
      effectiveSpreadWidthMm == 0 ? 0 : safeMm / effectiveSpreadWidthMm;

  double get safeHeightFraction =>
      effectiveSpreadHeightMm == 0 ? 0 : safeMm / effectiveSpreadHeightMm;

  PrintSpec copyWith({
    double? widthMm,
    double? heightMm,
    double? bleedMm,
    double? safeMm,
    int? dpi,
    double? spreadWidthMm,
    double? spreadHeightMm,
    double? coverWidthMm,
    double? coverHeightMm,
  }) => PrintSpec(
    widthMm: widthMm ?? this.widthMm,
    heightMm: heightMm ?? this.heightMm,
    bleedMm: bleedMm ?? this.bleedMm,
    safeMm: safeMm ?? this.safeMm,
    dpi: dpi ?? this.dpi,
    spreadWidthMm: spreadWidthMm ?? this.spreadWidthMm,
    spreadHeightMm: spreadHeightMm ?? this.spreadHeightMm,
    coverWidthMm: coverWidthMm ?? this.coverWidthMm,
    coverHeightMm: coverHeightMm ?? this.coverHeightMm,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'widthMm': widthMm,
    'heightMm': heightMm,
    'bleedMm': bleedMm,
    'safeMm': safeMm,
    'dpi': dpi,
    if (spreadWidthMm != null) 'spreadWidthMm': spreadWidthMm,
    if (spreadHeightMm != null) 'spreadHeightMm': spreadHeightMm,
    if (coverWidthMm != null) 'coverWidthMm': coverWidthMm,
    if (coverHeightMm != null) 'coverHeightMm': coverHeightMm,
  };

  factory PrintSpec.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final widthMm = JsonRead.number(map['widthMm'], '$path.widthMm');
    final heightMm = JsonRead.number(map['heightMm'], '$path.heightMm');
    final bleedMm = JsonRead.optNumber(map['bleedMm'], '$path.bleedMm') ?? 0;
    final safeMm = JsonRead.optNumber(map['safeMm'], '$path.safeMm') ?? 0;
    final dpi = JsonRead.optInteger(map['dpi'], '$path.dpi') ?? defaultDpi;
    if (widthMm <= 0 || heightMm <= 0) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'print size must be positive, got ${widthMm}x$heightMm mm',
        path: path,
      );
    }
    if (bleedMm < 0 || safeMm < 0) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'bleed and safety must be non-negative',
        path: path,
      );
    }
    if (dpi <= 0) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'dpi must be positive, got $dpi',
        path: '$path.dpi',
      );
    }
    return PrintSpec(
      widthMm: widthMm,
      heightMm: heightMm,
      bleedMm: bleedMm,
      safeMm: safeMm,
      dpi: dpi,
      spreadWidthMm: JsonRead.optNumber(
        map['spreadWidthMm'],
        '$path.spreadWidthMm',
      ),
      spreadHeightMm: JsonRead.optNumber(
        map['spreadHeightMm'],
        '$path.spreadHeightMm',
      ),
      coverWidthMm: JsonRead.optNumber(
        map['coverWidthMm'],
        '$path.coverWidthMm',
      ),
      coverHeightMm: JsonRead.optNumber(
        map['coverHeightMm'],
        '$path.coverHeightMm',
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PrintSpec &&
      other.widthMm == widthMm &&
      other.heightMm == heightMm &&
      other.bleedMm == bleedMm &&
      other.safeMm == safeMm &&
      other.dpi == dpi &&
      other.spreadWidthMm == spreadWidthMm &&
      other.spreadHeightMm == spreadHeightMm &&
      other.coverWidthMm == coverWidthMm &&
      other.coverHeightMm == coverHeightMm;

  @override
  int get hashCode => Object.hash(
    widthMm,
    heightMm,
    bleedMm,
    safeMm,
    dpi,
    spreadWidthMm,
    spreadHeightMm,
    coverWidthMm,
    coverHeightMm,
  );

  @override
  String toString() =>
      'PrintSpec(${widthMm}x$heightMm mm, bleed $bleedMm, safe $safeMm, '
      'dpi $dpi)';
}
