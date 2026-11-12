import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/analytics.dart';
import '../../../core/session/guest_work.dart';
import '../../../core/session/session_service.dart';
import 'async_retry.dart';
import 'design_format.dart';
import 'media_providers.dart';
import 'photo_enhance.dart';
import 'reset_to_imported.dart';

const String kLocalDesignPrefix = 'local_';

enum DesignSyncStatus {
  synced,

  saving,

  pending,

  offline,

  conflict,

  failed;

  bool get isUnsaved =>
      this == pending || this == offline || this == saving || this == conflict;
}

final class DesignSessionState {
  const DesignSessionState({
    required this.designId,
    required this.document,
    required this.format,
    required this.template,
    required this.serverRevision,
    this.serverId,
    this.sync = DesignSyncStatus.synced,
    this.restoredFromCache = false,
    this.localCopy = false,
    this.localOnly = false,
    this.syncFailure,
    this.canUndo = false,
    this.canRedo = false,
    this.selectedSpreadId,
    this.selectedSlotId,
    this.nextUndoLabel,
  });

  final String designId;

  final DesignDocument document;

  final ProductFormat format;

  final PrintTemplate template;

  final int? serverRevision;

  final String? serverId;

  final DesignSyncStatus sync;

  final bool restoredFromCache;

  final bool localCopy;

  final bool localOnly;

  final Failure? syncFailure;

  final bool canUndo;

  final bool canRedo;

  final String? selectedSpreadId;

  final String? selectedSlotId;

  final String? nextUndoLabel;

  PrintSpec get spec => format.toPrintSpec();

  Map<String, PrintTemplate> get templates => format.templateMap();

  PrintTemplate templateOf(Spread spread) =>
      templates[spread.templateId] ?? template;

  List<Spread> get spreads => document.spreads;

  int get sheetCount => document.spreads.length;

  String get templateId => template.id;

  Spread? spreadById(String? spreadId) =>
      spreadId == null ? null : document.spreadById(spreadId);

  Slot? get selectedSlot {
    final spreadId = selectedSpreadId;
    final slotId = selectedSlotId;
    if (spreadId == null || slotId == null) return null;
    return document.slotById(spreadId, slotId);
  }

  String? get selectedPhotoId => selectedSlot?.photoId;

  int? get photoLimit {
    if (format.maxPhotos <= 0) return null;
    if (format.maxSpreads > 0) return format.maxPhotos;
    return null;
  }

  int? get remainingPhotos {
    final limit = photoLimit;
    if (limit == null) return null;
    return math.max(0, limit - document.photoCount);
  }

  bool get isAtPhotoLimit {
    final remaining = remainingPhotos;
    return remaining != null && remaining <= 0;
  }

  int get missingPhotos => math.max(0, format.minPhotos - document.photoCount);

  int get minSheets {
    if (format.minPhotos <= 0) return 1;
    final perSheet = math.max(1, template.slots.length);
    return math.max(1, (format.minPhotos / perSheet).ceil());
  }

  DesignSessionState copyWith({
    DesignDocument? document,
    ProductFormat? format,
    PrintTemplate? template,
    Object? serverRevision = _unset,
    Object? serverId = _unset,
    DesignSyncStatus? sync,
    bool? restoredFromCache,
    bool? localCopy,
    bool? localOnly,
    Object? syncFailure = _unset,
    bool? canUndo,
    bool? canRedo,
    Object? selectedSpreadId = _unset,
    Object? selectedSlotId = _unset,
    Object? nextUndoLabel = _unset,
  }) => DesignSessionState(
    designId: designId,
    document: document ?? this.document,
    format: format ?? this.format,
    template: template ?? this.template,
    serverRevision: identical(serverRevision, _unset)
        ? this.serverRevision
        : serverRevision as int?,
    serverId: identical(serverId, _unset) ? this.serverId : serverId as String?,
    sync: sync ?? this.sync,
    restoredFromCache: restoredFromCache ?? this.restoredFromCache,
    localCopy: localCopy ?? this.localCopy,
    localOnly: localOnly ?? this.localOnly,
    syncFailure: identical(syncFailure, _unset)
        ? this.syncFailure
        : syncFailure as Failure?,
    canUndo: canUndo ?? this.canUndo,
    canRedo: canRedo ?? this.canRedo,
    selectedSpreadId: identical(selectedSpreadId, _unset)
        ? this.selectedSpreadId
        : selectedSpreadId as String?,
    selectedSlotId: identical(selectedSlotId, _unset)
        ? this.selectedSlotId
        : selectedSlotId as String?,
    nextUndoLabel: identical(nextUndoLabel, _unset)
        ? this.nextUndoLabel
        : nextUndoLabel as String?,
  );
}

