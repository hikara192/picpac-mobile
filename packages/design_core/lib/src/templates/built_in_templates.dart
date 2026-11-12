import '../document/geometry.dart';
import 'print_template.dart';

abstract final class BuiltInTemplates {
  static const PrintTemplate single10x15 = PrintTemplate(
    id: single10x15Id,
    nameKey: 'template.single_10x15',
    kind: TemplateKind.print,
    aspect: 2 / 3,
    slots: <TemplateSlot>[TemplateSlot(id: 'main', rect: NormalizedRect.unit)],
  );

  static const PrintTemplate duo10x15 = PrintTemplate(
    id: duo10x15Id,
    nameKey: 'template.duo_10x15',
    kind: TemplateKind.print,
    aspect: 2 / 3,
    slots: <TemplateSlot>[
      TemplateSlot(
        id: 'top',
        rect: NormalizedRect(x: 0, y: 0, w: 1, h: 0.4975),
      ),
      TemplateSlot(
        id: 'bottom',
        rect: NormalizedRect(x: 0, y: 0.5025, w: 1, h: 0.4975),
      ),
    ],
  );

  static const PrintTemplate quad10x15 = PrintTemplate(
    id: quad10x15Id,
    nameKey: 'template.quad_10x15',
    kind: TemplateKind.collage,
    aspect: 2 / 3,
    slots: <TemplateSlot>[
      TemplateSlot(
        id: 'tl',
        rect: NormalizedRect(x: 0, y: 0, w: 0.4975, h: 0.4975),
      ),
      TemplateSlot(
        id: 'tr',
        rect: NormalizedRect(x: 0.5025, y: 0, w: 0.4975, h: 0.4975),
      ),
      TemplateSlot(
        id: 'bl',
        rect: NormalizedRect(x: 0, y: 0.5025, w: 0.4975, h: 0.4975),
      ),
      TemplateSlot(
        id: 'br',
        rect: NormalizedRect(x: 0.5025, y: 0.5025, w: 0.4975, h: 0.4975),
      ),
    ],
  );

  static const PrintTemplate single3x4 = PrintTemplate(
    id: single3x4Id,
    nameKey: 'template.single_3x4',
    kind: TemplateKind.print,
    aspect: 3 / 4,
    slots: <TemplateSlot>[TemplateSlot(id: 'main', rect: NormalizedRect.unit)],
  );

  static const String single10x15Id = 'single_10x15';

  static const String duo10x15Id = 'duo_10x15';

  static const String quad10x15Id = 'quad_10x15';

  static const String single3x4Id = 'single_3x4';

  static const List<PrintTemplate> all = <PrintTemplate>[
    single10x15,
    duo10x15,
    quad10x15,
    single3x4,
  ];

  static const Map<String, PrintTemplate> byId = <String, PrintTemplate>{
    single10x15Id: single10x15,
    duo10x15Id: duo10x15,
    quad10x15Id: quad10x15,
    single3x4Id: single3x4,
  };

  static Map<String, PrintTemplate> mergedWith(
    Map<String, PrintTemplate> serverTemplates,
  ) => <String, PrintTemplate>{...byId, ...serverTemplates};
}
