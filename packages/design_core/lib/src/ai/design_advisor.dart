import '../document/adjustment_limits.dart';
import '../document/slot.dart';
import '../projections/document_summary.dart';
import 'design_patch.dart';

abstract final class AiIntents {
  static const String warmer = 'warmer';

  static const String brighter = 'brighter';

  static const String mono = 'mono';

  static const String fillSlots = 'fill_slots';

  static const String denser = 'denser';

  static const String alignFrames = 'align_frames';

  static const List<String> chips = <String>[
    warmer,
    brighter,
    mono,
    fillSlots,
    denser,
    alignFrames,
  ];
}

abstract final class DesignAdvisor {
  static const String skillId = 'picpac.rules.design';

  static const String skillVersion = '1.0.0';

  static const String toolSchemaVersion = '1';

  static const String model = 'rules';

  static const double monoStrength = 1;

  static const String monoLookId = 'mono';

  static const double warmthStep = 12;

  static const double exposureStep = 0.15;

  static const double contrastStep = 12;

  static DesignPatch propose({
    required DocumentSummary summary,
    required String intent,
    int maxOps = kMaxPatchOperations,
    Map<String, int> templates = const <String, int>{},
  }) {
    final normalised = normaliseIntent(intent);
    final operations = _operationsFor(summary, normalised, maxOps, templates);
    return DesignPatch(
      baseRevision: summary.revision,
      operations: List<PatchOperation>.unmodifiable(operations),
      meta: const PatchMeta(
        skillId: skillId,
        skillVersion: skillVersion,
        toolSchemaVersion: toolSchemaVersion,
        model: model,
        promptHash: '',
      ),
    );
  }

  static String normaliseIntent(String intent) {
    final folded = intent
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'[^\p{L}\p{N}/ ]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return folded;
  }

  static List<PatchOperation> _operationsFor(
    DocumentSummary summary,
    String intent,
    int maxOps,
    Map<String, int> templates,
  ) {
    if (_contains(intent, _monoWords)) {
      return <PatchOperation>[
        const ApplyLookOperation(lookId: monoLookId, strength: monoStrength),
      ];
    }
    if (_contains(intent, _warmWords)) {
      return <PatchOperation>[
        SetAdjustmentOperation(
          field: PhotoAdjustmentField.temperature,
          value: _value(PhotoAdjustmentField.temperature, warmthStep),
        ),
      ];
    }
    if (_contains(intent, _coolWords)) {
      return <PatchOperation>[
        SetAdjustmentOperation(
          field: PhotoAdjustmentField.temperature,
          value: _value(PhotoAdjustmentField.temperature, -warmthStep),
        ),
      ];
    }
    if (_contains(intent, _brightWords)) {
      return <PatchOperation>[
        SetAdjustmentOperation(
          field: PhotoAdjustmentField.exposure,
          value: _value(PhotoAdjustmentField.exposure, exposureStep),
        ),
      ];
    }
    if (_contains(intent, _darkWords)) {
      return <PatchOperation>[
        SetAdjustmentOperation(
          field: PhotoAdjustmentField.exposure,
          value: _value(PhotoAdjustmentField.exposure, -exposureStep),
        ),
      ];
    }
    if (_contains(intent, _contrastWords)) {
      return <PatchOperation>[
        SetAdjustmentOperation(
          field: PhotoAdjustmentField.contrast,
          value: _value(PhotoAdjustmentField.contrast, contrastStep),
        ),
      ];
    }
    if (_contains(intent, _alignWords)) {
      return _alignFrames(summary, maxOps);
    }
    if (_contains(intent, _fillWords)) {
      return _fillEmptySlots(summary, maxOps);
    }
    if (_contains(intent, _denseWords)) {
      return _denserLayout(summary, maxOps, templates);
    }
    return const <PatchOperation>[];
  }

