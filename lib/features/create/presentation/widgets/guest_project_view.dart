import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/presentation/failure_text.dart';
import '../../../../core/presentation/text_tones.dart';
import '../../application/projects_controller.dart';
import '../../application/restart_project.dart';

class GuestProjectView extends ConsumerStatefulWidget {
  const GuestProjectView({required this.designId, super.key});

  final String designId;

  @override
  ConsumerState<GuestProjectView> createState() => _GuestProjectViewState();
}

class _GuestProjectViewState extends ConsumerState<GuestProjectView> {
  bool _restarting = false;

  Future<void> _restart() async {
    setState(() => _restarting = true);
    final l10n = AppLocalizations.of(context);
    final result = await ref
        .read(projectRestarterProvider)
        .restart(widget.designId);
    if (!mounted) return;
    setState(() => _restarting = false);
    switch (result) {
      case Ok<DesignDto>(:final value):
        ref.invalidate(projectsProvider);
        context.go(AppRoutes.createFor(value.id));
      case Err<DesignDto>(:final error):
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '${l10n.projectsRestartFailed}: ${failureText(l10n, error)}',
              ),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final snapshot = ref.watch(localSnapshotProvider(widget.designId));
    final canRestart = snapshot.value ?? false;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PicPacSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.lock_clock_outlined,
              size: 40,
              color: PicPacColors.muted,
            ),
            const SizedBox(height: PicPacSpacing.md),
            Text(
              l10n.projectsGuestTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PicPacSpacing.sm),
            Text(
              canRestart
                  ? l10n.projectsGuestBodySnapshot
                  : l10n.projectsGuestBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: FunnelText.secondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PicPacSpacing.xl),
            if (canRestart)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: FilledButton(
                  key: const Key('guest-project-restart'),
                  onPressed: _restarting ? null : _restart,
                  child: Text(
                    _restarting
                        ? l10n.projectsRestarting
                        : l10n.projectsRestart,
                  ),
                ),
              ),
            const SizedBox(height: PicPacSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: OutlinedButton(
                key: const Key('guest-project-catalog'),
                onPressed: () => context.go(AppRoutes.catalog),
                child: Text(l10n.actionGoCatalog),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
