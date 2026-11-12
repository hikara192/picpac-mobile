import 'dart:convert';
import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/storage/draft_store.dart';

final class FormatSnapshot {
  const FormatSnapshot({required this.format, this.fromCache = false});

  final ProductFormat format;

  final bool fromCache;
}

final class DesignFormatRepository {
  DesignFormatRepository({required this._api, required this._rootDirectory});

  final ApiPort _api;
  final Future<Directory> Function() _rootDirectory;

  Future<Result<FormatSnapshot>> load({
    required String designId,
    required String productId,
    required String formatId,
  }) async {
    final result = await _api.product(productId);
    switch (result) {
      case Ok<Product>(:final value):
        for (final format in value.formats) {
          if (format.id == formatId) {
            await _writeCache(designId, format);
            return Ok<FormatSnapshot>(FormatSnapshot(format: format));
          }
        }
        return Err<FormatSnapshot>(
          ApiFailure(
            code: ApiErrorCode.notFound,
            message: 'the catalogue no longer offers format "$formatId"',
            args: <String, Object?>{'formatId': formatId},
          ),
        );
      case Err<Product>(:final error):
        if (!_isOffline(error)) return Err<FormatSnapshot>(error);
        final cached = await _readCache(designId, formatId);
        if (cached == null) return Err<FormatSnapshot>(error);
        return Ok<FormatSnapshot>(
          FormatSnapshot(format: cached, fromCache: true),
        );
    }
  }

  bool _isOffline(Failure failure) =>
      failure.code == ApiErrorCode.networkUnavailable ||
      failure.code == ApiErrorCode.timeout ||
      failure.code == ApiErrorCode.serverError;

  Future<File> _cacheFile(String designId) async {
    final root = await _rootDirectory();
    final directory = Directory('${root.path}/drafts/$designId');
    await directory.create(recursive: true);
    return File('${directory.path}/format.json');
  }

  Future<void> _writeCache(String designId, ProductFormat format) async {
    try {
      final file = await _cacheFile(designId);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(
        jsonEncode(<String, Object?>{
          'cachedAt': DateTime.now().toUtc().toIso8601String(),
          'format': format.toJson(),
        }),
        flush: true,
      );
      await temp.rename(file.path);
    } on Object {
    }
  }

  Future<ProductFormat?> _readCache(String designId, String formatId) async {
    try {
      final file = await _cacheFile(designId);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return null;
      final raw = decoded['format'];
      if (raw is! Map) return null;
      final format = ProductFormat.fromJson(Map<String, Object?>.from(raw));
      return format.id == formatId ? format : null;
    } on Object {
      return null;
    }
  }
}

final Provider<Future<Directory> Function()> draftRootProvider =
    Provider<Future<Directory> Function()>((ref) => defaultDraftRoot);

final Provider<DesignFormatRepository> designFormatRepositoryProvider =
    Provider<DesignFormatRepository>(
      (ref) => DesignFormatRepository(
        api: ref.watch(apiPortProvider),
        rootDirectory: ref.watch(draftRootProvider),
      ),
    );
