import 'dart:math' as math;

import '../document/design_document.dart';
import '../document/geometry.dart';
import '../document/photo_asset.dart';
import '../document/print_spec.dart';
import '../document/slot.dart';
import '../document/text_element.dart';
import '../templates/built_in_templates.dart';
import '../templates/print_template.dart';
import 'metrics.dart';
import 'preflight_model.dart';

abstract final class PreflightProjection {
  static PreflightReport run({
    required DesignDocument document,
    required PrintSpec spec,
    Iterable<PhotoAsset>? assets,
    Map<String, PrintTemplate>? templates,
    PreflightConfig config = const PreflightConfig(),
    TextMetrics textMetrics = const HeuristicTextMetrics(),
    FaceEdgeDetector? faceDetector,
  }) {
    final catalog = <String, PhotoAsset>{
      for (final asset in assets ?? document.assets) asset.id: asset,
    };
    final templateMap = templates == null
        ? BuiltInTemplates.byId
        : BuiltInTemplates.mergedWith(templates);
    final issues = <PreflightIssue>[];

    for (final spread in document.spreads) {
      final template = templateMap[spread.templateId];
      for (final slot in spread.slots) {
        final templateSlot = template?.slotById(slot.id);
        final photoId = slot.photoId;
        if (photoId == null) {
          issues.add(
            PreflightIssue(
              code: PreflightCode.emptySlot,
              severity: config.severityOf(PreflightCode.emptySlot),
              targetId: slot.id,
              messageKey: PreflightMessageKeys.emptySlot,
              args: <String, Object?>{
                'spreadId': spread.id,
                'reason': 'no_photo',
              },
              fixAction: PreflightFixAction.assignPhoto,
              spreadId: spread.id,
              slotId: slot.id,
            ),
          );
          continue;
        }

        final asset = assets == null
            ? (catalog[photoId] ?? document.assetById(photoId))
            : catalog[photoId];
        if (asset == null) {
          issues.add(
            PreflightIssue(
              code: PreflightCode.emptySlot,
              severity: config.severityOf(PreflightCode.emptySlot),
              targetId: slot.id,
              messageKey: PreflightMessageKeys.emptySlot,
              args: <String, Object?>{
                'spreadId': spread.id,
                'reason': 'missing_asset',
              },
              fixAction: PreflightFixAction.assignPhoto,
              spreadId: spread.id,
              slotId: slot.id,
              photoId: photoId,
            ),
          );
          continue;
        }

        if (!config.allowedMimeTypes.contains(asset.mimeType.toLowerCase())) {
          issues.add(
            PreflightIssue(
              code: PreflightCode.unsupportedFormat,
              severity: config.severityOf(PreflightCode.unsupportedFormat),
              targetId: slot.id,
              messageKey: PreflightMessageKeys.unsupportedFormat,
              args: <String, Object?>{
                'spreadId': spread.id,
                'mimeType': asset.mimeType,
                'allowed': (config.allowedMimeTypes.toList()..sort()).join(
                  ', ',
                ),
              },
              fixAction: PreflightFixAction.convertFormat,
              spreadId: spread.id,
              slotId: slot.id,
              photoId: photoId,
            ),
          );
        }

        if (templateSlot == null) continue;

        final slotWidthMm = spec.effectiveSpreadWidthMm * templateSlot.rect.w;
        final slotHeightMm = spec.effectiveSpreadHeightMm * templateSlot.rect.h;
        if (slotWidthMm <= 0 || slotHeightMm <= 0) continue;

        final dpiIssue = _checkDpi(
          document: document,
          spec: spec,
          config: config,
          spreadId: spread.id,
          slotId: slot.id,
          asset: asset,
          zoomWindow: slot.effectiveSourceWindow,
          slotWidthMm: slotWidthMm,
          slotHeightMm: slotHeightMm,
          zoom: slot.zoom,
          rotation: slot.rotation,
        );
        if (dpiIssue != null) issues.add(dpiIssue);

        final safeZoneIssue = _checkSafeZone(
          spec: spec,
          config: config,
          spreadId: spread.id,
          slotId: slot.id,
          photoId: photoId,
          templateSlot: templateSlot,
        );
        if (safeZoneIssue != null) issues.add(safeZoneIssue);

        if (faceDetector != null) {
          issues.addAll(
            _checkFaces(
              document: document,
              config: config,
              detector: faceDetector,
              asset: asset,
              spreadId: spread.id,
              slotId: slot.id,
              window: slot.effectiveSourceWindow,
            ),
          );
        }
      }

      for (final element in document.textForSpread(spread.id)) {
        final issue = _checkText(
          element: element,
          spec: spec,
          config: config,
          metrics: textMetrics,
        );
        if (issue != null) issues.add(issue);
      }
    }

    return PreflightReport(List<PreflightIssue>.unmodifiable(issues));
  }

