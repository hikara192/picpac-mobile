import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:design_core/design_core.dart';
import 'package:flutter/rendering.dart';

import 'asset_image_store.dart';
import 'sheet_layout.dart';

final class SheetPalette {
  const SheetPalette({
    this.paper = const Color(0xFFFFFFFF),
    this.emptyFill = const Color(0xFFDEDFDC),
    this.emptyBorder = const Color(0xFFBCBFB7),
    this.emptyGlyph = const Color(0xFFAEB4B3),
    this.selection = const Color(0xFFDD5757),
    this.slotRing = const Color(0xFF364C49),
    this.guide = const Color(0x66DD5757),
    this.outline = const Color(0xFFCCC7BF),
  });

  final Color paper;

  final Color emptyFill;

  final Color emptyBorder;

  final Color emptyGlyph;

  final Color selection;

  final Color slotRing;

  final Color guide;

  final Color outline;
}

class SheetPainter extends CustomPainter {
  SheetPainter({
    required this.layout,
    required this.document,
    required this.images,
    this.palette = const SheetPalette(),
    this.selectedSlotId,
    this.showGuides = false,
    this.applyAdjustments = true,
  }) : super(repaint: images);

  final SheetLayout layout;

  final DesignDocument document;

  final AssetImageStore images;

  final SheetPalette palette;

  final String? selectedSlotId;

  final bool showGuides;

  final bool applyAdjustments;

  static final Map<PhotoAdjustment, List<double>> _matrices =
      <PhotoAdjustment, List<double>>{};

  static List<double> matrixFor(PhotoAdjustment adjustment) {
    if (adjustment.isNeutral) return AdjustmentMatrix.identity;
    final cached = _matrices[adjustment];
    if (cached != null) return cached;
    if (_matrices.length > 256) _matrices.clear();
    final matrix = AdjustmentMatrix.encoded(adjustment);
    _matrices[adjustment] = matrix;
    return matrix;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sheet = layout.sheetRect;
    if (sheet.isEmpty) return;

    final background = layout.spread.background.argbColor;
    canvas.drawRect(
      sheet,
      Paint()..color = background == null ? palette.paper : Color(background),
    );

    canvas.save();
    canvas.clipRect(sheet);
    for (final templateSlot in layout.template.slots) {
      final slot = layout.spread.slotById(templateSlot.id);
      final target = layout.rectOf(templateSlot.id);
      if (target.isEmpty) continue;

      final asset = slot?.photoId == null
          ? null
          : document.assetById(slot!.photoId!);
      final image = asset == null ? null : images.imageOf(asset.sha256);
      if (asset != null && image == null) images.request(asset.sha256);

      if (slot != null && image != null) {
        _paintPhoto(canvas, slot: slot, image: image, target: target);
      } else {
        _paintEmptySlot(canvas, target);
      }

      if (showGuides) {
        _paintDashedRect(canvas, layout.safeRectOf(templateSlot.id));
      }
    }
    canvas.restore();

    canvas.drawRect(
      sheet.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = palette.outline,
    );
    if (showGuides) _paintDashedRect(canvas, layout.safeBox);

    final selected = selectedSlotId;
    if (selected != null) {
      final rect = layout.rectOf(selected);
      if (!rect.isEmpty) {
        canvas.drawRect(
          rect.deflate(1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = palette.slotRing,
        );
      }
    }
  }

  void _paintPhoto(
    Canvas canvas, {
    required Slot slot,
    required ui.Image image,
    required Rect target,
  }) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final source = layout.sourceRectFor(slot: slot, imageSize: imageSize);
    final quad = layout.untransformedSize(slot, target);
    final adjustment = applyAdjustments
        ? document.adjustmentFor(slot.photoId!)
        : PhotoAdjustment.neutral;
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;
    if (!adjustment.isNeutral) {
      paint.colorFilter = ColorFilter.matrix(matrixFor(adjustment));
    }

    canvas.save();
    if (!slot.hasOrientation) {
      canvas.drawImageRect(image, source, target, paint);
      canvas.restore();
      return;
    }
    canvas.clipRect(target, doAntiAlias: false);
    canvas.translate(target.center.dx, target.center.dy);
    if (!slot.rotation.isNone) {
      canvas.rotate(slot.rotation.degrees * math.pi / 180);
    }
    if (slot.flipH) canvas.scale(-1, 1);
    canvas.drawImageRect(
      image,
      source,
      Rect.fromCenter(
        center: Offset.zero,
        width: quad.width,
        height: quad.height,
      ),
      paint,
    );
    canvas.restore();
  }

  void _paintEmptySlot(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = palette.emptyFill);
    canvas.drawRect(
      rect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = palette.emptyBorder,
    );
    final radius = math.min(rect.width, rect.height) * 0.12;
    if (radius < 6) return;
    final centre = rect.center;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, radius * 0.12)
      ..strokeCap = StrokeCap.round
      ..color = palette.emptyGlyph;
    canvas.drawLine(
      Offset(centre.dx - radius, centre.dy),
      Offset(centre.dx + radius, centre.dy),
      stroke,
    );
    canvas.drawLine(
      Offset(centre.dx, centre.dy - radius),
      Offset(centre.dx, centre.dy + radius),
      stroke,
    );
  }

  void _paintDashedRect(Canvas canvas, Rect rect) {
    if (rect.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = palette.guide;
    const dash = 6.0;
    const gap = 4.0;
    for (var x = rect.left; x < rect.right; x += dash + gap) {
      final end = math.min(x + dash, rect.right);
      canvas.drawLine(Offset(x, rect.top), Offset(end, rect.top), paint);
      canvas.drawLine(Offset(x, rect.bottom), Offset(end, rect.bottom), paint);
    }
    for (var y = rect.top; y < rect.bottom; y += dash + gap) {
      final end = math.min(y + dash, rect.bottom);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.left, end), paint);
      canvas.drawLine(Offset(rect.right, y), Offset(rect.right, end), paint);
    }
  }

  @override
  bool shouldRepaint(covariant SheetPainter oldDelegate) =>
      oldDelegate.layout.spread != layout.spread ||
      oldDelegate.layout.template != layout.template ||
      oldDelegate.layout.spec != layout.spec ||
      oldDelegate.layout.area != layout.area ||
      oldDelegate.document.revision != document.revision ||
      !identical(oldDelegate.document.assets, document.assets) ||
      oldDelegate.selectedSlotId != selectedSlotId ||
      oldDelegate.showGuides != showGuides ||
      oldDelegate.applyAdjustments != applyAdjustments ||
      oldDelegate.images != images;
}

Future<ui.Image?> renderSheetToImage({
  required SheetLayout layout,
  required DesignDocument document,
  required AssetImageStore images,
  required Size pixelSize,
  SheetPalette palette = const SheetPalette(),
  double pixelRatio = 1,
  bool applyAdjustments = true,
}) async {
  if (pixelSize.isEmpty) return null;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(pixelRatio);
  SheetPainter(
    layout: layout,
    document: document,
    images: images,
    palette: palette,
    applyAdjustments: applyAdjustments,
  ).paint(canvas, pixelSize);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    pixelSize.width.round(),
    pixelSize.height.round(),
  );
  picture.dispose();
  return image;
}