final class EnhanceOutcome {
  const EnhanceOutcome({
    required this.applied,
    required this.alreadyEnhanced,
    this.unanalysed = 0,
    this.failed = false,
  });

  final int applied;

  final int alreadyEnhanced;

  final int unanalysed;

  final bool failed;

  bool get isEmpty => applied == 0;
}

final class DesignSessionController extends AsyncNotifier<DesignSessionState> {
  DesignSessionController(this.designId);

  final String designId;

  static const Duration syncDebounce = Duration(seconds: 2);

  UndoStack? _stack;
  Timer? _syncTimer;
  bool _syncing = false;
  bool _disposed = false;

  String? _promotedId;

  @override
  Future<DesignSessionState> build() async {
    final api = ref.watch(apiPortProvider);
    final session = ref.watch(sessionServiceProvider);
    final drafts = ref.watch(draftStoreProvider);
    final formats = ref.watch(designFormatRepositoryProvider);
    final analytics = ref.watch(analyticsProvider);

    ref.onDispose(_dispose);

    final localOnly = designId.startsWith(kLocalDesignPrefix);
    DesignDocument document;
    int? serverRevision;
    var restored = false;
    var localCopy = false;
    Failure? loadFailure;
    if (localOnly) {
      final local = await drafts.load(designId);
      if (local == null) {
        throw ApiFailure(
          code: ApiErrorCode.notFound,
          message: 'no local snapshot for design $designId',
        );
      }
      document = local;
      restored = true;
    } else {
      final remote = await session.ensureSession(() => api.design(designId));
      switch (remote) {
        case Ok<DesignDto>(:final value):
          document = value.document;
          serverRevision = value.revision;
        case Err<DesignDto>(:final error):
          if (!_canRestore(error)) throw error;
          final local = await drafts.load(designId);
          if (local == null) throw error;
          document = local;
          restored = true;
          localCopy = error.code == ApiErrorCode.notFound;
          loadFailure = error;
          analytics.track(AnalyticsEvent.draftRestored, <String, Object?>{
            'photos': local.photoCount,
            'revision': local.revision,
          });
      }
    }

    final snapshot = await formats.load(
      designId: designId,
      productId: document.product.id,
      formatId: document.product.formatId,
    );
    final format = switch (snapshot) {
      Ok<FormatSnapshot>(:final value) => value.format,
      Err<FormatSnapshot>(:final error) => throw error,
    };
    final fromCache = snapshot.valueOrNull?.fromCache ?? false;

    final template = _defaultTemplate(format);
    final normalized = _keepOrLayout(document, format, template);
    final stack = UndoStack(document: normalized);
    stack.addListener(_onDocumentChanged);
    _stack = stack;

    final state = DesignSessionState(
      designId: designId,
      document: stack.document,
      format: format,
      template: template,
      serverRevision: serverRevision,
      serverId: localOnly ? null : designId,
      sync: localOnly
          ? DesignSyncStatus.synced
          : restored || fromCache
          ? DesignSyncStatus.offline
          : DesignSyncStatus.synced,
      restoredFromCache: restored,
      localCopy: localCopy,
      localOnly: localOnly,
      syncFailure: loadFailure,
      selectedSpreadId: stack.document.spreads.isEmpty
          ? null
          : stack.document.spreads.first.id,
    );

    final changed =
        jsonEncode(stack.document.toJson()) != jsonEncode(document.toJson());
    if (changed) {
      _persist(stack.document);
      if (serverRevision != null && !localOnly) _scheduleSync();
    }
    return state;
  }