  static PreflightIssue? _checkDpi({
    required DesignDocument document,
    required PrintSpec spec,
    required PreflightConfig config,
    required String spreadId,
    required String slotId,
    required PhotoAsset asset,
    required Crop zoomWindow,
    required double slotWidthMm,
    required double slotHeightMm,
    required double zoom,
    required QuarterTurn rotation,
  }) {
    final availableWidthPx = asset.widthPx * zoomWindow.w;
    final availableHeightPx = asset.heightPx * zoomWindow.h;
    final swapped = rotation.swapsAxes;
    final widthPx = swapped ? availableHeightPx : availableWidthPx;
    final heightPx = swapped ? availableWidthPx : availableHeightPx;
    final dpiX = widthPx / (slotWidthMm / PrintSpec.mmPerInch);
    final dpiY = heightPx / (slotHeightMm / PrintSpec.mmPerInch);
    final effectiveDpi = math.min(dpiX, dpiY);
    if (effectiveDpi + config.dpiTolerance >= spec.dpi) return null;
    return PreflightIssue(
      code: PreflightCode.lowDpi,
      severity: config.severityOf(PreflightCode.lowDpi),
      targetId: slotId,
      messageKey: PreflightMessageKeys.lowDpi,
      args: <String, Object?>{
        'spreadId': spreadId,
        'photoPx': '${asset.widthPx}×${asset.heightPx}',
        'sourcePx': '${widthPx.floor()}×${heightPx.floor()}',
        'requiredPx':
            '${spec.requiredPxFor(slotWidthMm)}×'
            '${spec.requiredPxFor(slotHeightMm)}',
        'effectiveDpi': effectiveDpi.floor(),
        'requiredDpi': spec.dpi,
        'slotWidthMm': _round1(slotWidthMm),
        'slotHeightMm': _round1(slotHeightMm),
        'zoom': _round3(zoom),
        if (swapped) 'rotation': rotation.degrees,
        if (swapped) 'axesSwapped': true,
      },
      fixAction: zoom > 1
          ? PreflightFixAction.lowerZoom
          : PreflightFixAction.replacePhoto,
      spreadId: spreadId,
      slotId: slotId,
      photoId: asset.id,
    );
  }

  static PreflightIssue? _checkSafeZone({
    required PrintSpec spec,
    required PreflightConfig config,
    required String spreadId,
    required String slotId,
    required String photoId,
    required TemplateSlot templateSlot,
  }) {
    final safeW = spec.safeWidthFraction;
    final safeH = spec.safeHeightFraction;
    if (safeW <= 0 && safeH <= 0 && templateSlot.safeInset <= 0) return null;
    final safeBox = NormalizedRect(
      x: safeW,
      y: safeH,
      w: 1 - 2 * safeW,
      h: 1 - 2 * safeH,
    );
    if (safeBox.w <= 0 || safeBox.h <= 0) return null;

    final content = templateSlot.rect.deflate(templateSlot.safeInset);
    if (content.w <= 0 || content.h <= 0) {
      return PreflightIssue(
        code: PreflightCode.safeZone,
        severity: config.severityOf(PreflightCode.safeZone),
        targetId: slotId,
        messageKey: PreflightMessageKeys.safeZone,
        args: <String, Object?>{
          'spreadId': spreadId,
          'reason': 'slot_smaller_than_safe',
        },
        fixAction: PreflightFixAction.reposition,
        spreadId: spreadId,
        slotId: slotId,
        photoId: photoId,
      );
    }
    if (safeBox.containsRect(content)) return null;

    final overshootX =
        math.max(
          0.0,
          math.max(safeBox.x - content.x, content.right - safeBox.right),
        ) *
        spec.effectiveSpreadWidthMm;
    final overshootY =
        math.max(
          0.0,
          math.max(safeBox.y - content.y, content.bottom - safeBox.bottom),
        ) *
        spec.effectiveSpreadHeightMm;
    final overflowMm = math.max(overshootX, overshootY);
    if (overflowMm <= config.safeOverflowToleranceMm) return null;
    return PreflightIssue(
      code: PreflightCode.safeZone,
      severity: config.severityOf(PreflightCode.safeZone),
      targetId: slotId,
      messageKey: PreflightMessageKeys.safeZone,
      args: <String, Object?>{
        'spreadId': spreadId,
        'reason': 'content_in_trim_margin',
        'overflowMm': _round1(overflowMm),
        'safeMm': spec.safeMm,
      },
      fixAction: PreflightFixAction.reposition,
      spreadId: spreadId,
      slotId: slotId,
      photoId: photoId,
    );
  }

