import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../commands/command_result.dart';
import '../commands/design_command.dart';
import '../document/design_document.dart';
import '../document/geometry.dart';
import '../document/photo_asset.dart';
import '../document/slot.dart';
import '../document/spread.dart';
import '../templates/built_in_templates.dart';
import '../templates/print_template.dart';

enum PhotoOrientation {
  portrait,

  square,

  landscape;

  static PhotoOrientation ofAspect(double aspect) {
    if (!aspect.isFinite || aspect <= 0) return square;
    if (aspect < 0.9) return portrait;
    if (aspect > 1.1) return landscape;
    return square;
  }

  static PhotoOrientation of(PhotoAsset asset) => ofAspect(asset.aspect);
}

@immutable
final class PlannedSheet {
  const PlannedSheet({required this.template, required this.photoIds});

  final PrintTemplate template;

  final List<String?> photoIds;

  int get slotCount => template.slotCount;

  int get filledCount => photoIds.where((id) => id != null).length;

  bool get hasEmptySlot => filledCount < slotCount;

  @override
  String toString() => 'PlannedSheet(${template.id}, $filledCount/$slotCount)';
}

@immutable
final class LayoutPlan {
  const LayoutPlan(this.sheets);

  static const LayoutPlan empty = LayoutPlan(<PlannedSheet>[]);

  final List<PlannedSheet> sheets;

  int get sheetCount => sheets.length;

  bool get isEmpty => sheets.isEmpty;

  int get placedCount =>
      sheets.fold<int>(0, (sum, sheet) => sum + sheet.filledCount);

  int get emptySlotCount => sheets.fold<int>(
    0,
    (sum, sheet) => sum + (sheet.slotCount - sheet.filledCount),
  );

  List<String> get templateIds => <String>[
    for (final sheet in sheets) sheet.template.id,
  ];

  List<String> get photoIds => <String>[
    for (final sheet in sheets)
      for (final photoId in sheet.photoIds) ?photoId,
  ];

  DesignCommand toCommand({
    String background = LayoutPlanner.defaultBackground,
  }) => ApplyLayoutPlan(this, background: background);

  DesignDocument applyTo(
    DesignDocument document, {
    String background = LayoutPlanner.defaultBackground,
  }) => toCommand(background: background).apply(document);

  @override
  String toString() =>
      'LayoutPlan(${sheets.length} sheets, $placedCount photos, '
      '$emptySlotCount empty slots)';
}

abstract final class LayoutPlanner {
  static const String defaultBackground = '#FAF5ED';

  static String sheetId(int index) => 'sheet_${index + 1}';

  static const int denseMinPhotos = 4;

  static LayoutPlan planSheets({
    required List<PhotoAsset> photos,
    required List<PrintTemplate> templates,
    int minSheets = 1,
  }) {
    final catalog = _TemplateCatalog.of(templates);
    final minimum = math.max(minSheets, 0);

    if (photos.isEmpty) {
      final sheets = <PlannedSheet>[
        for (var i = 0; i < math.max(minimum, 1); i++)
          PlannedSheet(
            template: catalog.single,
            photoIds: <String?>[
              for (var s = 0; s < catalog.single.slotCount; s++) null,
            ],
          ),
      ];
      return LayoutPlan(List<PlannedSheet>.unmodifiable(sheets));
    }

    final dense = catalog.canPack && photos.length >= denseMinPhotos;
    final sheets = <PlannedSheet>[];

    if (!dense) {
      for (final photo in photos) {
        sheets.add(_singleSheet(catalog.single, photo.id));
      }
    } else {
      sheets.add(_singleSheet(catalog.single, photos[0].id));
      var index = 1;
      while (index < photos.length) {
        final remaining = photos.length - index;
        final quad = catalog.quad;
        final duo = catalog.duo;
        if (quad != null &&
            remaining >= quad.slotCount &&
            _sameOrientation(photos, index, quad.slotCount)) {
          sheets.add(_groupSheet(quad, photos, index));
          index += quad.slotCount;
          continue;
        }
        if (duo != null &&
            remaining >= duo.slotCount &&
            _sameOrientation(photos, index, duo.slotCount)) {
          sheets.add(_groupSheet(duo, photos, index));
          index += duo.slotCount;
          continue;
        }
        sheets.add(_singleSheet(catalog.single, photos[index].id));
        index++;
      }
    }

    while (sheets.length < minimum) {
      sheets.add(
        PlannedSheet(
          template: catalog.single,
          photoIds: <String?>[
            for (var s = 0; s < catalog.single.slotCount; s++) null,
          ],
        ),
      );
    }

    return LayoutPlan(List<PlannedSheet>.unmodifiable(sheets));
  }

