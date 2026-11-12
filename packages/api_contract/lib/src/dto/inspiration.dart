import 'package:design_core/design_core.dart'
    show PrintTemplate, TemplateKind, TemplateSlot;

import '../json.dart';

final class InspirationItem with ValueJson {
  const InspirationItem({
    required this.id,
    required this.templateId,
    required this.titleKey,
    required this.tags,
    required this.aspect,
    required this.slots,
    required this.productKind,
    required this.popularity,
    this.isFavorite = false,
  });

  final String id;

  final String templateId;

  final String titleKey;

  final List<String> tags;

  final double aspect;

  final List<TemplateSlot> slots;

  final String productKind;

  final int popularity;

  final bool isFavorite;

  int get slotCount => slots.length;

  TemplateKind get kind => switch (productKind) {
    'book' => TemplateKind.spread,
    _ => slots.length > 1 ? TemplateKind.collage : TemplateKind.print,
  };

  PrintTemplate toPrintTemplate() => PrintTemplate(
    id: templateId,
    nameKey: titleKey,
    kind: kind,
    slots: slots,
    aspect: aspect,
  );

  InspirationItem withFavorite(bool value) => InspirationItem(
    id: id,
    templateId: templateId,
    titleKey: titleKey,
    tags: tags,
    aspect: aspect,
    slots: slots,
    productKind: productKind,
    popularity: popularity,
    isFavorite: value,
  );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'templateId': templateId,
    'titleKey': titleKey,
    'tags': tags,
    'aspect': aspect,
    'slots': <Object?>[for (final slot in slots) slot.toJson()],
    'productKind': productKind,
    'popularity': popularity,
    'isFavorite': isFavorite,
  };

  factory InspirationItem.fromJson(JsonMap json, [String path = r'$']) {
    final tags = J.readList(json['tags'], '$path.tags');
    final slots = J.readList(json['slots'], '$path.slots');
    return InspirationItem(
      id: J.readId(json['id'], '$path.id'),
      templateId: J.readId(json['templateId'], '$path.templateId'),
      titleKey: J.readId(json['titleKey'], '$path.titleKey'),
      tags: List<String>.unmodifiable(<String>[
        for (var i = 0; i < tags.length; i++)
          J.readString(tags[i], '$path.tags[$i]'),
      ]),
      aspect: J.readDoubleOrNull(json['aspect'], '$path.aspect') ?? 1,
      slots: List<TemplateSlot>.unmodifiable(<TemplateSlot>[
        for (var i = 0; i < slots.length; i++)
          TemplateSlot.fromJson(slots[i], '$path.slots[$i]'),
      ]),
      productKind: J.readId(json['productKind'], '$path.productKind'),
      popularity: J.readIntOrNull(json['popularity'], '$path.popularity') ?? 0,
      isFavorite: J.readBoolOr(
        json['isFavorite'],
        '$path.isFavorite',
        fallback: false,
      ),
    );
  }
}

final class InspirationFeedPage with ValueJson {
  const InspirationFeedPage({required this.items, this.nextCursor});

  final List<InspirationItem> items;

  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'items': <Object?>[for (final item in items) item.toJson()],
    if (nextCursor != null) 'nextCursor': nextCursor,
  };

  factory InspirationFeedPage.fromJson(JsonMap json, [String path = r'$']) {
    final items = J.readList(json['items'], '$path.items');
    return InspirationFeedPage(
      items: List<InspirationItem>.unmodifiable(<InspirationItem>[
        for (var i = 0; i < items.length; i++)
          InspirationItem.fromJson(
            J.readObject(items[i], '$path.items[$i]'),
            '$path.items[$i]',
          ),
      ]),
      nextCursor: J.readStringOrNull(json['nextCursor'], '$path.nextCursor'),
    );
  }
}

final class InspirationSupport with ValueJson {
  const InspirationSupport({
    required this.productId,
    required this.productTitle,
    required this.formatId,
    required this.formatTitle,
    required this.productKind,
  });

  final String productId;

  final String productTitle;

  final String formatId;

  final String formatTitle;

  final String productKind;

  String get label => '$productTitle $formatTitle';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'productId': productId,
    'productTitle': productTitle,
    'formatId': formatId,
    'formatTitle': formatTitle,
    'productKind': productKind,
  };

  factory InspirationSupport.fromJson(JsonMap json, [String path = r'$']) =>
      InspirationSupport(
        productId: J.readId(json['productId'], '$path.productId'),
        productTitle: J.readString(json['productTitle'], '$path.productTitle'),
        formatId: J.readId(json['formatId'], '$path.formatId'),
        formatTitle: J.readString(json['formatTitle'], '$path.formatTitle'),
        productKind: J.readId(json['productKind'], '$path.productKind'),
      );
}

final class InspirationDetail with ValueJson {
  const InspirationDetail({required this.item, required this.supports});

  final InspirationItem item;

  final List<InspirationSupport> supports;

  bool get isSupported => supports.isNotEmpty;

  List<String> get supportLabels => <String>[
    for (final support in supports) support.label,
  ];

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'item': item.toJson(),
    'supports': <Object?>[for (final support in supports) support.toJson()],
  };

  factory InspirationDetail.fromJson(JsonMap json, [String path = r'$']) {
    final supports = J.readList(json['supports'], '$path.supports');
    return InspirationDetail(
      item: InspirationItem.fromJson(
        J.readObject(json['item'], '$path.item'),
        '$path.item',
      ),
      supports: List<InspirationSupport>.unmodifiable(<InspirationSupport>[
        for (var i = 0; i < supports.length; i++)
          InspirationSupport.fromJson(
            J.readObject(supports[i], '$path.supports[$i]'),
            '$path.supports[$i]',
          ),
      ]),
    );
  }
}

final class FavoriteState with ValueJson {
  const FavoriteState({required this.templateId, required this.isFavorite});

  final String templateId;

  final bool isFavorite;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'templateId': templateId,
    'isFavorite': isFavorite,
  };

  factory FavoriteState.fromJson(JsonMap json, [String path = r'$']) =>
      FavoriteState(
        templateId: J.readId(json['templateId'], '$path.templateId'),
        isFavorite: J.readBoolOr(
          json['isFavorite'],
          '$path.isFavorite',
          fallback: true,
        ),
      );
}
