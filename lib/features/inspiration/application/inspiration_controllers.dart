import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/session/session_service.dart';
import '../../_shared/application/async_retry.dart';

const int inspirationPageSize = 8;

final class InspirationFeedState {
  const InspirationFeedState({
    required this.items,
    required this.tags,
    this.nextCursor,
    this.activeTag,
    this.favoritesOnly = false,
    this.busy = false,
    this.failure,
  });

  final List<InspirationItem> items;

  final List<String> tags;

  final String? nextCursor;

  final String? activeTag;

  final bool favoritesOnly;

  final bool busy;

  final Failure? failure;

  bool get hasMore => nextCursor != null;

  bool get isEmpty => items.isEmpty && !busy && failure == null;

  InspirationFeedState copyWith({
    List<InspirationItem>? items,
    List<String>? tags,
    Object? nextCursor = _unset,
    Object? activeTag = _unset,
    bool? favoritesOnly,
    bool? busy,
    Object? failure = _unset,
  }) => InspirationFeedState(
    items: items ?? this.items,
    tags: tags ?? this.tags,
    nextCursor: identical(nextCursor, _unset)
        ? this.nextCursor
        : nextCursor as String?,
    activeTag: identical(activeTag, _unset)
        ? this.activeTag
        : activeTag as String?,
    favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    busy: busy ?? this.busy,
    failure: identical(failure, _unset) ? this.failure : failure as Failure?,
  );
}

final class InspirationController extends AsyncNotifier<InspirationFeedState> {
  @override
  Future<InspirationFeedState> build() => _firstPage(tag: null);

  Future<void> selectTag(String? tag) async {
    final current = state.value;
    if (current == null || current.activeTag == tag) return;
    state = AsyncData<InspirationFeedState>(
      current.copyWith(
        items: const <InspirationItem>[],
        nextCursor: null,
        activeTag: tag,
        busy: true,
        failure: null,
      ),
    );
    final next = await _firstPage(
      tag: tag,
      previousTags: current.tags,
      favoritesOnly: current.favoritesOnly,
    );
    if (!ref.mounted) return;
    state = AsyncData<InspirationFeedState>(next);
  }

  void toggleFavoritesOnly() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData<InspirationFeedState>(
      current.copyWith(favoritesOnly: !current.favoritesOnly),
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.busy || !current.hasMore) return;
    state = AsyncData<InspirationFeedState>(
      current.copyWith(busy: true, failure: null),
    );
    final api = ref.read(apiPortProvider);
    final session = ref.read(sessionServiceProvider);
    final result = await session.ensureSession(
      () => api.inspirationFeed(
        tag: current.activeTag,
        cursor: current.nextCursor,
        limit: inspirationPageSize,
      ),
    );
    if (!ref.mounted) return;
    switch (result) {
      case Ok<InspirationFeedPage>(:final value):
        final merged = <InspirationItem>[...current.items, ...value.items];
        state = AsyncData<InspirationFeedState>(
          current.copyWith(
            items: merged,
            tags: _collectTags(current.tags, value.items),
            nextCursor: value.nextCursor,
            busy: false,
          ),
        );
      case Err<InspirationFeedPage>(:final error):
        state = AsyncData<InspirationFeedState>(
          current.copyWith(busy: false, failure: error),
        );
    }
  }

  Future<void> refresh() async {
    final current = state.value;
    final tag = current?.activeTag;
    final favoritesOnly = current?.favoritesOnly ?? false;
    state = AsyncData<InspirationFeedState>(
      InspirationFeedState(
        items: const <InspirationItem>[],
        tags: current?.tags ?? const <String>[],
        activeTag: tag,
        favoritesOnly: favoritesOnly,
        busy: true,
      ),
    );
    final next = await _firstPage(
      tag: tag,
      previousTags: current?.tags,
      favoritesOnly: favoritesOnly,
    );
    if (!ref.mounted) return;
    state = AsyncData<InspirationFeedState>(
      next.copyWith(favoritesOnly: favoritesOnly),
    );
  }

  Future<InspirationFeedState> _firstPage({
    required String? tag,
    List<String>? previousTags,
    bool favoritesOnly = false,
  }) async {
    final api = ref.read(apiPortProvider);
    final session = ref.read(sessionServiceProvider);
    final knownTags = previousTags ?? const <String>[];
    final result = await session.ensureSession(
      () => api.inspirationFeed(tag: tag, limit: inspirationPageSize),
    );
    return switch (result) {
      Ok<InspirationFeedPage>(:final value) => InspirationFeedState(
        items: value.items,
        tags: _collectTags(knownTags, value.items),
        nextCursor: value.nextCursor,
        activeTag: tag,
        favoritesOnly: favoritesOnly,
      ),
      Err<InspirationFeedPage>(:final error) => InspirationFeedState(
        items: const <InspirationItem>[],
        tags: knownTags,
        activeTag: tag,
        favoritesOnly: favoritesOnly,
        failure: error,
      ),
    };
  }

  static List<String> _collectTags(
    List<String> known,
    List<InspirationItem> items,
  ) {
    final merged = <String>[...known];
    for (final item in items) {
      for (final tag in item.tags) {
        if (!merged.contains(tag)) merged.add(tag);
      }
    }
    return List<String>.unmodifiable(merged);
  }
}

final inspirationProvider =
    AsyncNotifierProvider<InspirationController, InspirationFeedState>(
      InspirationController.new,
      retry: noProviderRetry,
    );

final class InspirationDetailController
    extends AsyncNotifier<InspirationDetail> {
  InspirationDetailController(this.inspirationId);

  final String inspirationId;

  @override
  Future<InspirationDetail> build() async {
    final api = ref.read(apiPortProvider);
    final session = ref.read(sessionServiceProvider);
    final result = await session.ensureSession(
      () => api.inspirationItem(inspirationId),
    );
    return result.fold(ok: (detail) => detail, err: (failure) => throw failure);
  }
}

final inspirationDetailProvider =
    AsyncNotifierProvider.family<
      InspirationDetailController,
      InspirationDetail,
      String
    >(InspirationDetailController.new, retry: noProviderRetry);

final class FavoritesController extends Notifier<Map<String, bool>> {
  final Set<String> _pending = <String>{};

  @override
  Map<String, bool> build() => const <String, bool>{};

  bool isFavorite(InspirationItem item) => state[item.id] ?? item.isFavorite;

  bool isPending(String inspirationId) => _pending.contains(inspirationId);

  Future<Failure?> toggle(InspirationItem item) async {
    if (_pending.contains(item.id)) return null;
    final previous = isFavorite(item);
    final next = !previous;
    state = <String, bool>{...state, item.id: next};
    _pending.add(item.id);
    try {
      final api = ref.read(apiPortProvider);
      final session = ref.read(sessionServiceProvider);
      final result = next
          ? await session.ensureSession(() => api.addFavorite(item.id))
          : await session.ensureSession(() => api.removeFavorite(item.id));
      final failure = result.failureOrNull;
      if (failure != null) {
        if (ref.mounted) {
          state = <String, bool>{...state, item.id: previous};
        }
        return failure;
      }
      return null;
    } finally {
      _pending.remove(item.id);
    }
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesController, Map<String, bool>>(
      FavoritesController.new,
    );

const Object _unset = Object();
