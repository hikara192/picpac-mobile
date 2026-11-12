import 'dart:math' as math;

import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/session/session_service.dart';
import '../../../core/storage/draft_store.dart';
import '../../_shared/application/async_retry.dart';
import '../../_shared/application/design_session.dart';

enum TemplateApplyProblem {
  notSupported,

  notEnoughPhotos,

  formatUnavailable,

  commandRejected,
}

final class TemplateApplyOutcome {
  const TemplateApplyOutcome._({
    this.designId,
    this.problem,
    this.failure,
    this.slotCount = 0,
    this.photoCount = 0,
  });

  const TemplateApplyOutcome.applied(String designId)
    : this._(designId: designId);

  const TemplateApplyOutcome.blocked(
    TemplateApplyProblem problem, {
    int slotCount = 0,
    int photoCount = 0,
  }) : this._(problem: problem, slotCount: slotCount, photoCount: photoCount);

  const TemplateApplyOutcome.failed(Failure failure) : this._(failure: failure);

  final String? designId;

  final TemplateApplyProblem? problem;

  final Failure? failure;

  final int slotCount;

  final int photoCount;

  bool get isApplied => designId != null;
}

final class TemplateApplier {
  const TemplateApplier(this._ref);

  final Ref _ref;

  Future<TemplateApplyOutcome> apply(InspirationDetail detail) async {
    if (!detail.isSupported) {
      return const TemplateApplyOutcome.blocked(
        TemplateApplyProblem.notSupported,
      );
    }
    final drafts = _ref.read(draftStoreProvider);
    final designId = await _recentDraftFor(detail, drafts);
    if (designId != null) {
      final outcome = await _applyToDraft(designId, detail);
      final failure = outcome.failure;
      final recoverable =
          failure != null &&
          (failure.code == ApiErrorCode.forbidden ||
              failure.code == ApiErrorCode.notFound);
      if (!recoverable) return outcome;
    }
    return _createProject(detail);
  }

  Future<String?> _recentDraftFor(
    InspirationDetail detail,
    DraftStore drafts,
  ) async {
    for (final row in await drafts.list()) {
      final mayFit = detail.supports.any(
        (support) => support.productId == row.productId,
      );
      if (!mayFit) continue;
      final document = await drafts.load(row.designId);
      if (document == null) continue;
      final fits = detail.supports.any(
        (support) =>
            support.productId == document.product.id &&
            support.formatId == document.product.formatId,
      );
      if (fits) return row.designId;
    }
    return null;
  }

  Future<TemplateApplyOutcome> _applyToDraft(
    String designId,
    InspirationDetail detail,
  ) async {
    final provider = designSessionProvider(designId);
    final DesignSessionState session;
    try {
      session = await _ref.read(provider.future);
    } on Object catch (error) {
      return TemplateApplyOutcome.failed(failureOr(error));
    }
    final template = session.templates[detail.item.templateId];
    if (template == null) {
      return const TemplateApplyOutcome.blocked(
        TemplateApplyProblem.notSupported,
      );
    }
    final photos = session.document.photoCount;
    if (photos < template.slotCount) {
      return TemplateApplyOutcome.blocked(
        TemplateApplyProblem.notEnoughPhotos,
        slotCount: template.slotCount,
        photoCount: photos,
      );
    }
    final spreadId =
        session.selectedSpreadId ??
        (session.spreads.isEmpty ? null : session.spreads.first.id);
    if (spreadId == null) {
      return const TemplateApplyOutcome.blocked(
        TemplateApplyProblem.commandRejected,
      );
    }
    final sheet = session.spreadById(spreadId);
    if (sheet == null) {
      return const TemplateApplyOutcome.blocked(
        TemplateApplyProblem.commandRejected,
      );
    }
    final existing = <String, String?>{
      for (final slot in sheet.slots) slot.id: slot.photoId,
    };
    final keptPhotos = <String>{
      for (final templateSlot in template.slots) ?existing[templateSlot.id],
    };
    final sheetPhotos = <String>[for (final slot in sheet.slots) ?slot.photoId];
    final placedElsewhere = <String>{
      for (final spread in session.spreads)
        if (spread.id != spreadId)
          for (final slot in spread.slots) ?slot.photoId,
    };
    final pool = <String>[
      for (final photoId in sheetPhotos)
        if (!keptPhotos.contains(photoId)) photoId,
      for (final asset in session.document.assets)
        if (!placedElsewhere.contains(asset.id) &&
            !sheetPhotos.contains(asset.id))
          asset.id,
    ];
    final newSlots = <String>[
      for (final templateSlot in template.slots)
        if (!existing.containsKey(templateSlot.id)) templateSlot.id,
    ];
    final commands = <DesignCommand>[
      SetLayout(spreadId: spreadId, template: template),
      for (var i = 0; i < newSlots.length && i < pool.length; i++)
        AssignPhoto(spreadId: spreadId, slotId: newSlots[i], photoId: pool[i]),
    ];
    final result = _ref
        .read(provider.notifier)
        .execute(
          commands.length == 1
              ? commands.single
              : CompositeCommand(commands, label: 'applyIdea'),
        );
    if (result is CommandFailed) {
      return const TemplateApplyOutcome.blocked(
        TemplateApplyProblem.commandRejected,
      );
    }
    await _ref.read(provider.notifier).flush();
    return TemplateApplyOutcome.applied(designId);
  }

