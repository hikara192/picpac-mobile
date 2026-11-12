import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

class AssistantToolButton extends StatelessWidget {
  const AssistantToolButton({
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final VoidCallback onTap;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final foreground = enabled ? PicPacColors.ink : PicPacColors.muted;
    final iconColor = enabled ? PicPacColors.accentText : PicPacColors.muted;
    return Tooltip(
      message: l10n.assistantButton,
      child: SizedBox(
        width: 92,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: enabled ? PicPacColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(PicPacRadii.field),
            child: InkWell(
              key: const ValueKey<String>('editor_assistant_button'),
              borderRadius: BorderRadius.circular(PicPacRadii.field),
              onTap: enabled ? onTap : null,
              child: Semantics(
                button: true,
                enabled: enabled,
                label: l10n.assistantButton,
                excludeSemantics: true,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 88),
                  padding: const EdgeInsets.symmetric(
                    horizontal: PicPacSpacing.xxs,
                    vertical: PicPacSpacing.xs,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.auto_awesome, size: 22, color: iconColor),
                      const SizedBox(height: 2),
                      Text(
                        l10n.assistantButton,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
