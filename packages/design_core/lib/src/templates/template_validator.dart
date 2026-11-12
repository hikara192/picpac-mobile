import 'package:meta/meta.dart';

import '../document/geometry.dart';
import 'format_spec.dart';
import 'print_template.dart';

enum TemplateIssueCode {
  emptySlotList('empty_slot_list'),

  duplicateSlotId('duplicate_slot_id'),

  slotOutOfBounds('slot_out_of_bounds'),

  slotsOverlap('slots_overlap'),

  areaExceeded('area_exceeded'),

  slotCountOutOfRange('slot_count_out_of_range'),

  aspectMismatch('aspect_mismatch'),

  templateNotAllowed('template_not_allowed'),

  invalidAspect('invalid_aspect'),

  unknown('unknown');

  const TemplateIssueCode(this.wire);

  final String wire;
}

@immutable
final class TemplateIssue {
  const TemplateIssue({required this.code, this.slotId, this.args = const {}});

  final TemplateIssueCode code;

  final String? slotId;

  final Map<String, Object?> args;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code.wire,
    if (slotId != null) 'slotId': slotId,
    if (args.isNotEmpty) 'args': args,
  };

  @override
  String toString() =>
      'TemplateIssue(${code.wire}${slotId == null ? '' : ' $slotId'})';
}

@immutable
final class TemplateValidation {
  const TemplateValidation(this.issues);

  final List<TemplateIssue> issues;

  bool get isValid => issues.isEmpty;

  List<TemplateIssueCode> get codes => <TemplateIssueCode>[
    for (final issue in issues) issue.code,
  ];

  List<TemplateIssue> issuesFor(String slotId) =>
      issues.where((issue) => issue.slotId == slotId).toList();

  @override
  String toString() => 'TemplateValidation(${issues.length} issues)';
}

abstract final class TemplateValidator {
  static const double minSlotArea = 1e-4;

  static TemplateValidation validateGeometry(PrintTemplate template) {
    final issues = <TemplateIssue>[];
    if (template.slots.isEmpty) {
      issues.add(const TemplateIssue(code: TemplateIssueCode.emptySlotList));
    }
    if (!(template.aspect > 0)) {
      issues.add(const TemplateIssue(code: TemplateIssueCode.invalidAspect));
    }
    final seen = <String>{};
    var area = 0.0;
    for (final slot in template.slots) {
      if (!seen.add(slot.id)) {
        issues.add(
          TemplateIssue(
            code: TemplateIssueCode.duplicateSlotId,
            slotId: slot.id,
          ),
        );
      }
      if (!slot.rect.isValidUnitRect || slot.rect.area < minSlotArea) {
        issues.add(
          TemplateIssue(
            code: TemplateIssueCode.slotOutOfBounds,
            slotId: slot.id,
            args: <String, Object?>{'rect': slot.rect.toJson()},
          ),
        );
      }
      area += slot.rect.area;
    }
    for (var i = 0; i < template.slots.length; i++) {
      for (var j = i + 1; j < template.slots.length; j++) {
        if (template.slots[i].rect.intersects(template.slots[j].rect)) {
          issues.add(
            TemplateIssue(
              code: TemplateIssueCode.slotsOverlap,
              slotId: template.slots[j].id,
              args: <String, Object?>{'otherSlotId': template.slots[i].id},
            ),
          );
        }
      }
    }
    if (area > 1 + kUnitEpsilon) {
      issues.add(
        TemplateIssue(
          code: TemplateIssueCode.areaExceeded,
          args: <String, Object?>{'area': area},
        ),
      );
    }
    return TemplateValidation(List<TemplateIssue>.unmodifiable(issues));
  }

  static TemplateValidation validateForFormat(
    PrintTemplate template,
    FormatSpec format, {
    double aspectTolerance = 0.02,
  }) {
    final issues = <TemplateIssue>[...validateGeometry(template).issues];
    final slotCount = template.slots.length;
    if (format.minPhotos > 0 && slotCount < format.minPhotos) {
      issues.add(
        TemplateIssue(
          code: TemplateIssueCode.slotCountOutOfRange,
          args: <String, Object?>{
            'slots': slotCount,
            'min': format.minPhotos,
            'max': format.maxPhotos,
          },
        ),
      );
    }
    if (format.maxPhotos > 0 && slotCount > format.maxPhotos) {
      issues.add(
        TemplateIssue(
          code: TemplateIssueCode.slotCountOutOfRange,
          args: <String, Object?>{
            'slots': slotCount,
            'min': format.minPhotos,
            'max': format.maxPhotos,
          },
        ),
      );
    }
    final formatAspect = format.print.widthMm / format.print.heightMm;
    if ((template.aspect - formatAspect).abs() > aspectTolerance) {
      issues.add(
        TemplateIssue(
          code: TemplateIssueCode.aspectMismatch,
          args: <String, Object?>{
            'templateAspect': template.aspect,
            'formatAspect': formatAspect,
          },
        ),
      );
    }
    if (!format.allowsTemplate(template.id)) {
      issues.add(
        TemplateIssue(
          code: TemplateIssueCode.templateNotAllowed,
          args: <String, Object?>{'templateId': template.id},
        ),
      );
    }
    return TemplateValidation(List<TemplateIssue>.unmodifiable(issues));
  }
}
