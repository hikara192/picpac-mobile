import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/app_localizations.dart';

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(PicPacSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.hourglass_empty,
                size: 40,
                color: PicPacColors.muted,
              ),
              const SizedBox(height: PicPacSpacing.md),
              Text(
                l10n.placeholderTitle,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PicPacSpacing.sm),
              Text(
                l10n.placeholderBody,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: PicPacColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
