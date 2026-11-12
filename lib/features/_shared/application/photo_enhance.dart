import 'package:design_core/design_core.dart';

final class EnhancePlan {
  const EnhancePlan({
    required this.commands,
    required this.applied,
    required this.alreadyEnhanced,
    required this.unanalysed,
  });

  final List<DesignCommand> commands;

  final int applied;

  final int alreadyEnhanced;

  final int unanalysed;

  bool get isEmpty => commands.isEmpty;
}

EnhancePlan planEnhanceAll(
  DesignDocument document,
  Map<String, PhotoAnalysis> analyses,
) {
  final commands = <DesignCommand>[];
  var applied = 0;
  var alreadyEnhanced = 0;
  var unanalysed = 0;

  for (final asset in document.assets) {
    final adjustment = document.photoAdjustments[asset.id];
    if (_hasTone(adjustment)) {
      alreadyEnhanced++;
      continue;
    }
    final analysis = analyses[asset.id];
    if (analysis == null || analysis.pixelCount == 0) {
      unanalysed++;
      continue;
    }
    final look = adjustment?.look;
    final proposal = AutoEnhance.propose(
      analysis,
      lookId: look?.id,
      lookStrength: look?.strength ?? 0,
    );
    if (proposal.isNeutral) {
      unanalysed++;
      continue;
    }
    for (final field in PhotoAdjustmentField.values) {
      final value = proposal.valueOf(field);
      if (value == 0) continue;
      commands.add(
        SetPhotoAdjustment(photoId: asset.id, field: field, value: value),
      );
    }
    applied++;
  }

  return EnhancePlan(
    commands: commands,
    applied: applied,
    alreadyEnhanced: alreadyEnhanced,
    unanalysed: unanalysed,
  );
}

bool _hasTone(PhotoAdjustment? adjustment) =>
    adjustment != null &&
    (adjustment.exposure != 0 ||
        adjustment.contrast != 0 ||
        adjustment.temperature != 0 ||
        adjustment.tint != 0);
