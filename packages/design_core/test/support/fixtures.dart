import 'dart:math' as math;

import 'package:design_core/design_core.dart';

String shaFor(String seed) {
  var value = 7;
  for (final unit in seed.codeUnits) {
    value = (value * 31 + unit) & 0xFFFFFF;
  }
  return value.toRadixString(16).padLeft(6, '0').padRight(64, 'a');
}

PhotoAsset asset(
  String id, {
  int widthPx = 3000,
  int heightPx = 2000,
  String mimeType = 'image/jpeg',
  int bytes = 1024 * 1024,
}) => PhotoAsset(
  id: id,
  sha256: shaFor(id),
  widthPx: widthPx,
  heightPx: heightPx,
  mimeType: mimeType,
  bytes: bytes,
);

const DocumentProduct printProduct = DocumentProduct(
  id: 'photo_print',
  formatId: '10x15',
);

const PrintSpec print10x15Spec = PrintSpec(
  widthMm: 100,
  heightMm: 150,
  dpi: 300,
);

Spread spreadFromTemplate(
  String id,
  PrintTemplate template, {
  List<String?> photoIds = const <String?>[],
  String templateId = '',
}) => Spread(
  id: id,
  templateId: templateId.isEmpty ? template.id : templateId,
  background: SpreadBackground.color('#FFFFFF'),
  slots: <Slot>[
    for (var i = 0; i < template.slots.length; i++)
      Slot(
        id: template.slots[i].id,
        photoId: i < photoIds.length ? photoIds[i] : null,
      ),
  ],
);

DesignDocument tenPhotoProject({String templateId = 'single_10x15'}) {
  final assets = <PhotoAsset>[for (var i = 0; i < 10; i++) asset('p$i')];
  final spreads = <Spread>[
    for (var i = 0; i < assets.length; i++)
      spreadFromTemplate(
        's$i',
        BuiltInTemplates.single10x15,
        photoIds: <String?>[assets[i].id],
      ),
  ];
  return DesignDocument(
    product: printProduct,
    spreads: spreads,
    spreadsCount: spreads.length,
    assets: assets,
  );
}

DesignDocument emptySlotsProject(PrintTemplate template) => DesignDocument(
  product: printProduct,
  spreads: <Spread>[spreadFromTemplate('s0', template)],
  spreadsCount: 1,
);

DesignDocument randomDocument(math.Random random, {int index = 0}) {
  final assetCount = 2 + random.nextInt(4);
  final assets = <PhotoAsset>[
    for (var i = 0; i < assetCount; i++)
      asset(
        'p$index-$i',
        widthPx: 600 + random.nextInt(3000),
        heightPx: 600 + random.nextInt(3000),
        bytes: 1000 + random.nextInt(2000000),
      ),
  ];
  const templateIds = <String>['single_10x15', 'duo_10x15', 'quad_10x15'];
  final spreadCount = 1 + random.nextInt(3);
  final spreads = <Spread>[];
  for (var s = 0; s < spreadCount; s++) {
    final template =
        BuiltInTemplates.byId[templateIds[random.nextInt(templateIds.length)]]!;
    final slots = <Slot>[];
    for (var i = 0; i < template.slots.length; i++) {
      final filled = random.nextInt(3) != 0;
      final crop = random.nextBool()
          ? Crop.full
          : Crop(
              x: random.nextDouble() * 0.3,
              y: random.nextDouble() * 0.3,
              w: 0.4 + random.nextDouble() * 0.3,
              h: 0.4 + random.nextDouble() * 0.3,
            );
      slots.add(
        Slot(
          id: template.slots[i].id,
          photoId: filled ? assets[random.nextInt(assets.length)].id : null,
          crop: crop,
          zoom: 1 + random.nextDouble() * 2,
          anchor: NormalizedPoint(random.nextDouble(), random.nextDouble()),
          rotation:
              QuarterTurn.values[random.nextInt(QuarterTurn.values.length)],
          flipH: random.nextBool(),
        ),
      );
    }
    spreads.add(
      Spread(
        id: 's$index-$s',
        templateId: template.id,
        background: SpreadBackground.color(
          random.nextBool() ? '#FFFFFF' : '#101010',
        ),
        slots: slots,
      ),
    );
  }

  final adjustments = <String, PhotoAdjustment>{};
  for (final photo in assets) {
    if (!random.nextBool()) continue;
    adjustments[photo.id] = PhotoAdjustment(
      exposure: random.nextDouble() * 4 - 2,
      contrast: random.nextDouble() * 200 - 100,
      temperature: random.nextDouble() * 200 - 100,
      tint: random.nextDouble() * 200 - 100,
      saturation: random.nextDouble() * 200 - 100,
      vibrance: random.nextDouble() * 200 - 100,
      look: random.nextBool()
          ? LookSetting(
              id: LookLibrary.presets[1 + random.nextInt(5)].id,
              strength: random.nextDouble(),
            )
          : null,
    );
  }

  final text = <TextElement>[
    if (random.nextBool())
      TextElement(
        id: 't$index-0',
        spreadId: spreads.first.id,
        text: 'PicPac',
        box: NormalizedRect(
          x: random.nextDouble() * 0.4,
          y: random.nextDouble() * 0.4,
          w: 0.2 + random.nextDouble() * 0.3,
          h: 0.05 + random.nextDouble() * 0.2,
        ),
        fontSizeNorm: 0.02 + random.nextDouble() * 0.05,
      ),
  ];

  return DesignDocument(
    revision: random.nextInt(100),
    product: printProduct,
    spreads: spreads,
    photoAdjustments: adjustments,
    text: text,
    spreadsCount: spreads.length + random.nextInt(2),
    assets: assets,
    coverSpreadId: random.nextBool() ? spreads.first.id : null,
  );
}
