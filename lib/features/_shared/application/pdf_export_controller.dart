import 'dart:typed_data';

import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/analytics.dart';
import '../../../core/export/pdf_share.dart';
import '../../../core/media/photo_format.dart';
import '../../../core/presentation/export_messages.dart';
import '../../../render/asset_image_store.dart';
import '../../../render/pdf_exporter.dart';
import 'async_retry.dart';
import 'design_session.dart';
import 'media_providers.dart';

final class ExportFailure implements Failure {
  const ExportFailure({
    required this.code,
    required this.message,
    this.args = const <String, Object?>{},
  });

  factory ExportFailure.documentUnavailable() => const ExportFailure(
    code: ExportErrorCode.documentUnavailable,
    message: 'the project is not loaded',
  );

  factory ExportFailure.nothingToExport() => const ExportFailure(
    code: ExportErrorCode.nothingToExport,
    message: 'the document has no sheets',
  );

  factory ExportFailure.renderFailed({String? message}) => ExportFailure(
    code: ExportErrorCode.renderFailed,
    message: message ?? 'the pdf could not be rendered',
  );

  factory ExportFailure.shareFailed({String? message}) => ExportFailure(
    code: ExportErrorCode.shareFailed,
    message: message ?? 'the share sheet could not be opened',
  );

  @override
  final String code;

  @override
  final String message;

  @override
  final Map<String, Object?> args;
}

enum PdfExportPhase {
  idle,

  rendering,

  sharing,
}

final class PdfExportState {
  const PdfExportState({
    this.phase = PdfExportPhase.idle,
    this.done = 0,
    this.total = 0,
    this.bytes = 0,
  });

  static const PdfExportState idle = PdfExportState();

  final PdfExportPhase phase;

  final int done;

  final int total;

  final int bytes;

  bool get isBusy => phase != PdfExportPhase.idle;

  double get progress => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);

  PdfExportState copyWith({
    PdfExportPhase? phase,
    int? done,
    int? total,
    int? bytes,
  }) => PdfExportState(
    phase: phase ?? this.phase,
    done: done ?? this.done,
    total: total ?? this.total,
    bytes: bytes ?? this.bytes,
  );
}

final class PdfExportController extends AsyncNotifier<PdfExportState> {
  PdfExportController(this.designId);

  final String designId;

  @override
  Future<PdfExportState> build() async => PdfExportState.idle;

  Future<Failure?> share() async {
    final current = state.value ?? PdfExportState.idle;
    if (current.isBusy) return null;

    final session = ref.read(designSessionProvider(designId)).value;
    if (session == null) return ExportFailure.documentUnavailable();
    if (session.document.spreads.isEmpty) {
      return ExportFailure.nothingToExport();
    }

    final analytics = ref.read(analyticsProvider);
    final logger = ref.read(loggerProvider);
    final images = AssetImageStore(
      cache: ref.read(designAssetCacheProvider),
      designId: designId,
      maxSide: PhotoFormats.previewMaxSide,
    );
    final total = session.document.spreads.length;
    state = AsyncData<PdfExportState>(
      PdfExportState(phase: PdfExportPhase.rendering, total: total),
    );

    try {
      final Uint8List bytes;
      try {
        bytes = await PdfExporter.exportSheets(
          document: session.document,
          spec: session.spec,
          images: images,
          templates: session.templates,
          onProgress: (done, pages) {
            if (!ref.mounted) return;
            state = AsyncData<PdfExportState>(
              PdfExportState(
                phase: PdfExportPhase.rendering,
                done: done,
                total: pages,
              ),
            );
          },
        );
      } on Object catch (error) {
        logger.warning('pdf.export.render.failed', <String, Object?>{
          'designId': designId,
          'type': error.runtimeType.toString(),
        });
        return ExportFailure.renderFailed(
          message: error.runtimeType.toString(),
        );
      }
      if (!ref.mounted) return null;
      state = AsyncData<PdfExportState>(
        PdfExportState(
          phase: PdfExportPhase.sharing,
          done: total,
          total: total,
          bytes: bytes.length,
        ),
      );

      final ShareOutcome outcome;
      try {
        outcome = await ref
            .read(pdfShareProvider)
            .sharePdf(
              bytes: bytes,
              fileName: 'picpac-$designId.pdf',
              subject: 'PicPac',
            );
      } on Object catch (error) {
        logger.warning('pdf.export.share.failed', <String, Object?>{
          'designId': designId,
          'type': error.runtimeType.toString(),
        });
        return ExportFailure.shareFailed(message: error.runtimeType.toString());
      }
      analytics.track(AnalyticsEvent.pdfExported, <String, Object?>{
        'sheets': total,
        'bytes': bytes.length,
        'outcome': outcome.name,
      });
      return null;
    } finally {
      if (ref.mounted) state = AsyncData<PdfExportState>(PdfExportState.idle);
      images.dispose();
    }
  }
}

final pdfExportProvider =
    AsyncNotifierProvider.family<PdfExportController, PdfExportState, String>(
      PdfExportController.new,
      retry: noProviderRetry,
    );

final Provider<PdfSharePort> pdfShareProvider = Provider<PdfSharePort>(
  (ref) => const SystemPdfShare(),
);
