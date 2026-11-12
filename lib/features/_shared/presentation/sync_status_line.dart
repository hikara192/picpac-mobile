import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/design_session.dart';
import '../../../core/presentation/text_tones.dart';

class SyncStatusLine extends StatelessWidget {
  const SyncStatusLine({required this.state, super.key});

  final DesignSessionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (text, icon) = switch (state.sync) {
      DesignSyncStatus.offline => (
        l10n.createOfflineBanner,
        Icons.cloud_off_outlined,
      ),
      DesignSyncStatus.pending => (l10n.createSyncPending, Icons.sync_outlined),
      DesignSyncStatus.conflict => (
        l10n.createConflictTitle,
        Icons.sync_problem_outlined,
      ),
      DesignSyncStatus.failed => (l10n.errorGeneric, Icons.error_outline),
      DesignSyncStatus.saving => (l10n.createSyncSaving, Icons.sync),
      DesignSyncStatus.synced => (
        state.restoredFromCache
            ? l10n.createDraftRestored
            : l10n.createSyncSaved,
        Icons.check_circle_outline,
      ),
    };
    return Semantics(
      liveRegion: true,
      label: text,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 14, color: FunnelText.secondary),
            const SizedBox(width: PicPacSpacing.xs),
            Flexible(
              child: Text(
                text,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: FunnelText.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
