import 'dart:convert';
import 'dart:ui' as ui;

import 'package:design_core/design_core.dart';
import 'package:flutter/widgets.dart';

import '../render/asset_image_store.dart';
import '../render/sheet_layout.dart';
import '../render/sheet_painter.dart';

const int kAiPreviewMinSide = 512;
const int kAiPreviewMaxSide = 768;

Future<String?> renderPreviewBase64({
  required DesignDocument document,
  required Spread spread,
  required PrintTemplate template,
  required PrintSpec spec,
  required AssetImageStore images,
  int maxSide = kAiPreviewMaxSide,
}) async {
  final side = maxSide.clamp(kAiPreviewMinSide, kAiPreviewMaxSide);
  final widthMm = spec.effectiveSpreadWidthMm;
  final heightMm = spec.effectiveSpreadHeightMm;
  if (widthMm <= 0 || heightMm <= 0) return null;

  final aspect = widthMm / heightMm;
  final width = aspect >= 1 ? side : (side * aspect).round();
  final height = aspect >= 1 ? (side / aspect).round() : side;
  if (width < 1 || height < 1) return null;

  final hashes = <String>{
    for (final slot in spread.slots)
      if (slot.photoId != null)
        if (document.assetById(slot.photoId!) case final asset?) asset.sha256,
  };
  if (hashes.isNotEmpty) {
    await images.preload(hashes);
  }

  final layout = SheetLayout(
    spread: spread,
    template: template,
    spec: spec,
    area: Size(width.toDouble(), height.toDouble()),
  );
  final image = await renderSheetToImage(
    layout: layout,
    document: document,
    images: images,
    pixelSize: Size(width.toDouble(), height.toDouble()),
  );
  if (image == null) return null;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return base64Encode(bytes);
  } on Object {
    return null;
  } finally {
    image.dispose();
  }
}
