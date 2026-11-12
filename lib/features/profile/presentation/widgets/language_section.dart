import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/settings/locale_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/presentation/state_views.dart';
import '../../../../core/presentation/text_tones.dart';

class LanguageSection extends ConsumerWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = AppLocaleChoice.fromLocale(
      ref.watch(localeControllerProvider),
    );
    return SectionCard(
      title: l10n.profileLanguageTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.profileLanguageHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: FunnelText.secondary,
            ),
          ),
          const SizedBox(height: PicPacSpacing.sm),
          RadioGroup<AppLocaleChoice>(
            groupValue: selected,
            onChanged: (value) {
              if (value == null) return;
              ref.read(localeControllerProvider.notifier).select(value);
            },
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: <Widget>[
                  for (final choice in AppLocaleChoice.values)
                    RadioListTile<AppLocaleChoice>(
                      value: choice,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.comfortable,
                      title: Text(_label(l10n, choice)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _label(AppLocalizations l10n, AppLocaleChoice choice) =>
      switch (choice) {
        AppLocaleChoice.system => l10n.profileLanguageSystem,
        AppLocaleChoice.ru => l10n.profileLanguageRu,
        AppLocaleChoice.be => l10n.profileLanguageBe,
      };
}
