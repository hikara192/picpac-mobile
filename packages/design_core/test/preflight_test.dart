import 'package:design_core/design_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

const PrintSpec oneInchSpec = PrintSpec(widthMm: 25.4, heightMm: 25.4);

DesignDocument singleSlotProject(PhotoAsset photo, {PrintTemplate? template}) {
  final used = template ?? BuiltInTemplates.single10x15;
  return DesignDocument(
    product: printProduct,
    spreads: <Spread>[
      Spread(
        id: 's0',
        templateId: used.id,
        background: SpreadBackground.color('#FFFFFF'),
        slots: <Slot>[Slot(id: used.slots.first.id, photoId: photo.id)],
      ),
    ],
    spreadsCount: 1,
    assets: <PhotoAsset>[photo],
  );
}

void main() {
  group('preflight', () {
    test('EMPTY_SLOT is reported and blocks the order', () {
      final document = emptySlotsProject(BuiltInTemplates.single10x15);
      final report = PreflightProjection.run(
        document: document,
        spec: print10x15Spec,
      );
      expect(report.hasBlockingIssues, isTrue);
      expect(report.codes, contains(PreflightCode.emptySlot));
      expect(report.canOrder, isFalse);
      final issue = report.issuesFor('main').single;
      expect(issue.severity, PreflightSeverity.error);
      expect(issue.messageKey, PreflightMessageKeys.emptySlot);
      expect(issue.fixAction, PreflightFixAction.assignPhoto);
      expect(issue.args['reason'], 'no_photo');
    });

    test('a slot referencing a photo missing from the manifest is empty', () {
      final document = singleSlotProject(asset('p0'));
      final report = PreflightProjection.run(
        document: document,
        spec: print10x15Spec,
        assets: const <PhotoAsset>[],
      );
      expect(report.issuesFor('main').single.args['reason'], 'missing_asset');
    });

    test('exactly 300 dpi is acceptable', () {
      final document = singleSlotProject(
        asset('p0', widthPx: 300, heightPx: 300),
      );
      final report = PreflightProjection.run(
        document: document,
        spec: oneInchSpec,
      );
      expect(report.codes, isNot(contains(PreflightCode.lowDpi)));
    });

    test('299 dpi is reported as LOW_DPI with message arguments', () {
      final document = singleSlotProject(
        asset('p0', widthPx: 299, heightPx: 299),
      );
      final report = PreflightProjection.run(
        document: document,
        spec: oneInchSpec,
      );
      final issue = report.issuesFor('main').single;
      expect(issue.code, PreflightCode.lowDpi);
      expect(issue.severity, PreflightSeverity.warning);
      expect(issue.messageKey, PreflightMessageKeys.lowDpi);
      expect(issue.args['effectiveDpi'], 299);
      expect(issue.args['requiredDpi'], 300);
      expect(issue.args['requiredPx'], '300×300');
      expect(issue.args['photoPx'], '299×299');
      expect(report.canOrder, isTrue, reason: 'warnings do not block');
    });

    test('zoom reduces the effective resolution', () {
      final base = singleSlotProject(asset('p0', widthPx: 600, heightPx: 600));
      final report = PreflightProjection.run(document: base, spec: oneInchSpec);
      expect(report.codes, isNot(contains(PreflightCode.lowDpi)));

      final zoomed = base.copyWith(
        spreads: <Spread>[
          base.spreads.first.copyWith(
            slots: <Slot>[base.spreads.first.slots.first.copyWith(zoom: 2.5)],
          ),
        ],
      );
      final zoomedReport = PreflightProjection.run(
        document: zoomed,
        spec: oneInchSpec,
      );
      expect(zoomedReport.codes, contains(PreflightCode.lowDpi));
      final issue = zoomedReport.issuesFor('main').single;
      expect(issue.args['zoom'], 2.5);
      expect(issue.fixAction, PreflightFixAction.lowerZoom);
    });

    test('UNSUPPORTED_FORMAT is blocking and suggests conversion', () {
      final document = singleSlotProject(asset('p0', mimeType: 'image/heic'));
      final report = PreflightProjection.run(
        document: document,
        spec: print10x15Spec,
      );
      final formatIssue = report.issues.firstWhere(
        (issue) => issue.code == PreflightCode.unsupportedFormat,
      );
      expect(formatIssue.severity, PreflightSeverity.error);
      expect(formatIssue.fixAction, PreflightFixAction.convertFormat);
      expect(formatIssue.args['mimeType'], 'image/heic');
      expect(report.canOrder, isFalse);
    });

    test('SAFE_ZONE is reported when a slot sits in the trim margin', () {
      const bookSpec = PrintSpec(
        widthMm: 400,
        heightMm: 203,
        safeMm: 3,
        dpi: 300,
      );
      final document = singleSlotProject(
        asset('p0', widthPx: 6000, heightPx: 6000),
      );
      final report = PreflightProjection.run(
        document: document,
        spec: bookSpec,
      );
      final issue = report.issues.firstWhere(
        (issue) => issue.code == PreflightCode.safeZone,
      );
      expect(issue.severity, PreflightSeverity.warning);
      expect(issue.args['reason'], 'content_in_trim_margin');
      expect(issue.args['safeMm'], 3);
      expect(issue.fixAction, PreflightFixAction.reposition);
    });

    test('full-bleed photo prints have no SAFE_ZONE issue', () {
      final document = singleSlotProject(
        asset('p0', widthPx: 4000, heightPx: 4000),
      );
      final report = PreflightProjection.run(
        document: document,
        spec: print10x15Spec,
      );
      expect(report.codes, isNot(contains(PreflightCode.safeZone)));
    });

    test('TEXT_OVERFLOW is reported for text that does not fit', () {
      final document =
          singleSlotProject(asset('p0', widthPx: 4000, heightPx: 4000))
              .copyWith(
                text: const <TextElement>[
                  TextElement(
                    id: 't0',
                    spreadId: 's0',
                    text: 'Длинная подпись, которая заведомо не помещается в узкий бокс',
                    box: NormalizedRect(x: 0.1, y: 0.05, w: 0.2, h: 0.02),
                    fontSizeNorm: 0.05,
                  ),
                ],
              );
      final report = PreflightProjection.run(
        document: document,
        spec: print10x15Spec,
      );
      final issue = report.issuesFor('t0').single;
      expect(issue.code, PreflightCode.textOverflow);
      expect(issue.args['reason'], 'text_too_large');
      expect(issue.fixAction, PreflightFixAction.reduceText);
    });

    test('short text inside a large box passes', () {
      final document =
          singleSlotProject(asset('p0', widthPx: 4000, heightPx: 4000))
              .copyWith(
                text: const <TextElement>[
                  TextElement(
                    id: 't0',
                    spreadId: 's0',
                    text: 'PicPac',
                    box: NormalizedRect(x: 0.1, y: 0.1, w: 0.8, h: 0.3),
                    fontSizeNorm: 0.05,
                  ),
                ],
              );
      final report = PreflightProjection.run(
        document: document,
        spec: print10x15Spec,
      );
      expect(report.issuesFor('t0'), isEmpty);
    });

    test('FACE_AT_EDGE runs only when a detector is injected', () {
      final document = singleSlotProject(
        asset('p0', widthPx: 4000, heightPx: 4000),
      );
      final withoutDetector = PreflightProjection.run(
        document: document,
        spec: print10x15Spec,
      );
      expect(withoutDetector.codes, isNot(contains(PreflightCode.faceAtEdge)));

      final withDetector = PreflightProjection.run(
        document: document,
        spec: print10x15Spec,
        faceDetector: const _CornerFaceDetector(),
      );
      final issue = withDetector.issuesFor('main').single;
      expect(issue.code, PreflightCode.faceAtEdge);
      expect(issue.args['edge'], 'left');
    });

    test('acknowledging a blocking report allows the order', () {
      final document = emptySlotsProject(BuiltInTemplates.quad10x15);
      final report = PreflightProjection.run(
        document: document,
        spec: print10x15Spec,
      );
      expect(report.blockingCount, 4);
      expect(report.canOrder, isFalse);
      final acknowledged = report.acknowledge();
      expect(acknowledged.canOrder, isTrue);
      expect(acknowledged.issues.length, report.issues.length);
      expect(report.acknowledged, isFalse, reason: 'must not mutate in place');
    });

    test('report round-trips through JSON', () {
      final report = PreflightProjection.run(
        document: emptySlotsProject(BuiltInTemplates.single10x15),
        spec: print10x15Spec,
      );
      final decoded = PreflightReport.fromJson(report.toJson());
      expect(decoded.isOk, isTrue, reason: '${decoded.failureOrNull}');
      expect(decoded.requireValue.issues.length, report.issues.length);
      expect(decoded.requireValue.blockingCount, report.blockingCount);
    });

    test('clean project produces an empty report', () {
      final document = tenPhotoProject();
      final report = PreflightProjection.run(
        document: document,
        spec: const PrintSpec(widthMm: 100, heightMm: 150),
        assets: document.assets,
        templates: BuiltInTemplates.byId,
      );
      expect(report.isClean, isTrue, reason: '${report.issues}');
      expect(report.canOrder, isTrue);
    });
  });
}

class _CornerFaceDetector implements FaceEdgeDetector {
  const _CornerFaceDetector();

  @override
  List<NormalizedRect> faces(PhotoAssetRef asset, DesignDocument document) =>
      <NormalizedRect>[const NormalizedRect(x: 0.0, y: 0.4, w: 0.1, h: 0.1)];
}
