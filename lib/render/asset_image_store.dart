import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../core/media/asset_cache.dart';
import '../core/media/image_probe.dart';
import '../core/media/photo_format.dart';

const int kAssetCacheBudgetBytes = 64 * 1024 * 1024;

const int kAssetDecodeMaxSide = 6000;

int slotDecodeSidePx({
  required double widthMm,
  required double heightMm,
  required int dpi,
  double zoom = 1,
}) {
  final longSideMm = math.max(widthMm, heightMm);
  final safeDpi = dpi <= 0 ? 300 : dpi;
  final safeZoom = zoom < 1 ? 1.0 : zoom;
  if (longSideMm <= 0) return 0;
  return (longSideMm / 25.4 * safeDpi * safeZoom).ceil();
}

int boundedDecodeSide({
  required int target,
  int? intrinsicSide,
  int ceiling = kAssetDecodeMaxSide,
}) {
  var side = target;
  if (intrinsicSide != null && intrinsicSide > 0 && side > intrinsicSide) {
    side = intrinsicSide;
  }
  if (side > ceiling) side = ceiling;
  return side < 1 ? 1 : side;
}

typedef PreviewDecoder = Future<ui.Image?> Function(String path, int maxSide);

Future<ui.Image?> decodePreviewAtPath(String path, int maxSide) =>
    decodePreviewFile(File(path), maxSide: maxSide);

final class AssetImageStore extends ChangeNotifier {
  AssetImageStore({
    required this._cache,
    required this.designId,
    this._maxSide = PhotoFormats.previewMaxSide,
    this._budgetBytes = kAssetCacheBudgetBytes,
    this._decode = decodePreviewAtPath,
    int maxConcurrentDecodes = 2,
    this._prefetchConcurrentDecodes = 3,
  }) : _gate = _DecodeGate(maxConcurrentDecodes);

  final DesignAssetCache _cache;

  final String designId;

  final int _maxSide;
  final int _budgetBytes;
  final PreviewDecoder _decode;

  final int _prefetchConcurrentDecodes;

  final _DecodeGate _gate;

  final LinkedHashMap<String, _Texture> _textures =
      LinkedHashMap<String, _Texture>();

  final Map<String, Future<void>> _inflight = <String, Future<void>>{};

  final Map<String, int> _wantedSides = <String, int>{};

  final Map<String, int> _intrinsicSides = <String, int>{};

  final List<int> _decodedSides = <int>[];

  int _bytes = 0;

  int _generation = 0;
  bool _disposed = false;

  int get budgetBytes => _budgetBytes;

  @visibleForTesting
  int get cachedBytes => _bytes;

  @visibleForTesting
  int get cachedTextures => _textures.length;

  @visibleForTesting
  int get activeDecodes => _gate.active;

  @visibleForTesting
  int get waitingDecodes => _gate.waiting;

  ui.Image? imageOf(String sha256) {
    final entry = _textures.remove(sha256);
    if (entry == null) return null;
    _textures[sha256] = entry; // Mark as most recently used.
    return entry.image;
  }

  bool isLoaded(String sha256) => _textures.containsKey(sha256);

  @visibleForTesting
  List<int> get decodedSides => List<int>.unmodifiable(_decodedSides);

  @visibleForTesting
  int? requestedSideOf(String sha256) => _wantedSides[sha256];

  @visibleForTesting
  int? intrinsicSideOf(String sha256) => _intrinsicSides[sha256];

  ui.Size? sizeOf(String sha256) {
    final entry = _textures[sha256];
    if (entry == null) return null;
    return ui.Size(entry.image.width.toDouble(), entry.image.height.toDouble());
  }

