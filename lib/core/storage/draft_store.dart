import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import 'package:api_contract/api_contract.dart';

import 'app_database.dart';

final class DraftStore {
  DraftStore({
    required this._database,
    required this._rootDirectory,
    this._debounce = const Duration(milliseconds: 500),
    this._keepRevisions = 5,
  });

  final AppDatabase _database;
  final Future<Directory> Function() _rootDirectory;
  final Duration _debounce;
  final int _keepRevisions;

  final Map<String, Timer> _timers = <String, Timer>{};
  final Map<String, _PendingSave> _pending = <String, _PendingSave>{};

  final Map<String, Future<void>> _queues = <String, Future<void>>{};
  bool _disposed = false;

  bool get isDisposed => _disposed;

  bool isWriting(String designId) => _queues.containsKey(designId);

  Future<void> saveNow(
    DesignDocument document, {
    required String designId,
    required String productId,
    String title = '',
  }) {
    if (_disposed) return Future<void>.value();
    return _enqueue(
      designId,
      () => _write(
        document,
        designId: designId,
        productId: productId,
        title: title,
      ),
    );
  }

  Future<void> _enqueue(String designId, Future<void> Function() write) {
    final previous = _queues[designId] ?? Future<void>.value();
    final completer = Completer<void>();
    final chained = previous.then((_) async {
      try {
        await write();
        if (!completer.isCompleted) completer.complete();
      } on Object catch (error, stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      }
    });
    _queues[designId] = chained;
    unawaited(
      chained.whenComplete(() {
        if (identical(_queues[designId], chained)) _queues.remove(designId);
      }),
    );
    return completer.future;
  }

  Future<void> _drain() async {
    while (_queues.isNotEmpty) {
      await Future.wait<void>(_queues.values.toList());
    }
  }

  Future<void> _write(
    DesignDocument document, {
    required String designId,
    required String productId,
    required String title,
  }) async {
    final directory = await _designDirectory(designId);
    await directory.create(recursive: true);

    final revisions = Directory('${directory.path}/revisions');
    await revisions.create(recursive: true);

    final json = jsonEncode(document.toJson());
    final target = File('${directory.path}/document.json');
    final temp = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temp.writeAsString(json, flush: true);
      await temp.rename(target.path);
    } on Object {
      await _deleteQuietly(temp);
      rethrow;
    }

    final revisionFile = File('${revisions.path}/r${document.revision}.json');
    await revisionFile.writeAsString(json, flush: true);
    await _pruneRevisions(revisions);

    try {
      await _database
          .into(_database.draftIndex)
          .insertOnConflictUpdate(
            DraftIndexCompanion.insert(
              designId: designId,
              productId: productId,
              revision: document.revision,
              title: Value(title),
              updatedAt: DateTime.now().toUtc(),
            ),
          );
    } on StateError {
      return;
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
    }
  }

  void cancelPending() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _pending.clear();
  }

  Future<void> dispose() {
    _disposed = true;
    cancelPending();
    return _drain();
  }

  void scheduleSave(
    DesignDocument document, {
    required String designId,
    required String productId,
    String title = '',
  }) {
    if (_disposed) return;
    _pending[designId] = _PendingSave(document, productId, title);
    _timers[designId]?.cancel();
    _timers[designId] = Timer(_debounce, () {
      final latest = _pending.remove(designId);
      if (latest == null) return;
      unawaited(
        saveNow(
          latest.document,
          designId: designId,
          productId: latest.productId,
          title: latest.title,
        ).catchError((Object _) {}),
      );
    });
  }

  Future<DesignDocument?> load(String designId) async {
    final file = File(
      '${(await _designDirectory(designId)).path}/document.json',
    );
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    final decoded = DesignDocument.fromJson(jsonDecode(raw));
    return decoded.valueOrNull;
  }

  Future<List<DraftIndexData>> list() {
    final query = _database.select(_database.draftIndex)
      ..orderBy(<OrderClauseGenerator<$DraftIndexTable>>[
        (table) => OrderingTerm.desc(table.updatedAt),
      ]);
    return query.get();
  }

  Future<void> delete(String designId) async {
    _timers.remove(designId)?.cancel();
    _pending.remove(designId);
    await _drainDesign(designId);
    final directory = await _designDirectory(designId);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await (_database.delete(
      _database.draftIndex,
    )..where((table) => table.designId.equals(designId))).go();
  }

  Future<void> deleteAll() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _pending.clear();
    await _drain();
    final root = await _rootDirectory();
    final drafts = Directory('${root.path}/drafts');
    if (await drafts.exists()) await drafts.delete(recursive: true);
    await _database.delete(_database.draftIndex).go();
  }

  Future<List<String>> missingAssets(
    String designId,
    DesignDocument document,
  ) async {
    final directory = await _assetsDirectory(designId);
    final missing = <String>[];
    for (final asset in document.assets) {
      final file = File('${directory.path}/${asset.sha256}');
      if (!await file.exists()) missing.add(asset.sha256);
    }
    return missing;
  }

  Future<void> flush() async {
    final entries = _pending.entries.toList();
    final writes = <Future<void>>[];
    for (final entry in entries) {
      _timers.remove(entry.key)?.cancel();
      _pending.remove(entry.key);
      writes.add(
        saveNow(
          entry.value.document,
          designId: entry.key,
          productId: entry.value.productId,
          title: entry.value.title,
        ).catchError((Object _) {
        }),
      );
    }
    await Future.wait(writes);
    await _drain();
  }

  Future<void> _drainDesign(String designId) async {
    while (_queues.containsKey(designId)) {
      await _queues[designId]!;
    }
  }

  Future<Directory> _designDirectory(String designId) async {
    final root = await _rootDirectory();
    return Directory('${root.path}/drafts/$designId');
  }

  Future<Directory> _assetsDirectory(String designId) async {
    final directory = await _designDirectory(designId);
    return Directory('${directory.path}/assets');
  }

  Future<void> _pruneRevisions(Directory revisions) async {
    final files = await revisions
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    if (files.length <= _keepRevisions) return;
    final numbered = <({File file, int revision})>[];
    for (final file in files) {
      final revision = _revisionOf(file);
      if (revision != null) numbered.add((file: file, revision: revision));
    }
    if (numbered.length <= _keepRevisions) return;
    numbered.sort((a, b) => a.revision.compareTo(b.revision));
    for (final entry in numbered.take(numbered.length - _keepRevisions)) {
      await _deleteQuietly(entry.file);
    }
  }

  static int? _revisionOf(File file) {
    final name = file.uri.pathSegments.last;
    return int.tryParse(name.replaceFirst('r', '').replaceFirst('.json', ''));
  }
}

final class _PendingSave {
  const _PendingSave(this.document, this.productId, this.title);

  final DesignDocument document;
  final String productId;
  final String title;
}

Future<Directory> defaultDraftRoot() async {
  final documents = await getApplicationDocumentsDirectory();
  return Directory('${documents.path}/picpac');
}
