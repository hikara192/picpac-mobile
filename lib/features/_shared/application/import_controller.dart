import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/photo_format.dart';
import '../../../core/media/photo_importer.dart';
import '../../../core/media/photo_uploader.dart';
import 'design_session.dart';
import 'media_providers.dart';

final class ImportTask {
  const ImportTask({
    required this.localId,
    required this.fileName,
    required this.bytes,
    required this.prepared,
    this.stage = PhotoUploadStage.queued,
    this.progress = 0,
    this.failure,
  });

  final String localId;

  final String fileName;

  final int bytes;

  final PreparedPhoto prepared;

  final PhotoUploadStage stage;

  final double progress;

  final Failure? failure;

  bool get hasFailed => stage == PhotoUploadStage.failed;

  bool get isCompleted => stage == PhotoUploadStage.completed;

  bool get isActive => stage.isActive;

  ImportTask copyWith({
    PhotoUploadStage? stage,
    double? progress,
    Object? failure = _unset,
  }) => ImportTask(
    localId: localId,
    fileName: fileName,
    bytes: bytes,
    prepared: prepared,
    stage: stage ?? this.stage,
    progress: progress ?? this.progress,
    failure: identical(failure, _unset) ? this.failure : failure as Failure?,
  );
}

final class ImportState {
  const ImportState({
    this.tasks = const <ImportTask>[],
    this.rejections = const <PhotoRejection>[],
    this.duplicates = 0,
    this.added = 0,
    this.picking = false,
    this.promotedDesignId,
    this.pickerFailure,
  });

  final List<ImportTask> tasks;

  final List<PhotoRejection> rejections;

  final int duplicates;

  final int added;

  final bool picking;

  final String? promotedDesignId;

  final MediaFailure? pickerFailure;

  bool get isBusy => picking || tasks.any((task) => task.isActive);

  List<ImportTask> get pendingTiles => <ImportTask>[
    for (final task in tasks)
      if (!task.isCompleted) task,
  ];

  int get done =>
      tasks.where((task) => task.stage == PhotoUploadStage.completed).length;

  int get total => tasks.length;

  bool get hasFailures => tasks.any((task) => task.hasFailed);

  bool get hasNotice =>
      tasks.isNotEmpty ||
      rejections.isNotEmpty ||
      pickerFailure != null ||
      duplicates > 0;

  ImportState copyWith({
    List<ImportTask>? tasks,
    List<PhotoRejection>? rejections,
    int? duplicates,
    int? added,
    bool? picking,
    Object? promotedDesignId = _unset,
    Object? pickerFailure = _unset,
  }) => ImportState(
    tasks: tasks ?? this.tasks,
    rejections: rejections ?? this.rejections,
    duplicates: duplicates ?? this.duplicates,
    added: added ?? this.added,
    picking: picking ?? this.picking,
    promotedDesignId: identical(promotedDesignId, _unset)
        ? this.promotedDesignId
        : promotedDesignId as String?,
    pickerFailure: identical(pickerFailure, _unset)
        ? this.pickerFailure
        : pickerFailure as MediaFailure?,
  );
}

final class ImportController extends Notifier<ImportState> {
  ImportController(this.designId);

  final String designId;

  final Set<String> _cancelled = <String>{};

  @override
  ImportState build() => const ImportState();

  Future<void> pickAndImport({int? limit}) async {
    if (state.picking) return;
    state = state.copyWith(picking: true, pickerFailure: null);
    final importer = ref.read(photoImporterProvider);
    final session = ref.read(designSessionProvider(designId)).value;
    final knownHashes =
        session?.document.assets.map((asset) => asset.sha256).toList() ??
        const <String>[];

    final picked = await importer.pickAndPrepare(
      designId: designId,
      knownHashes: knownHashes,
      limit: limit,
    );
    if (!ref.mounted) return;

    switch (picked) {
      case Err<PhotoImportBatch>(:final error):
        state = state.copyWith(
          picking: false,
          pickerFailure: error is MediaFailure ? error : null,
        );
        return;
      case Ok<PhotoImportBatch>(:final value):
        state = state.copyWith(
          picking: false,
          pickerFailure: null,
          rejections: <PhotoRejection>[
            ...state.rejections,
            ...value.rejections,
          ],
          duplicates: state.duplicates + value.duplicates,
        );
        if (value.prepared.isEmpty) return;
        await _uploadAll(photos: value.prepared);
    }
  }

