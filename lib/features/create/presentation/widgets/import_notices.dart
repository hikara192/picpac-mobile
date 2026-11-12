import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../_shared/presentation/media_messages.dart';
import '../../../../core/presentation/text_tones.dart';
import '../../application/import_controller.dart';

class ImportNotices extends ConsumerWidget {
  const ImportNotices({required this.designId, super.key});

  final String designId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importControllerProvider(designId));
    if (state.pickerFailure == null &&
        state.rejections.isEmpty &&
        state.duplicates == 0) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: PicPacSpacing.md),
        if (state.pickerFailure != null)
          _Notice(
            tone: PicPacColors.accentSoft,
            icon: Icons.lock_outline,
            title: l10n.mediaPermissionTitle,
            body: pickerFailureText(l10n, state.pickerFailure!),
            action: OutlinedButton(
              onPressed: () => ref
                  .read(importControllerProvider(designId).notifier)
                  .pickAndImport(),
              child: Text(l10n.mediaPermissionRetry),
            ),
          ),
        if (state.rejections.isNotEmpty) ...<Widget>[
          _Notice(
            tone: PicPacColors.fillBeige,
            icon: Icons.image_not_supported_outlined,
            title: l10n.mediaRejectedTitle,
            body: state.rejections
                .map(
                  (rejection) =>
                      '${rejection.fileName}: '
                      '${photoRejectionText(l10n, rejection)}',
                )
                .join('\n'),
            action: TextButton(
              onPressed: () => ref
                  .read(importControllerProvider(designId).notifier)
                  .dismissRejections(),
              child: Text(l10n.actionClose),
            ),
          ),
          const SizedBox(height: PicPacSpacing.sm),
        ],
        if (state.duplicates > 0)
          Text(
            l10n.mediaDuplicatesSkipped(state.duplicates),
            style: theme.textTheme.bodySmall?.copyWith(
              color: FunnelText.secondary,
            ),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.tone,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final Color tone;
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PicPacSpacing.md),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(PicPacRadii.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 18, color: PicPacColors.inkStrong),
              const SizedBox(width: PicPacSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: PicPacColors.inkStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PicPacSpacing.xxs),
          Text(
            body,
            style: theme.textTheme.bodySmall?.copyWith(color: PicPacColors.ink),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: PicPacSpacing.sm),
            Align(alignment: Alignment.centerLeft, child: action),
          ],
        ],
      ),
    );
  }
}
