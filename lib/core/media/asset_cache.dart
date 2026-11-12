import 'dart:io';

import 'package:design_core/design_core.dart';

import 'photo_format.dart';

final class DesignAssetCache {
  DesignAssetCache({required this._rootDirectory});

  final Future<Directory> Function() _rootDirectory;

  Future<Directory> directoryFor(String designId) async {
    final root = await _rootDirectory();
    return Directory('${root.path}/drafts/$designId/assets');
  }

  Future<File?> fileFor(String designId, String sha256) async {
    final file = File('${(await directoryFor(designId)).path}/$sha256');
    return await file.exists() ? file : null;
  }

  Future<Result<File>> store({
    required String designId,
    required String sha256,
    required File source,
  }) async {
    try {
      final directory = await directoryFor(designId);
      await directory.create(recursive: true);
      final target = File('${directory.path}/$sha256');
      if (await target.exists() && await target.length() > 0) return Ok(target);

      final temp = File('${target.path}.tmp');
      await source.copy(temp.path);
      if (await temp.length() == 0) {
        await temp.delete();
        return Err<File>(
          const MediaFailure(
            code: MediaErrorCode.cacheFailed,
            message: 'the copied original is empty',
          ),
        );
      }
      await temp.rename(target.path);
      return Ok<File>(target);
    } on Object catch (error) {
      return Err<File>(
        MediaFailure(
          code: MediaErrorCode.cacheFailed,
          message: 'the original cannot be cached: ${error.runtimeType}',
        ),
      );
    }
  }

  Future<int> collectGarbage({
    required String designId,
    required Set<String> keep,
  }) async {
    final directory = await directoryFor(designId);
    if (!await directory.exists()) return 0;
    var removed = 0;
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (keep.contains(name)) continue;
      try {
        await entity.delete();
        removed++;
      } on Object {
      }
    }
    return removed;
  }

  Future<void> clear(String designId) async {
    final directory = await directoryFor(designId);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