  Future<void> retryFailed() async {
    final pending = <PreparedPhoto>[
      for (final task in state.tasks)
        if (task.hasFailed) task.prepared,
    ];
    if (pending.isEmpty) return;
    await _uploadAll(photos: pending);
  }

  void dismissRejections() {
    if (state.rejections.isEmpty) return;
    state = state.copyWith(rejections: const <PhotoRejection>[]);
  }

  void cancel(String localId) {
    _cancelled.add(localId);
    final tasks = List<ImportTask>.of(state.tasks)
      ..removeWhere((task) => task.localId == localId);
    state = state.copyWith(tasks: tasks);
  }

  Future<void> retry(String localId) async {
    for (final task in state.tasks) {
      if (task.localId != localId || !task.hasFailed) continue;
      await _uploadAll(photos: <PreparedPhoto>[task.prepared]);
      return;
    }
  }

  void resetBatch() {
    state = const ImportState();
  }

  Future<void> _uploadAll({required List<PreparedPhoto> photos}) async {
    final uploader = ref.read(photoUploaderProvider);
    for (final photo in photos) {
      if (!ref.mounted) return;
      if (_cancelled.contains(photo.sha256)) continue;
      _upsert(
        ImportTask(
          localId: photo.sha256,
          fileName: photo.fileName,
          bytes: photo.bytes,
          prepared: photo,
          stage: PhotoUploadStage.presigning,
        ),
      );
      final result = await uploader.upload(
        photo,
        onStage: (stage) => _update(photo.sha256, stage: stage),
        onProgress: (progress) => _update(photo.sha256, progress: progress),
      );
      if (!ref.mounted) return;
      if (_cancelled.contains(photo.sha256)) continue;
      switch (result) {
        case Ok<CompletedUpload>(:final value):
          final assetId = 'photo_${value.sha256.substring(0, 12)}';
          final session = ref.read(designSessionProvider(designId)).value;
          final present = session?.document.assetById(assetId) != null;
          if (!present) {
            ref.read(designSessionProvider(designId).notifier).addPhotos(
              <PhotoAsset>[photo.toAsset(assetId)],
            );
            state = state.copyWith(added: state.added + 1);
          }
          _update(photo.sha256, stage: PhotoUploadStage.completed);
          await _promoteIfLocal();
        case Err<CompletedUpload>(:final error):
          _update(photo.sha256, stage: PhotoUploadStage.failed, failure: error);
      }
    }
  }

  Future<void> _promoteIfLocal() async {
    final session = ref.read(designSessionProvider(designId)).value;
    if (session == null || !session.localOnly) return;
    final result = await ref
        .read(designSessionProvider(designId).notifier)
        .promoteToServer();
    if (!ref.mounted) return;
    if (result case Ok<String>(:final value)) {
      state = state.copyWith(promotedDesignId: value);
    }
  }

  void _upsert(ImportTask task) {
    final tasks = List<ImportTask>.of(state.tasks);
    final index = tasks.indexWhere((item) => item.localId == task.localId);
    if (index >= 0) {
      tasks[index] = task;
    } else {
      tasks.add(task);
    }
    state = state.copyWith(tasks: tasks);
  }

  void _update(
    String localId, {
    PhotoUploadStage? stage,
    double? progress,
    Failure? failure,
  }) {
    if (!ref.mounted) return;
    final tasks = List<ImportTask>.of(state.tasks);
    final index = tasks.indexWhere((item) => item.localId == localId);
    if (index < 0) return;
    tasks[index] = tasks[index].copyWith(
      stage: stage,
      progress: progress,
      failure: failure,
    );
    state = state.copyWith(tasks: tasks);
  }
}

final importControllerProvider =
    NotifierProvider.family<ImportController, ImportState, String>(
      ImportController.new,
    );

const Object _unset = Object();
