import 'package:meta/meta.dart';

import '../core/json_read.dart';
import '../document/design_format_exception.dart';
import '../document/print_spec.dart';

@immutable
final class FormatSpec {
  const FormatSpec({
    required this.id,
    required this.print,
    this.minPhotos = 0,
    this.maxPhotos = 0,
    this.minSpreads = 0,
    this.maxSpreads = 0,
    this.spreadStep = 0,
    this.allowedTemplateIds = const <String>{},
  });

  final String id;

  final PrintSpec print;

  final int minPhotos;

  final int maxPhotos;

  final int minSpreads;

  final int maxSpreads;

  final int spreadStep;

  final Set<String> allowedTemplateIds;

  bool allowsTemplate(String templateId) =>
      allowedTemplateIds.isEmpty || allowedTemplateIds.contains(templateId);

  bool allowsSpreadCount(int count) {
    if (minSpreads > 0 && count < minSpreads) return false;
    if (maxSpreads > 0 && count > maxSpreads) return false;
    if (spreadStep > 1 && (count - minSpreads) % spreadStep != 0) return false;
    return true;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'print': print.toJson(),
    'minPhotos': minPhotos,
    'maxPhotos': maxPhotos,
    'minSpreads': minSpreads,
    'maxSpreads': maxSpreads,
    'spreadStep': spreadStep,
    if (allowedTemplateIds.isNotEmpty)
      'allowedTemplateIds': allowedTemplateIds.toList()..sort(),
  };

  factory FormatSpec.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    return FormatSpec(
      id: JsonRead.id(map['id'], '$path.id'),
      print: PrintSpec.fromJson(map['print'], '$path.print'),
      minPhotos: JsonRead.optInteger(map['minPhotos'], '$path.minPhotos') ?? 0,
      maxPhotos: JsonRead.optInteger(map['maxPhotos'], '$path.maxPhotos') ?? 0,
      minSpreads:
          JsonRead.optInteger(map['minSpreads'], '$path.minSpreads') ?? 0,
      maxSpreads:
          JsonRead.optInteger(map['maxSpreads'], '$path.maxSpreads') ?? 0,
      spreadStep:
          JsonRead.optInteger(map['spreadStep'], '$path.spreadStep') ?? 0,
      allowedTemplateIds: map['allowedTemplateIds'] == null
          ? const <String>{}
          : JsonRead.idList(
              map['allowedTemplateIds'],
              '$path.allowedTemplateIds',
            ).toSet(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FormatSpec &&
      other.id == id &&
      other.print == print &&
      other.minPhotos == minPhotos &&
      other.maxPhotos == maxPhotos &&
      other.minSpreads == minSpreads &&
      other.maxSpreads == maxSpreads &&
      other.spreadStep == spreadStep &&
      other.allowedTemplateIds.length == allowedTemplateIds.length &&
      other.allowedTemplateIds.containsAll(allowedTemplateIds);

  @override
  int get hashCode => Object.hash(
    id,
    print,
    minPhotos,
    maxPhotos,
    minSpreads,
    maxSpreads,
    spreadStep,
    Object.hashAllUnordered(allowedTemplateIds),
  );

  @override
  String toString() => 'FormatSpec($id, ${print.widthMm}x${print.heightMm} mm)';
}