  static LayoutPlan uniformPlan({
    required PrintTemplate template,
    required List<String> photoIds,
    int minSheets = 1,
  }) {
    final perSheet = math.max(1, template.slotCount);
    final needed = photoIds.isEmpty ? 0 : (photoIds.length / perSheet).ceil();
    final sheetCount = math.max(math.max(minSheets, needed), 0);
    final sheets = <PlannedSheet>[
      for (var index = 0; index < sheetCount; index++)
        PlannedSheet(
          template: template,
          photoIds: <String?>[
            for (var position = 0; position < perSheet; position++)
              index * perSheet + position < photoIds.length
                  ? photoIds[index * perSheet + position]
                  : null,
          ],
        ),
    ];
    return LayoutPlan(List<PlannedSheet>.unmodifiable(sheets));
  }

  @internal
  static DesignDocument materialise(
    DesignDocument document,
    LayoutPlan plan,
    String background,
  ) {
    final framing = _framingByPhoto(document);
    final previous = <String, Spread>{
      for (final spread in document.spreads) spread.id: spread,
    };

    final spreads = <Spread>[];
    for (var index = 0; index < plan.sheets.length; index++) {
      final sheet = plan.sheets[index];
      final id = sheetId(index);
      final slots = <Slot>[];
      for (
        var position = 0;
        position < sheet.template.slots.length;
        position++
      ) {
        final photoId = position < sheet.photoIds.length
            ? sheet.photoIds[position]
            : null;
        final kept = photoId == null ? null : framing[photoId];
        slots.add(
          Slot(
            id: sheet.template.slots[position].id,
            photoId: photoId,
            crop: kept?.crop ?? Crop.full,
            zoom: kept?.zoom ?? Slot.minZoom,
            anchor: kept?.anchor ?? NormalizedPoint.center,
            rotation: kept?.rotation ?? QuarterTurn.none,
            flipH: kept?.flipH ?? false,
          ),
        );
      }
      spreads.add(
        Spread(
          id: id,
          templateId: sheet.template.id,
          background:
              previous[id]?.background ?? SpreadBackground.color(background),
          slots: slots,
        ),
      );
    }
    return document.copyWith(spreads: spreads, spreadsCount: spreads.length);
  }

  static PlannedSheet _singleSheet(PrintTemplate template, String photoId) =>
      PlannedSheet(
        template: template,
        photoIds: <String?>[
          photoId,
          for (var i = 1; i < template.slotCount; i++) null,
        ],
      );

  static PlannedSheet _groupSheet(
    PrintTemplate template,
    List<PhotoAsset> photos,
    int start,
  ) => PlannedSheet(
    template: template,
    photoIds: <String?>[
      for (var i = 0; i < template.slotCount; i++)
        start + i < photos.length ? photos[start + i].id : null,
    ],
  );

  static bool _sameOrientation(List<PhotoAsset> photos, int start, int count) {
    if (start + count > photos.length) return false;
    final first = PhotoOrientation.of(photos[start]);
    for (var i = start + 1; i < start + count; i++) {
      if (PhotoOrientation.of(photos[i]) != first) return false;
    }
    return true;
  }

  static Map<String, Slot> _framingByPhoto(DesignDocument document) {
    final framing = <String, Slot>{};
    for (final spread in document.spreads) {
      for (final slot in spread.slots) {
        final photoId = slot.photoId;
        if (photoId == null) continue;
        framing.putIfAbsent(photoId, () => slot);
      }
    }
    return framing;
  }
}

final class _TemplateCatalog {
  const _TemplateCatalog({required this.single, this.duo, this.quad});

  factory _TemplateCatalog.of(List<PrintTemplate> templates) {
    final usable = <PrintTemplate>[
      for (final template in templates)
        if (template.slotCount > 0) template,
    ];
    if (usable.isEmpty) return _TemplateCatalog.of(BuiltInTemplates.all);
    PrintTemplate? pick(int slotCount) {
      for (final template in usable) {
        if (template.slotCount == slotCount) return template;
      }
      return null;
    }

    final single = pick(1) ?? pick(2) ?? usable.first;
    return _TemplateCatalog(
      single: single,
      duo: single.slotCount == 1 ? pick(2) : null,
      quad: single.slotCount == 1 ? pick(4) : null,
    );
  }

  final PrintTemplate single;
  final PrintTemplate? duo;
  final PrintTemplate? quad;

  bool get canPack => duo != null || quad != null;
}

