import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../_shared/application/async_retry.dart';
import '../../../core/presentation/a11y.dart';
import '../../../core/presentation/state_views.dart';
import '../application/inspiration_controllers.dart';
import 'inspiration_labels.dart';
import 'widgets/inspiration_card.dart';

class InspirationPage extends ConsumerWidget {
  const InspirationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(inspirationProvider);
    final favorites = ref.watch(favoritesProvider);
    final state = feed.value;

    Future<void> toggleFavorite(InspirationItem item) async {
      final failure = await ref.read(favoritesProvider.notifier).toggle(item);
      if (failure == null || !context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.inspirationFavoriteFailed)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inspirationTitle, style: AppTheme.rootTabTitle),
        actions: <Widget>[
          IconButton(
            key: const Key('inspiration-favorites-filter'),
            tooltip: l10n.inspirationFilterFavorites,
            isSelected: state?.favoritesOnly ?? false,
            selectedIcon: const Icon(Icons.favorite),
            onPressed: state == null
                ? null
                : () => ref
                      .read(inspirationProvider.notifier)
                      .toggleFavoritesOnly(),
            icon: const Icon(Icons.favorite_border),
          ),
          const SizedBox(width: PicPacSpacing.xs),
        ],
      ),
      body: switch (feed) {
        AsyncData<InspirationFeedState>(:final value) => _FeedBody(
          state: value,
          favorites: favorites,
          onTag: (tag) => ref.read(inspirationProvider.notifier).selectTag(tag),
          onToggleFavorite: toggleFavorite,
          onLoadMore: () => ref.read(inspirationProvider.notifier).loadMore(),
          onRefresh: () => ref.read(inspirationProvider.notifier).refresh(),
          onRetry: () => ref.read(inspirationProvider.notifier).refresh(),
          onShowAll: () =>
              ref.read(inspirationProvider.notifier).selectTag(null),
          onShowFavorites: () =>
              ref.read(inspirationProvider.notifier).toggleFavoritesOnly(),
        ),
        AsyncError<InspirationFeedState>(:final error) => FailureView(
          failure: failureOr(error),
          onRetry: () => ref.invalidate(inspirationProvider),
          onLogin: () => context.push(AppRoutes.login),
        ),
        _ => const _FeedSkeleton(),
      },
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.state,
    required this.favorites,
    required this.onTag,
    required this.onToggleFavorite,
    required this.onLoadMore,
    required this.onRefresh,
    required this.onRetry,
    required this.onShowAll,
    required this.onShowFavorites,
  });

  final InspirationFeedState state;

  final Map<String, bool> favorites;
  final ValueChanged<String?> onTag;
  final ValueChanged<InspirationItem> onToggleFavorite;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onShowAll;
  final VoidCallback onShowFavorites;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visible = state.favoritesOnly
        ? <InspirationItem>[
            for (final item in state.items)
              if (favorites[item.id] ?? item.isFavorite) item,
          ]
        : state.items;
    return Column(
      children: <Widget>[
        _TagBar(
          tags: state.tags,
          activeTag: state.activeTag,
          onTag: onTag,
          busy: state.busy,
        ),
        Expanded(
          child: RefreshIndicator(
            color: PicPacColors.accent,
            onRefresh: onRefresh,
            child: _content(context, l10n, visible),
          ),
        ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    AppLocalizations l10n,
    List<InspirationItem> visible,
  ) {
    if (state.busy && state.items.isEmpty) return const _FeedSkeleton();
    if (state.failure != null && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
          FailureView(failure: state.failure!, onRetry: onRetry),
        ],
      );
    }
    if (visible.isEmpty) return _empty(context, l10n);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(PicPacSpacing.lg),
      child: Column(
        children: <Widget>[
          _IdeaMasonry(
            items: visible,
            favorites: favorites,
            onToggleFavorite: onToggleFavorite,
          ),
          if (state.busy) ...<Widget>[
            const SizedBox(height: PicPacSpacing.lg),
            const Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
          if (state.failure != null && state.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: PicPacSpacing.lg),
            Text(
              l10n.inspirationLoadMoreFailed,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: PicPacColors.secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PicPacSpacing.sm),
            OutlinedButton(
              onPressed: onLoadMore,
              child: Text(l10n.actionRetry),
            ),
          ],
          if (state.failure == null &&
              state.hasMore &&
              !state.busy) ...<Widget>[
            const SizedBox(height: PicPacSpacing.lg),
            MinTapTarget(
              child: OutlinedButton(
                key: const Key('inspiration-load-more'),
                onPressed: onLoadMore,
                child: Text(l10n.inspirationLoadMore),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, AppLocalizations l10n) {
    if (state.favoritesOnly) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
          EmptyView(
            title: l10n.inspirationEmptyFavoritesTitle,
            body: l10n.inspirationEmptyFavoritesBody,
            icon: Icons.favorite_border,
            action: OutlinedButton(
              onPressed: onShowFavorites,
              child: Text(l10n.inspirationShowAll),
            ),
          ),
        ],
      );
    }
    if (state.activeTag != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
          EmptyView(
            title: l10n.inspirationEmptyTagTitle,
            body: l10n.inspirationEmptyTagBody,
            icon: Icons.search_off,
            hero: true,
            action: OutlinedButton(
              onPressed: onShowAll,
              child: Text(l10n.inspirationShowAll),
            ),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
        EmptyView(
          title: l10n.inspirationEmptyTitle,
          body: l10n.inspirationEmptyBody,
          icon: Icons.explore_outlined,
          hero: true,
        ),
      ],
    );
  }
}

class _TagBar extends StatelessWidget {
  const _TagBar({
    required this.tags,
    required this.activeTag,
    required this.onTag,
    required this.busy,
  });

  final List<String> tags;
  final String? activeTag;
  final ValueChanged<String?> onTag;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l10n.inspirationTagBarLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: PicPacSpacing.lg,
          vertical: PicPacSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            _chip(
              label: l10n.inspirationTagAll,
              selected: activeTag == null,
              onSelected: () => onTag(null),
              key: const Key('inspiration-tag-all'),
            ),
            for (final tag in tags)
              _chip(
                label: ideaTag(l10n, tag),
                selected: activeTag == tag,
                onSelected: () => onTag(tag),
                key: Key('inspiration-tag-$tag'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    required Key key,
  }) => Padding(
    padding: const EdgeInsets.only(right: PicPacSpacing.sm),
    child: ChoiceChip(
      key: key,
      label: Text(label),
      selected: selected,
      onSelected: busy ? null : (_) => onSelected(),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      showCheckmark: false,
      selectedColor: PicPacColors.accentSoft,
      side: BorderSide(
        color: selected ? PicPacColors.accent : PicPacColors.border,
      ),
      labelStyle: TextStyle(
        color: selected ? PicPacColors.ink : PicPacColors.inkStrong,
      ),
    ),
  );
}

class _IdeaMasonry extends StatelessWidget {
  const _IdeaMasonry({
    required this.items,
    required this.favorites,
    required this.onToggleFavorite,
  });

  final List<InspirationItem> items;
  final Map<String, bool> favorites;
  final ValueChanged<InspirationItem> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final scaled = MediaQuery.textScalerOf(context).scale(14);
    final columns = scaled > 22 ? 1 : (width >= 600 ? 3 : 2);
    final buckets = List<List<InspirationItem>>.generate(
      columns,
      (_) => <InspirationItem>[],
    );
    for (var index = 0; index < items.length; index++) {
      buckets[index % columns].add(items[index]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var column = 0; column < columns; column++) ...<Widget>[
          if (column > 0) const SizedBox(width: PicPacSpacing.md),
          Expanded(
            child: Column(
              children: <Widget>[
                for (final item in buckets[column])
                  Padding(
                    padding: const EdgeInsets.only(bottom: PicPacSpacing.md),
                    child: InspirationCard(
                      key: Key('inspiration-card-${item.id}'),
                      item: item,
                      title: ideaTitle(l10n, item.titleKey),
                      isFavorite: favorites[item.id] ?? item.isFavorite,
                      onOpen: () =>
                          context.push(AppRoutes.inspirationFor(item.id)),
                      onToggleFavorite: () => onToggleFavorite(item),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final columns = MediaQuery.sizeOf(context).width >= 600 ? 3 : 2;
    return Semantics(
      label: l10n.inspirationLoading,
      liveRegion: true,
      child: GridView.builder(
        padding: const EdgeInsets.all(PicPacSpacing.lg),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: columns * 3,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: PicPacSpacing.md,
          crossAxisSpacing: PicPacSpacing.md,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (context, index) => const SkeletonBox(
          height: double.infinity,
          radius: PicPacRadii.card,
        ),
      ),
    );
  }
}
