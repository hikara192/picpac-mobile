import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/presentation/picpac_card.dart';
import '../inspiration_labels.dart';
import 'template_preview.dart';

class InspirationCard extends StatelessWidget {
  const InspirationCard({
    required this.item,
    required this.title,
    required this.isFavorite,
    required this.onOpen,
    required this.onToggleFavorite,
    super.key,
  });

  final InspirationItem item;

  final String title;

  final bool isFavorite;

  final VoidCallback onOpen;

  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cardLabel = ideaCardLabel(l10n, title, item.slotCount);
    final favoriteLabel = isFavorite
        ? l10n.inspirationRemoveTitle(title)
        : l10n.inspirationSaveTitle(title);
    return PicPacCard(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Stack(
            children: <Widget>[
              Semantics(
                container: true,
                button: true,
                label: cardLabel,
                excludeSemantics: true,
                onTap: onOpen,
                child: InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.all(PicPacSpacing.sm),
                    child: TemplatePreview(
                      slots: item.slots,
                      aspect: item.aspect,
                      selectedSlot: 0,
                      background: PicPacColors.surfaceMuted,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Semantics(
                  container: true,
                  button: true,
                  toggled: isFavorite,
                  label: favoriteLabel,
                  excludeSemantics: true,
                  child: IconButton(
                    key: Key('inspiration-favorite-${item.id}'),
                    onPressed: onToggleFavorite,
                    tooltip: favoriteLabel,
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(kMinTouchTarget),
                      backgroundColor: PicPacColors.surface.withValues(
                        alpha: 0.86,
                      ),
                      foregroundColor: isFavorite
                          ? PicPacColors.accent
                          : PicPacColors.secondaryText,
                    ),
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PicPacSpacing.md,
              0,
              PicPacSpacing.md,
              PicPacSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (item.tags.isNotEmpty) ...<Widget>[
                  const SizedBox(height: PicPacSpacing.xs),
                  Wrap(
                    spacing: PicPacSpacing.xs,
                    runSpacing: PicPacSpacing.xxs,
                    children: <Widget>[
                      for (final tag in item.tags.take(2))
                        _TagLabel(text: ideaTag(l10n, tag)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagLabel extends StatelessWidget {
  const _TagLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: PicPacSpacing.sm,
      vertical: 2,
    ),
    decoration: BoxDecoration(
      color: PicPacColors.fillStone,
      borderRadius: BorderRadius.circular(PicPacRadii.pill),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: PicPacColors.inkStrong),
    ),
  );
}
