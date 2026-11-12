import 'dart:math' as math;

import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../render/asset_image_store.dart';
import '../../../render/sheet_layout.dart';
import '../../../render/sheet_painter.dart';
import '../application/media_providers.dart';

typedef SheetSceneBuilder = Widget Function(
  BuildContext context,
  SheetLayout layout,
  AssetImageStore images,
);

class SheetScene extends ConsumerWidget {
  const SheetScene({
    required this.designId,
    required this.document,
    required this.spread,
    required this.template,
    required this.spec,
    this.selectedSlotId,
    this.showGuides = false,
    this.maxSide = 1024,
    this.slotDecodeTargets = false,
    this.palette = const SheetPalette(),
    this.semanticLabel,
    this.builder,
    super.key,
  });

  final String designId;

  final DesignDocument document;

  final Spread spread;

  final PrintTemplate template;

  final PrintSpec spec;

  final String? selectedSlotId;

  final bool showGuides;

  final int maxSide;

  final bool slotDecodeTargets;

  final SheetPalette palette;

  final String? semanticLabel;

  final SheetSceneBuilder? builder;

  double get aspectRatio {
    final height = spec.effectiveSpreadHeightMm;
    if (height <= 0) return 1;
    return spec.effectiveSpreadWidthMm / height;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(
      assetImageStoreProvider((designId: designId, maxSide: maxSide)),
    );
    for (final slot in spread.slots) {
      final photoId = slot.photoId;
      if (photoId == null) continue;
      final asset = document.assetById(photoId);
      if (asset == null) continue;
      final geometry = template.slotById(slot.id);
      if (!slotDecodeTargets || geometry == null) {
        store.request(asset.sha256);
        continue;
      }
      store.request(
        asset.sha256,
        targetSide: math.max(
          maxSide,
          slotDecodeSidePx(
            widthMm: geometry.rect.w * spec.effectiveSpreadWidthMm,
            heightMm: geometry.rect.h * spec.effectiveSpreadHeightMm,
            dpi: spec.dpi,
            zoom: slot.zoom,
          ),
        ),
        intrinsicSide: math.max(asset.widthPx, asset.heightPx),
      );
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = SheetLayout(
            spread: spread,
            template: template,
            spec: spec,
            area: constraints.biggest,
          );
          final scene = RepaintBoundary(
            child: CustomPaint(
              painter: SheetPainter(
                layout: layout,
                document: document,
                images: store,
                palette: palette,
                selectedSlotId: selectedSlotId,
                showGuides: showGuides,
              ),
              size: Size.infinite,
            ),
          );
          final overlay = builder?.call(context, layout, store);
          final label = semanticLabel;
          final picture = label == null
              ? scene
              : Semantics(image: true, label: label, child: scene);
          if (overlay == null) return picture;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[picture, overlay],
          );
        },
      ),
    );
  }
}