final class ApplyLayoutPlan extends DesignCommand {
  const ApplyLayoutPlan(
    this.plan, {
    this.background = LayoutPlanner.defaultBackground,
  });

  final LayoutPlan plan;

  final String background;

  @override
  String get kind => 'applyLayoutPlan';

  @override
  CommandResult validate(DesignDocument document) {
    if (plan.isEmpty) {
      return const CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidTarget,
          message: 'an empty layout plan cannot be applied',
        ),
      );
    }
    for (final sheet in plan.sheets) {
      if (sheet.template.slots.isEmpty) {
        return CommandFailed(
          CommandError(
            code: CommandErrorCode.invalidTarget,
            message: 'template "${sheet.template.id}" has no slots',
            targetId: sheet.template.id,
          ),
        );
      }
      if (sheet.photoIds.length != sheet.template.slots.length) {
        return CommandFailed(
          CommandError(
            code: CommandErrorCode.invalidValue,
            message:
                'sheet "${sheet.template.id}" plans ${sheet.photoIds.length} '
                'photos for ${sheet.template.slots.length} slots',
            targetId: sheet.template.id,
          ),
        );
      }
      final seen = <String>{};
      for (final slot in sheet.template.slots) {
        if (!seen.add(slot.id)) {
          return CommandFailed(
            CommandError(
              code: CommandErrorCode.duplicateId,
              message:
                  'template "${sheet.template.id}" repeats slot "${slot.id}"',
              targetId: slot.id,
            ),
          );
        }
      }
      for (final photoId in sheet.photoIds) {
        if (photoId != null && document.assetById(photoId) == null) {
          return CommandFailed(
            CommandError(
              code: CommandErrorCode.photoNotInDocument,
              message: 'photo "$photoId" is not in the document',
              targetId: photoId,
            ),
          );
        }
      }
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) =>
      LayoutPlanner.materialise(document, plan, background);

  @override
  DesignCommand invertCore(DesignDocument preState) => _RestoreSheets(
    spreads: preState.spreads,
    spreadsCount: preState.spreadsCount,
    plan: plan,
    background: background,
  );

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'sheets': plan.sheetCount,
    'templateIds': plan.templateIds,
    'background': background,
  };

  @override
  String toString() => 'ApplyLayoutPlan(${plan.sheetCount} sheets)';
}

final class AutoLayoutSheets extends DesignCommand {
  const AutoLayoutSheets({
    required this.template,
    this.background = LayoutPlanner.defaultBackground,
    this.minSheets = 1,
  });

  static const String defaultBackground = LayoutPlanner.defaultBackground;

  final PrintTemplate template;

  final String background;

  final int minSheets;

  static String sheetId(int index) => LayoutPlanner.sheetId(index);

  @override
  String get kind => 'autoLayoutSheets';

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
    final seen = <String>{};
    for (final slot in template.slots) {
      if (!seen.add(slot.id)) {
        return CommandFailed(
          CommandError(
            code: CommandErrorCode.duplicateId,
            message: 'template "${template.id}" repeats slot "${slot.id}"',
            targetId: slot.id,
          ),
        );
      }
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) =>
      LayoutPlanner.materialise(
        document,
        LayoutPlanner.uniformPlan(
          template: template,
          photoIds: <String>[for (final asset in document.assets) asset.id],
          minSheets: minSheets,
        ),
        background,
      );

  @override
  DesignCommand invertCore(DesignDocument preState) => _RestoreSheets(
    spreads: preState.spreads,
    spreadsCount: preState.spreadsCount,
    plan: LayoutPlanner.uniformPlan(
      template: template,
      photoIds: <String>[for (final asset in preState.assets) asset.id],
      minSheets: minSheets,
    ),
    background: background,
  );

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'templateId': template.id,
    'minSheets': minSheets,
  };

  @override
  String toString() => 'AutoLayoutSheets(${template.id}, min $minSheets)';
}

final class _RestoreSheets extends DesignCommand {
  const _RestoreSheets({
    required this.spreads,
    required this.spreadsCount,
    required this.plan,
    required this.background,
  });

  final List<Spread> spreads;
  final int spreadsCount;
  final LayoutPlan plan;
  final String background;

  @override
  String get kind => 'restoreSheets';

  @override
  CommandResult validate(DesignDocument document) => const CommandOk();

  @override
  DesignDocument applyCore(DesignDocument document) =>
      document.copyWith(spreads: spreads, spreadsCount: spreadsCount);

  @override
  DesignCommand invertCore(DesignDocument preState) =>
      ApplyLayoutPlan(plan, background: background);

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'spreads': spreads.length,
  };
}
