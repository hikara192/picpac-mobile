import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'empty_illustration.dart';
import 'failure_text.dart';
import 'picpac_card.dart';

class FailureView extends StatelessWidget {
  const FailureView({
    required this.failure,
    required this.onRetry,
    this.onLogin,
    this.title,
    super.key,
  });

  final Failure failure;
  final VoidCallback onRetry;
  final VoidCallback? onLogin;

  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canLogin = onLogin != null && isAuthFailure(failure);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PicPacSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: PicPacColors.muted,
            ),
            const SizedBox(height: PicPacSpacing.md),
            PageHeader(
              title: title ?? l10n.errorGeneric,
              subtitle: failureText(l10n, failure),
              center: true,
              action: canLogin
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        FilledButton(
                          onPressed: onLogin,
                          child: Text(l10n.actionLogin),
                        ),
                        const SizedBox(height: PicPacSpacing.md),
                        OutlinedButton(
                          onPressed: onRetry,
                          child: Text(l10n.actionRetry),
                        ),
                      ],
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: FilledButton(
                        onPressed: onRetry,
                        child: Text(l10n.actionRetry),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.title,
    required this.body,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.hero = false,
    super.key,
  });

  final String title;
  final String body;

  final IconData icon;
  final Widget? action;

  final bool hero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PicPacSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            EmptyIllustration(motif: EmptyMotif.forIcon(icon)),
            const SizedBox(height: PicPacSpacing.lg),
            PageHeader(
              title: title,
              subtitle: body,
              center: true,
              titleStyle: hero ? theme.textTheme.displayLarge : null,
              action: action == null
                  ? null
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: action,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.height = 16,
    this.width,
    this.radius = PicPacRadii.field,
    super.key,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: PicPacColors.fillStone,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class CatalogSkeleton extends StatelessWidget {
  const CatalogSkeleton({this.items = 6, super.key});

  final int items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.catalogLoading,
      liveRegion: true,
      child: GridView.builder(
        padding: const EdgeInsets.all(PicPacSpacing.lg),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: PicPacSpacing.md,
          crossAxisSpacing: PicPacSpacing.md,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (context, index) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: SkeletonBox(
                height: double.infinity,
                radius: PicPacRadii.photo,
              ),
            ),
            SizedBox(height: PicPacSpacing.sm),
            SkeletonBox(height: 14, width: 120),
            SizedBox(height: PicPacSpacing.xs),
            SkeletonBox(height: 14, width: 80),
          ],
        ),
      ),
    );
  }
}

class CardListSkeleton extends StatelessWidget {
  const CardListSkeleton({this.items = 3, super.key});

  final int items;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).loading,
    liveRegion: true,
    child: ListView.separated(
      padding: const EdgeInsets.all(PicPacSpacing.lg),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items,
      separatorBuilder: (context, index) =>
          const SizedBox(height: PicPacSpacing.md),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(PicPacSpacing.md),
        decoration: BoxDecoration(
          color: PicPacColors.surface,
          borderRadius: BorderRadius.circular(PicPacRadii.card),
          border: Border.all(color: PicPacColors.border),
        ),
        child: const Row(
          children: <Widget>[
            SkeletonBox(height: 64, width: 64, radius: PicPacRadii.photo),
            SizedBox(width: PicPacSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SkeletonBox(height: 16, width: 160),
                  SizedBox(height: PicPacSpacing.sm),
                  SkeletonBox(height: 14, width: 96),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({required this.child, this.title, this.padding, super.key});

  final Widget child;
  final String? title;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: PicPacCard(
        padding: padding ?? const EdgeInsets.all(PicPacSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (title != null) ...<Widget>[
              Text(
                title!,
                style: theme.textTheme.titleSmall,
                semanticsLabel: title,
              ),
              const SizedBox(height: PicPacSpacing.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

enum ChipTone {
  neutral,

  success,

  progress,

  warning,

  danger,
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    this.tone = ChipTone.neutral,
    this.liveRegion = false,
    super.key,
  });

  final String label;
  final ChipTone tone;

  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (tone) {
      ChipTone.success => (
        PicPacColors.fillMint,
        PicPacColors.inkStrong,
        Icons.check_circle_outline,
      ),
      ChipTone.progress => (
        PicPacColors.fillBlue,
        PicPacColors.inkStrong,
        Icons.autorenew,
      ),
      ChipTone.warning => (
        PicPacColors.fillBeige,
        PicPacColors.inkStrong,
        Icons.info_outline,
      ),
      ChipTone.danger => (
        PicPacColors.accentSoft,
        PicPacColors.ink,
        Icons.error_outline,
      ),
      ChipTone.neutral => (
        PicPacColors.fillStone,
        PicPacColors.inkStrong,
        Icons.circle_outlined,
      ),
    };
    return Semantics(
      label: label,
      container: true,
      liveRegion: liveRegion,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PicPacSpacing.md,
          vertical: PicPacSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(PicPacRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: PicPacSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