  void request(String sha256, {int? targetSide, int? intrinsicSide}) {
    if (_disposed) return;
    if (intrinsicSide != null && intrinsicSide > 0) {
      _intrinsicSides[sha256] = intrinsicSide;
    }
    final wanted = targetSide == null || targetSide <= 0
        ? _maxSide
        : boundedDecodeSide(
            target: targetSide,
            intrinsicSide: intrinsicSide ?? _intrinsicSides[sha256],
          );
    final previous = _wantedSides[sha256];
    if (previous == null || wanted > previous) _wantedSides[sha256] = wanted;
    final cached = _textures[sha256];
    if (cached != null && cached.side >= (_wantedSides[sha256] ?? 0)) return;
    if (_inflight.containsKey(sha256)) return;
    unawaited(_load(sha256));
  }

  void requestAll(Iterable<String> hashes) {
    for (final hash in hashes) {
      request(hash);
    }
  }

  Future<void> preload(Iterable<String> hashes) async {
    final previous = _gate.capacity;
    _gate.capacity = math.max(previous, _prefetchConcurrentDecodes);
    try {
      final pending = <Future<void>>[];
      for (final hash in hashes) {
        if (_textures.containsKey(hash)) continue;
        pending.add(_load(hash));
      }
      await Future.wait(pending);
    } finally {
      _gate.capacity = previous;
    }
  }

  void clear() {
    _generation++;
    _gate.cancelWaiting();
    for (final entry in _textures.values) {
      entry.image.dispose();
    }
    _textures.clear();
    _bytes = 0;
    if (!_disposed) notifyListeners();
  }

  Future<void> _load(String sha256) {
    final existing = _inflight[sha256];
    if (existing != null) return existing;
    final future = _decodeAndStore(sha256);
    _inflight[sha256] = future;
    return future.whenComplete(() => _inflight.remove(sha256));
  }

  Future<void> _decodeAndStore(String sha256) async {
    final generation = _generation;
    final side = boundedDecodeSide(
      target: _wantedSides[sha256] ?? _maxSide,
      intrinsicSide: _intrinsicSides[sha256],
    );
    var granted = false;
    try {
      final file = await _cache.fileFor(designId, sha256);
      if (file == null || _disposed || generation != _generation) return;
      granted = await _gate.acquire();
      if (!granted || _disposed || generation != _generation) return;
      _decodedSides.add(side);
      final image = await _decode(file.path, side);
      if (image == null || _disposed || generation != _generation) {
        image?.dispose();
        return;
      }
      final previous = _textures.remove(sha256);
      if (previous != null) {
        _bytes -= previous.bytes;
        previous.image.dispose();
      }
      final entry = _Texture(image, image.width * image.height * 4, side);
      _textures[sha256] = entry;
      _bytes += entry.bytes;
      _evict();
      if (!_disposed) notifyListeners();
    } on Object {
    } finally {
      if (granted) _gate.release();
    }
  }

  void _evict() {
    while (_bytes > _budgetBytes && _textures.length > 1) {
      final oldestKey = _textures.keys.first;
      final removed = _textures.remove(oldestKey);
      if (removed == null) break;
      _bytes -= removed.bytes;
      removed.image.dispose();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _gate.cancelWaiting();
    for (final entry in _textures.values) {
      entry.image.dispose();
    }
    _textures.clear();
    _bytes = 0;
    super.dispose();
  }
}

final class _DecodeGate {
  _DecodeGate(this._capacity);

  int _capacity;
  int _active = 0;
  final Queue<Completer<bool>> _waiters = Queue<Completer<bool>>();

  int get capacity => _capacity;

  set capacity(int value) => _capacity = value < 1 ? 1 : value;

  int get active => _active;

  int get waiting => _waiters.length;

  Future<bool> acquire() {
    if (_active < _capacity) {
      _active++;
      return Future<bool>.value(true);
    }
    final waiter = Completer<bool>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(true);
      return;
    }
    if (_active > 0) _active--;
  }

  void cancelWaiting() {
    while (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(false);
    }
  }
}

final class _Texture {
  const _Texture(this.image, this.bytes, this.side);

  final ui.Image image;
  final int bytes;

  final int side;
}