  Future<TemplateApplyOutcome> _createProject(InspirationDetail detail) async {
    final api = _ref.read(apiPortProvider);
    final sessionService = _ref.read(sessionServiceProvider);
    final drafts = _ref.read(draftStoreProvider);

    final catalogResult = await sessionService.ensurePublic(api.catalog);
    final catalog = catalogResult.valueOrNull;
    if (catalog == null) {
      return TemplateApplyOutcome.failed(
        catalogResult.failureOrNull ??
            const ApiFailure(
              code: ApiErrorCode.serverError,
              message: 'the catalogue is unavailable',
            ),
      );
    }
    final target = _targetOf(detail, catalog);
    if (target == null) {
      return const TemplateApplyOutcome.blocked(
        TemplateApplyProblem.formatUnavailable,
      );
    }

    final created = await sessionService.ensureSession(
      () => api.createDesign(
        DesignDocument.start(
          product: DocumentProduct(
            id: target.product.id,
            formatId: target.format.id,
          ),
        ),
      ),
    );
    final dto = created.valueOrNull;
    if (dto == null) {
      return TemplateApplyOutcome.failed(
        created.failureOrNull ??
            const ApiFailure(
              code: ApiErrorCode.serverError,
              message: 'the project could not be created',
            ),
      );
    }
    try {
      await drafts.saveNow(
        dto.document,
        designId: dto.id,
        productId: target.product.id,
      );
    } on Object {
    }

    final provider = designSessionProvider(dto.id);
    final DesignSessionState session;
    try {
      session = await _ref.read(provider.future);
    } on Object catch (error) {
      return TemplateApplyOutcome.failed(failureOr(error));
    }
    final template = session.templates[detail.item.templateId];
    if (template == null) {
      return const TemplateApplyOutcome.blocked(
        TemplateApplyProblem.notSupported,
      );
    }
    final perSheet = math.max(1, template.slotCount);
    final minimum = math.max(
      1,
      math.max(
        target.format.minSpreads,
        (target.format.minPhotos / perSheet).ceil(),
      ),
    );
    final result = _ref
        .read(provider.notifier)
        .execute(AutoLayoutSheets(template: template, minSheets: minimum));
    if (result is CommandFailed) {
      return const TemplateApplyOutcome.blocked(
        TemplateApplyProblem.commandRejected,
      );
    }
    await _ref.read(provider.notifier).flush();
    return TemplateApplyOutcome.applied(dto.id);
  }

  ({Product product, ProductFormat format})? _targetOf(
    InspirationDetail detail,
    CatalogResponse catalog,
  ) {
    for (final support in detail.supports) {
      for (final product in catalog.products) {
        if (product.id != support.productId) continue;
        for (final format in product.formats) {
          if (format.id == support.formatId) {
            return (product: product, format: format);
          }
        }
      }
    }
    return null;
  }
}

final Provider<TemplateApplier> templateApplierProvider =
    Provider<TemplateApplier>((ref) => TemplateApplier(ref));
