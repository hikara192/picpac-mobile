import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_core/design_core.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'asset_image_store.dart';
import 'jpeg_encoder.dart';
import 'sheet_layout.dart';
import 'sheet_painter.dart';

final class PdfExportOptions {
  const PdfExportOptions({
    this.quality = kExportJpegQuality,
    this.dpi = 0,
    this.title = 'PicPac',
    this.useIsolate = true,
  });

  final int quality;

  final int dpi;

  final String title;

  final bool useIsolate;
}

abstract final class PdfExporter {
  static Future<Uint8List> exportSheets({
    required DesignDocument document,
    required PrintSpec spec,
    required AssetImageStore images,
    Map<String, PrintTemplate> templates = const <String, PrintTemplate>{},
    PdfExportOptions options = const PdfExportOptions(),
    void Function(int done, int total)? onProgress,
  }) async {
    final catalog = BuiltInTemplates.mergedWith(templates);
    final pdf = pw.Document(title: options.title);
    final dpi = options.dpi > 0 ? options.dpi : spec.dpi;
    final total = document.spreads.length;
    var done = 0;

    for (var index = 0; index < document.spreads.length; index++) {
      final spread = document.spreads[index];
      final template = catalog[spread.templateId];
      if (template == null) continue;

      final pageWidthPx =
          (spec.effectiveSpreadWidthMm / PrintSpec.mmPerInch * dpi).round();
      final pageHeightPx =
          (spec.effectiveSpreadHeightMm / PrintSpec.mmPerInch * dpi).round();
      if (pageWidthPx <= 0 || pageHeightPx <= 0) continue;

      final layout = SheetLayout(
        spread: spread,
        template: template,
        spec: spec,
        area: Size(pageWidthPx.toDouble(), pageHeightPx.toDouble()),
      );

      final hashes = <String>{};
      for (final slot in spread.slots) {
        final photoId = slot.photoId;
        if (photoId == null) continue;
        final asset = document.assetById(photoId);
        if (asset == null) continue;
        hashes.add(asset.sha256);
        final rect = layout.rectOf(slot.id);
        images.request(
          asset.sha256,
          targetSide:
              (math.max(rect.width, rect.height) *
                      (slot.zoom < 1 ? 1 : slot.zoom))
                  .ceil(),
          intrinsicSide: math.max(asset.widthPx, asset.heightPx),
        );
      }
      await images.preload(hashes);

      final image = await renderSheetToImage(
        layout: layout,
        document: document,
        images: images,
        pixelSize: Size(pageWidthPx.toDouble(), pageHeightPx.toDouble()),
      );
      if (image == null) continue;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) continue;
        final jpeg = await _encode(
          data.buffer.asUint8List(),
          pageWidthPx,
          pageHeightPx,
          options,
        );
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormatOf(spec),
            build: (context) =>
                pw.Image(pw.MemoryImage(jpeg), fit: pw.BoxFit.fill),
          ),
        );
      } finally {
        image.dispose();
      }
      done++;
      onProgress?.call(done, total);
      await Future<void>.delayed(Duration.zero);
    }

    final bytes = await pdf.save();
    return Uint8List.fromList(bytes);
  }

  static PdfPageFormat pageFormatOf(PrintSpec spec) => PdfPageFormat(
    spec.effectiveSpreadWidthMm * PdfPageFormat.mm,
    spec.effectiveSpreadHeightMm * PdfPageFormat.mm,
    marginAll: 0,
  );

  static Future<Uint8List> _encode(
    Uint8List rgba,
    int width,
    int height,
    PdfExportOptions options,
  ) async {
    Uint8List encode() => encodeJpeg(
      rgba: rgba,
      width: width,
      height: height,
      quality: options.quality,
    );
    if (!options.useIsolate) return encode();
    try {
      return await Isolate.run(encode);
    } on Object {
      return encode();
    }
  }
}
