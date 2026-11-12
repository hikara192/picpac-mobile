import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/presentation/a11y.dart';
import '../../../../core/presentation/format.dart';
import '../../../../core/presentation/picpac_card.dart';
import '../../../_shared/presentation/product_artwork.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({required this.product, required this.onTap, super.key});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final minPrice = product.minPrice;
    final priceLabel = minPrice == null
        ? null
        : l10n.priceFrom(Fmt.of(context).money(minPrice));
    return FocusRing(
      child: Semantics(
        container: true,
        button: true,
        label: priceLabel == null
            ? product.title
            : a11yProductCardLabel(
                l10n,
                title: product.title,
                price: priceLabel,
              ),
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: PicPacColors.surface,
          borderRadius: BorderRadius.circular(PicPacRadii.card),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(PicPacRadii.card),
            child: PicPacCard(
              color: Colors.transparent,
              padding: const EdgeInsets.all(PicPacSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: ProductArtwork(
                        seedId: product.id,
                        category: product.category,
                      ),
                    ),
                  ),
                  const SizedBox(height: PicPacSpacing.sm),
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: PicPacColors.ink,
                    ),
                  ),
                  if (priceLabel != null) ...<Widget>[
                    const SizedBox(height: PicPacSpacing.xxs),
                    Text(
                      priceLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: PicPacColors.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