  static List<PatchOperation> _alignFrames(
    DocumentSummary summary,
    int maxOps,
  ) {
    final operations = <PatchOperation>[];
    for (final spread in summary.spreads) {
      for (final slot in spread.slots) {
        if (operations.length >= maxOps) return operations;
        if (slot.photoId == null) continue;
        final centred = _centredCrop(slot.crop);
        if (centred == slot.crop) continue;
        operations.add(
          SetCropOperation(
            spreadId: spread.id,
            slotId: slot.id,
            crop: centred,
            zoom: slot.zoom,
            anchor: slot.anchor,
          ),
        );
      }
    }
    return operations;
  }

  static List<PatchOperation> _fillEmptySlots(
    DocumentSummary summary,
    int maxOps,
  ) {
    final free = <String>[
      for (final photoId in summary.unassignedPhotoIds) photoId,
    ];
    if (free.isEmpty) return const <PatchOperation>[];
    final operations = <PatchOperation>[];
    var next = 0;
    for (final spread in summary.spreads) {
      for (final slot in spread.slots) {
        if (next >= free.length) return operations;
        if (slot.photoId != null) continue;
        operations.add(
          AssignPhotoOperation(
            spreadId: spread.id,
            slotId: slot.id,
            photoId: free[next++],
          ),
        );
        if (operations.length >= maxOps) return operations;
      }
    }
    return operations;
  }

  static List<PatchOperation> _denserLayout(
    DocumentSummary summary,
    int maxOps,
    Map<String, int> templates,
  ) {
    final free = summary.unassignedPhotoIds;
    final densest = _densestTemplate(templates);
    if (free.isEmpty || densest == null) {
      return _fillEmptySlots(summary, maxOps);
    }
    for (final spread in summary.spreads) {
      final gained = densest.slotCount - spread.slotCount;
      if (gained <= 0 || gained > free.length) continue;
      return <PatchOperation>[
        SetLayoutOperation(
          templateId: densest.id,
          spreadIds: <String>[spread.id],
        ),
      ];
    }
    return _fillEmptySlots(summary, maxOps);
  }

  static ({String id, int slotCount})? _densestTemplate(
    Map<String, int> templates,
  ) {
    ({String id, int slotCount})? best;
    for (final entry in templates.entries) {
      if (entry.value <= 1) continue;
      if (best == null || entry.value > best.slotCount) {
        best = (id: entry.key, slotCount: entry.value);
      }
    }
    return best;
  }

  static double _value(PhotoAdjustmentField field, double value) =>
      AdjustmentLimits.of(field).snap(value);

  static Crop _centredCrop(Crop crop) {
    final width = crop.w.clamp(kMinCropSize, 1.0).toDouble();
    final height = crop.h.clamp(kMinCropSize, 1.0).toDouble();
    return Crop(
      x: ((1 - width) / 2).clamp(0.0, 1.0).toDouble(),
      y: ((1 - height) / 2).clamp(0.0, 1.0).toDouble(),
      w: width,
      h: height,
    );
  }

  static bool _contains(String intent, List<String> words) {
    for (final word in words) {
      if (intent.contains(word)) return true;
    }
    return false;
  }

  static const List<String> _monoWords = <String>[
    AiIntents.mono,
    'ч/б',
    'чб',
    'моно',
    'черно бел',
    'чернобел',
    'black and white',
    'monochrome',
  ];

  static const List<String> _warmWords = <String>[
    AiIntents.warmer,
    'тепл',
    'warmer',
    'warmer tones',
  ];

  static const List<String> _coolWords = <String>[
    'cooler',
    'холод',
    'прохлад',
    'cooler tones',
  ];

  static const List<String> _brightWords = <String>[
    AiIntents.brighter,
    'ярч',
    'светл',
    'brighter',
    'bright',
    'lighten',
  ];

  static const List<String> _darkWords = <String>['темн', 'darker', 'darken'];

  static const List<String> _contrastWords = <String>['контраст', 'contrast'];

  static const List<String> _alignWords = <String>[
    AiIntents.alignFrames,
    'выровн',
    'по центру',
    'центр',
    'center',
    'centre',
    'align',
  ];

  static const List<String> _fillWords = <String>[
    AiIntents.fillSlots,
    'заполн',
    'пуст',
    'fill',
    'empty',
  ];

  static const List<String> _denseWords = <String>[
    AiIntents.denser,
    'плотн',
    'denser',
    'compact',
  ];
}