  static List<PreflightIssue> _checkFaces({
    required DesignDocument document,
    required PreflightConfig config,
    required FaceEdgeDetector detector,
    required PhotoAsset asset,
    required String spreadId,
    required String slotId,
    required Crop window,
  }) {
    final faces = detector.faces(
      PhotoAssetRef(id: asset.id, sha256: asset.sha256),
      document,
    );
    if (faces.isEmpty) return const <PreflightIssue>[];
    final band = config.faceEdgeBand.clamp(0.0, 0.45);
    final windowRect = NormalizedRect(
      x: window.x,
      y: window.y,
      w: window.w,
      h: window.h,
    );
    final issues = <PreflightIssue>[];
    for (final face in faces) {
      final visible = face.intersection(windowRect);
      if (visible == null) continue;
      final left = (visible.x - window.x) / window.w;
      final right = (visible.x + visible.w - window.x) / window.w;
      final top = (visible.y - window.y) / window.h;
      final bottom = (visible.y + visible.h - window.y) / window.h;
      final horizontalEdge = left < band
          ? 'left'
          : right > 1 - band
          ? 'right'
          : null;
      final verticalEdge = top < band
          ? 'top'
          : bottom > 1 - band
          ? 'bottom'
          : null;
      if (horizontalEdge == null && verticalEdge == null) continue;
      issues.add(
        PreflightIssue(
          code: PreflightCode.faceAtEdge,
          severity: config.severityOf(PreflightCode.faceAtEdge),
          targetId: slotId,
          messageKey: PreflightMessageKeys.faceAtEdge,
          args: <String, Object?>{
            'spreadId': spreadId,
            'edge': horizontalEdge ?? verticalEdge,
          },
          fixAction: PreflightFixAction.reposition,
          spreadId: spreadId,
          slotId: slotId,
          photoId: asset.id,
        ),
      );
    }
    return issues;
  }

  static PreflightIssue? _checkText({
    required TextElement element,
    required PrintSpec spec,
    required PreflightConfig config,
    required TextMetrics metrics,
  }) {
    if (element.isBlank) return null;
    if (!element.box.isValidUnitRect) {
      return PreflightIssue(
        code: PreflightCode.textOverflow,
        severity: config.severityOf(PreflightCode.textOverflow),
        targetId: element.id,
        messageKey: PreflightMessageKeys.textOverflow,
        args: <String, Object?>{
          'spreadId': element.spreadId,
          'reason': 'outside_spread',
        },
        fixAction: PreflightFixAction.reposition,
        spreadId: element.spreadId,
      );
    }
    final extent = metrics.measure(element, spec);
    if (!extent.exceedsBox) return null;
    return PreflightIssue(
      code: PreflightCode.textOverflow,
      severity: config.severityOf(PreflightCode.textOverflow),
      targetId: element.id,
      messageKey: PreflightMessageKeys.textOverflow,
      args: <String, Object?>{
        'spreadId': element.spreadId,
        'reason': 'text_too_large',
        'lineCount': extent.lineCount,
        'requiredHeightMm': _round1(extent.requiredHeightMm),
        'availableHeightMm': _round1(extent.availableHeightMm),
      },
      fixAction: PreflightFixAction.reduceText,
      spreadId: element.spreadId,
    );
  }

  static double _round1(double value) => (value * 10).round() / 10;

  static double _round3(double value) => (value * 1000).round() / 1000;
}
