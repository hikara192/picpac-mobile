import 'package:design_core/design_core.dart';

final class ResetToImported extends DesignCommand {
  const ResetToImported({
    required this.template,
    this.background = LayoutPlanner.defaultBackground,
    this.minSheets = 1,
  });

  final PrintTemplate template;

  final String background;

  final int minSheets;

  @override
  String get kind => 'resetToImported';

  @override
  CommandResult validate(DesignDocument document) {
    if (template.slots.isEmpty) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidTarget,
          message: 'template "${template.id}" has no slots',
          targetId: template.id,
        ),
      );
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) {
    final laidOut = AutoLayoutSheets(
      template: template,
      background: background,
      minSheets: minSheets,
    ).applyCore(document);
    final reset = <Spread>[
      for (final spread in laidOut.spreads)
        spread.copyWith(
          background: SpreadBackground.color(background),
          slots: <Slot>[
            for (final slot in spread.slots)
              Slot(id: slot.id, photoId: slot.photoId),
          ],
        ),
    ];
    return laidOut.copyWith(
      spreads: reset,
      photoAdjustments: const <String, PhotoAdjustment>{},
    );
  }

  @override
  DesignCommand invertCore(DesignDocument preState) => _RestoreProject(
    spreads: preState.spreads,
    spreadsCount: preState.spreadsCount,
    photoAdjustments: preState.photoAdjustments,
  );

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'templateId': template.id,
    'minSheets': minSheets,
  };

  @override
  String toString() => 'ResetToImported(${template.id})';
}

final class _RestoreProject extends DesignCommand {
  const _RestoreProject({
    required this.spreads,
    required this.spreadsCount,
    required this.photoAdjustments,
  });

  final List<Spread> spreads;
  final int spreadsCount;
  final Map<String, PhotoAdjustment> photoAdjustments;

  @override
  String get kind => 'restoreProject';

  @override
  CommandResult validate(DesignDocument document) => const CommandOk();

  @override
  DesignDocument applyCore(DesignDocument document) => document.copyWith(
    spreads: spreads,
    spreadsCount: spreadsCount,
    photoAdjustments: photoAdjustments,
  );

  @override
  DesignCommand invertCore(DesignDocument preState) => ResetToImported(
    template: BuiltInTemplates.single10x15,
    minSheets: preState.spreads.length,
  );

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'spreads': spreads.length,
    'adjusted': photoAdjustments.length,
  };
}