  CommandResult execute(DesignCommand command) {
    final stack = _stack;
    if (stack == null) {
      return const CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidState,
          message: 'the session is not loaded yet',
        ),
      );
    }
    return stack.execute(command);
  }

  void beginGesture([String label = 'gesture']) => _stack?.beginGroup(label);

  void endGesture() {
    final stack = _stack;
    if (stack == null || !stack.isGrouping) return;
    stack.endGroup();
  }

  bool undo() => _stack?.undo() ?? false;

  bool redo() => _stack?.redo() ?? false;

  CommandResult addPhotos(List<PhotoAsset> photos) {
    final state = this.state.value;
    if (state == null) {
      return const CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidState,
          message: 'the session is not loaded yet',
        ),
      );
    }
    if (photos.isEmpty) return const CommandOk();
    final additions = <DesignCommand>[
      for (final photo in photos) AddPhoto(photo: photo),
      _layoutCommand(state),
    ];
    return execute(CompositeCommand(additions, label: 'importPhotos'));
  }

  CommandResult removePhoto(String photoId) {
    final state = this.state.value;
    if (state == null) {
      return const CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidState,
          message: 'the session is not loaded yet',
        ),
      );
    }
    return execute(
      CompositeCommand(<DesignCommand>[
        RemovePhoto(photoId: photoId),
        _layoutCommand(state),
      ], label: 'removePhoto'),
    );
  }

  CommandResult reorderPhotos(int fromIndex, int toIndex) {
    final state = this.state.value;
    if (state == null) {
      return const CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidState,
          message: 'the session is not loaded yet',
        ),
      );
    }
    if (fromIndex == toIndex) return const CommandOk();
    return execute(
      CompositeCommand(<DesignCommand>[
        ReorderPhotos(fromIndex: fromIndex, toIndex: toIndex),
        _layoutCommand(state),
      ], label: 'reorderPhotos'),
    );
  }

  EnhanceOutcome enhanceAll(Map<String, PhotoAnalysis> analyses) {
    final state = this.state.value;
    if (state == null) {
      return const EnhanceOutcome(applied: 0, alreadyEnhanced: 0, failed: true);
    }
    final plan = planEnhanceAll(state.document, analyses);
    if (plan.isEmpty) {
      return EnhanceOutcome(
        applied: 0,
        alreadyEnhanced: plan.alreadyEnhanced,
        unanalysed: plan.unanalysed,
      );
    }
    final result = execute(
      CompositeCommand(plan.commands, label: 'enhanceAll'),
    );
    return EnhanceOutcome(
      applied: result is CommandFailed ? 0 : plan.applied,
      alreadyEnhanced: plan.alreadyEnhanced,
      unanalysed: plan.unanalysed,
      failed: result is CommandFailed,
    );
  }

  CommandResult resetToImported() {
    final state = this.state.value;
    if (state == null) {
      return const CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidState,
          message: 'the session is not loaded yet',
        ),
      );
    }
    return execute(
      ResetToImported(template: state.template, minSheets: _minSheets(state)),
    );
  }

  Result<PatchResolution> applyAiPatch(DesignPatch patch) {
    final state = this.state.value;
    if (state == null) {
      return const Err<PatchResolution>(
        PatchRejected(
          reason: PatchErrorCode.sessionNotReady,
          message: 'the session is not loaded yet',
        ),
      );
    }
    final resolved = PatchApplier.resolve(
      state.document,
      patch,
      templates: state.templates,
      spec: state.spec,
    );
    return switch (resolved) {
      Ok<PatchResolution>(:final value) => switch (execute(value.command)) {
        CommandFailed(:final error) => Err<PatchResolution>(
          PatchRejected(
            reason: PatchErrorCode.commandRejected,
            message: error.message,
            details: <String, Object?>{'commandCode': error.code.wire},
          ),
        ),
        CommandOk() => Ok<PatchResolution>(value),
      },
      Err<PatchResolution>(:final error) => Err<PatchResolution>(error),
    };
  }

  void selectSlot(String? spreadId, String? slotId) {
    final state = this.state.value;
    if (state == null) return;
    if (state.selectedSpreadId == spreadId && state.selectedSlotId == slotId) {
      return;
    }
    this.state = AsyncData<DesignSessionState>(
      state.copyWith(selectedSpreadId: spreadId, selectedSlotId: slotId),
    );
  }

  void selectSpread(String spreadId) {
    final state = this.state.value;
    if (state == null) return;
    this.state = AsyncData<DesignSessionState>(
      state.copyWith(selectedSpreadId: spreadId),
    );
  }

  Future<void> flush() async {
    try {
      await future;
    } on Object {
      return;
    }
    await ref.read(draftStoreProvider).flush();
    await syncNow();
  }

  Future<void> syncNow() async {
    _syncTimer?.cancel();
    await _sync();
  }

  Future<Failure?> loadServerVersion() async {
    final state = this.state.value;
    final stack = _stack;
    if (state == null || stack == null) return null;
    final api = ref.read(apiPortProvider);
    final session = ref.read(sessionServiceProvider);
    final result = await session.ensureSession(() => api.design(designId));
    if (result case Err<DesignDto>(:final error)) return error;
    final dto = (result as Ok<DesignDto>).value;
    final normalized = _keepOrLayout(
      dto.document,
      state.format,
      state.template,
    );
    stack.reset(normalized);
    this.state = AsyncData<DesignSessionState>(
      state.copyWith(
        document: stack.document,
        serverRevision: dto.revision,
        sync: DesignSyncStatus.synced,
        syncFailure: null,
        canUndo: false,
        canRedo: false,
        selectedSpreadId: stack.document.spreads.isEmpty
            ? null
            : stack.document.spreads.first.id,
        selectedSlotId: null,
      ),
    );
    await ref
        .read(draftStoreProvider)
        .saveNow(
          stack.document,
          designId: designId,
          productId: stack.document.product.id,
        );
    return null;
  }

  Future<Result<String>> promoteToServer() async {
    final state = this.state.value;
    final stack = _stack;
    if (state == null || stack == null) {
      return const Err<String>(
        ApiFailure(
          code: ApiErrorCode.networkUnavailable,
          message: 'the session is not loaded yet',
        ),
      );
    }
    if (!state.localOnly) return Ok<String>(state.designId);

    final api = ref.read(apiPortProvider);
    final session = ref.read(sessionServiceProvider);
    final document = stack.document.copyWith(revision: 0);
    final created = await session.ensureSession(
      () => api.createDesign(document),
    );
    final DesignDto dto;
    switch (created) {
      case Ok<DesignDto>(:final value):
        dto = value;
      case Err<DesignDto>(:final error):
        return Err<String>(error);
    }

    final assets = ref.read(designAssetCacheProvider);
    for (final asset in stack.document.assets) {
      final source = await assets.fileFor(designId, asset.sha256);
      if (source == null) continue;
      await assets.store(
        designId: dto.id,
        sha256: asset.sha256,
        source: source,
      );
    }
    final drafts = ref.read(draftStoreProvider);
    try {
      await drafts.saveNow(
        stack.document,
        designId: dto.id,
        productId: stack.document.product.id,
      );
    } on Object {
    }
    ref
        .read(guestWorkProvider.notifier)
        .rememberDesign(dto.id, role: session.role);
    _promotedId = dto.id;
    this.state = AsyncData<DesignSessionState>(
      state.copyWith(
        document: stack.document,
        serverRevision: dto.revision,
        serverId: dto.id,
        localOnly: false,
        localCopy: false,
        restoredFromCache: false,
        sync: DesignSyncStatus.synced,
        syncFailure: null,
      ),
    );
    return Ok<String>(dto.id);
  }

  Future<Failure?> keepLocalVersion() async {
    final state = this.state.value;
    if (state == null) return null;
    final api = ref.read(apiPortProvider);
    final session = ref.read(sessionServiceProvider);
    final current = await session.ensureSession(() => api.design(designId));
    if (current case Err<DesignDto>(:final error)) return error;
    final revision = (current as Ok<DesignDto>).value.revision;
    this.state = AsyncData<DesignSessionState>(
      state.copyWith(
        serverRevision: revision,
        sync: DesignSyncStatus.saving,
        syncFailure: null,
      ),
    );
    await _sync();
    final after = this.state.value;
    return after != null && after.sync == DesignSyncStatus.synced
        ? null
        : after?.syncFailure;
  }

  Future<void> discardLocalSnapshot() async {
    if (!designId.startsWith(kLocalDesignPrefix)) return;
    try {
      await ref.read(draftStoreProvider).delete(designId);
      await ref.read(designAssetCacheProvider).clear(designId);
    } on Object {
    }
  }


  AutoLayoutSheets _layoutCommand(DesignSessionState state) =>
      AutoLayoutSheets(template: state.template, minSheets: _minSheets(state));

  int _minSheets(DesignSessionState state) => state.minSheets;

  DesignDocument _keepOrLayout(
    DesignDocument document,
    ProductFormat format,
    PrintTemplate template,
  ) {
    if (document.spreads.isNotEmpty) return document;
    return _layoutOf(document, format, template);
  }

  DesignDocument _layoutOf(
    DesignDocument document,
    ProductFormat format,
    PrintTemplate template,
  ) {
    final minSheets = format.minPhotos <= 0
        ? 1
        : (format.minPhotos / math.max(1, template.slots.length)).ceil();
    return AutoLayoutSheets(
      template: template,
      minSheets: math.max(1, minSheets),
    ).applyCore(document);
  }

  PrintTemplate _defaultTemplate(ProductFormat format) {
    for (final template in format.templates) {
      if (template.kind == TemplateKind.print ||
          template.kind == TemplateKind.spread ||
          template.kind == TemplateKind.page) {
        return template.toPrintTemplate();
      }
    }
    if (format.templates.isNotEmpty) {
      return format.templates.first.toPrintTemplate();
    }
    return BuiltInTemplates.single10x15;
  }

  void _onDocumentChanged() {
    if (_disposed) return;
    final state = this.state.value;
    final stack = _stack;
    if (state == null || stack == null) return;
    final document = stack.document;
    this.state = AsyncData<DesignSessionState>(
      state.copyWith(
        document: document,
        canUndo: stack.canUndo,
        canRedo: stack.canRedo,
        nextUndoLabel: stack.nextUndoLabel,
        sync: state.localOnly
            ? DesignSyncStatus.synced
            : state.sync == DesignSyncStatus.conflict
            ? DesignSyncStatus.conflict
            : DesignSyncStatus.pending,
        syncFailure: null,
      ),
    );
    _persist(document);
    if (!state.localOnly && state.sync != DesignSyncStatus.conflict) {
      _scheduleSync();
    }
  }

  void _persist(DesignDocument document) {
    ref
        .read(draftStoreProvider)
        .scheduleSave(
          document,
          designId: _promotedId ?? designId,
          productId: document.product.id,
        );
  }

  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(syncDebounce, () => unawaited(_sync()));
  }

  Future<void> _sync() async {
    if (_disposed) return;
    if (_syncing) return;
    final state = this.state.value;
    final stack = _stack;
    if (state == null || stack == null) return;
    if (state.localOnly) return;
    if (state.sync == DesignSyncStatus.conflict) return;

    _syncing = true;
    final api = ref.read(apiPortProvider);
    final session = ref.read(sessionServiceProvider);
    final apiId = _promotedId ?? designId;
    this.state = AsyncData<DesignSessionState>(
      state.copyWith(sync: DesignSyncStatus.saving, syncFailure: null),
    );
    try {
      var revision = this.state.value?.serverRevision;
      if (revision == null) {
        final current = await session.ensureSession(() => api.design(apiId));
        if (current case Err<DesignDto>(:final error)) {
          _failSync(error);
          return;
        }
        revision = (current as Ok<DesignDto>).value.revision;
      }
      final document = stack.document;
      final result = await session.ensureSession(
        () => api.putDesign(apiId, document, ifMatchRevision: revision!),
      );
      if (_disposed) return;
      final latest = this.state.value;
      if (latest == null) return;
      switch (result) {
        case Ok<DesignDto>(:final value):
          final unchanged = identical(stack.document, document);
          this.state = AsyncData<DesignSessionState>(
            latest.copyWith(
              serverRevision: value.revision,
              sync: unchanged
                  ? DesignSyncStatus.synced
                  : DesignSyncStatus.pending,
              syncFailure: null,
            ),
          );
          if (!unchanged) _scheduleSync();
        case Err<DesignDto>(:final error):
          _failSync(error);
      }
    } finally {
      _syncing = false;
    }
  }

  void _failSync(Failure failure) {
    if (_disposed) return;
    final state = this.state.value;
    if (state == null) return;
    final conflict = failure.code == ApiErrorCode.conflictRevision;
    final offline = _isOffline(failure);
    this.state = AsyncData<DesignSessionState>(
      state.copyWith(
        sync: conflict
            ? DesignSyncStatus.conflict
            : offline
            ? DesignSyncStatus.offline
            : DesignSyncStatus.failed,
        syncFailure: failure,
      ),
    );
    ref.read(loggerProvider).warning('design.sync.failed', <String, Object?>{
      'code': failure.code,
    });
  }

  bool _isOffline(Failure failure) =>
      failure.code == ApiErrorCode.networkUnavailable ||
      failure.code == ApiErrorCode.timeout;

  bool _canRestore(Failure failure) =>
      _isOffline(failure) || failure.code == ApiErrorCode.notFound;

  void _dispose() {
    _disposed = true;
    _syncTimer?.cancel();
    _syncTimer = null;
    _stack?.removeListener(_onDocumentChanged);
    _stack = null;
  }
}

final designSessionProvider =
    AsyncNotifierProvider.family<
      DesignSessionController,
      DesignSessionState,
      String
    >(DesignSessionController.new, retry: noProviderRetry);

const Object _unset = Object();
