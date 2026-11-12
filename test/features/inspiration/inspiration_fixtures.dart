import 'package:api_contract/api_contract.dart';

InspirationItem duoIdea({
  String id = 'idea_duo',
  String templateId = 'insp_duo_split',
  String titleKey = 'inspirationTemplateDuoSplit',
  List<String> tags = const <String>['семья', 'минимализм'],
  bool isFavorite = false,
  int popularity = 90,
}) => InspirationItem(
  id: id,
  templateId: templateId,
  titleKey: titleKey,
  tags: tags,
  aspect: 2 / 3,
  slots: stackedSlots(2),
  productKind: 'print',
  popularity: popularity,
  isFavorite: isFavorite,
);

InspirationItem quadIdea({
  String id = 'idea_quad',
  String templateId = 'insp_quad_2x2',
  String titleKey = 'inspirationTemplateQuadGrid',
  List<String> tags = const <String>['путешествие'],
  bool isFavorite = false,
  int popularity = 80,
}) => InspirationItem(
  id: id,
  templateId: templateId,
  titleKey: titleKey,
  tags: tags,
  aspect: 2 / 3,
  slots: gridSlots(),
  productKind: 'print',
  popularity: popularity,
  isFavorite: isFavorite,
);

List<TemplateSlot> stackedSlots(int count) {
  final height = 1 / count;
  return <TemplateSlot>[
    for (var index = 0; index < count; index++)
      TemplateSlot(
        id: 'row_${index + 1}',
        rect: NormalizedRect(x: 0, y: index * height, w: 1, h: height - 0.01),
      ),
  ];
}

List<TemplateSlot> gridSlots() => const <TemplateSlot>[
  TemplateSlot(id: 'tl', rect: NormalizedRect(x: 0, y: 0, w: 0.49, h: 0.49)),
  TemplateSlot(id: 'tr', rect: NormalizedRect(x: 0.51, y: 0, w: 0.49, h: 0.49)),
  TemplateSlot(id: 'bl', rect: NormalizedRect(x: 0, y: 0.51, w: 0.49, h: 0.49)),
  TemplateSlot(
    id: 'br',
    rect: NormalizedRect(x: 0.51, y: 0.51, w: 0.49, h: 0.49),
  ),
];

InspirationDetail detailOf(InspirationItem item) => InspirationDetail(
  item: item,
  supports: const <InspirationSupport>[
    InspirationSupport(
      productId: 'photo_print',
      productTitle: 'Печать фотографий',
      formatId: '10x15',
      formatTitle: '10×15',
      productKind: 'print',
    ),
  ],
);

InspirationFeedPage feedOf(List<InspirationItem> items, {String? nextCursor}) =>
    InspirationFeedPage(items: items, nextCursor: nextCursor);

ProductFormat formatWithTemplates(
  ProductFormat base,
  List<ProductTemplate> extra,
) => ProductFormat(
  id: base.id,
  productId: base.productId,
  title: base.title,
  widthMm: base.widthMm,
  heightMm: base.heightMm,
  bleedMm: base.bleedMm,
  safeMm: base.safeMm,
  dpi: base.dpi,
  minPhotos: base.minPhotos,
  maxPhotos: base.maxPhotos,
  minSpreads: base.minSpreads,
  maxSpreads: base.maxSpreads,
  spreadStep: base.spreadStep,
  spreadWidthMm: base.spreadWidthMm,
  spreadHeightMm: base.spreadHeightMm,
  coverWidthMm: base.coverWidthMm,
  coverHeightMm: base.coverHeightMm,
  etaDays: base.etaDays,
  options: base.options,
  templates: <ProductTemplate>[...base.templates, ...extra],
);

ProductTemplate templateOf(InspirationItem item) => ProductTemplate(
  id: item.templateId,
  nameKey: item.titleKey,
  kind: item.kind,
  aspect: item.aspect,
  slots: item.slots,
);
