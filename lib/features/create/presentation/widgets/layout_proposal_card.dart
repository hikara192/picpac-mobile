import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../_shared/application/design_session.dart';
import '../../../_shared/application/document_capabilities.dart';
import '../../../../core/presentation/text_tones.dart';
import '../../../../core/presentation/a11y.dart';

class LayoutProposalCard extends ConsumerStatefulWidget {
  const LayoutProposalCard({required this.designId, super.key});

  final String designId;

  @override
  ConsumerState<LayoutProposalCard> createState() => _LayoutProposalCardState();
}

class _LayoutProposalCardState extends ConsumerState<LayoutProposalCard> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final capabilities = ref.watch(documentCapabilitiesProvider);
    final state = ref.watch(designSessionProvider(widget.designId)).value;
    if (_dismissed || !capabilities.layoutPlanner || state == null) {
      return const SizedBox.shrink();
    }
    final photos = state.document.assets;
    if (photos.length < LayoutPlanner.denseMinPhotos) {
      return const SizedBox.shrink();
    }

    final plan = LayoutPlanner.planSheets(
      photos: photos,
      templates: state.templates.values.toList(),
      minSheets: state.minSheets,
    );
    final current = state.spreads.length;
    if (plan.isEmpty || plan.sheetCount >= current) {
      return const SizedBox.shrink();
    }
    final packsDenser =
        plan.sheetCount > 0 && plan.sheets.any((sheet) => sheet.slotCount > 1);
    if (!packsDenser) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PicPacSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.dashboard_customize_outlined,
                  size: 20,
                  color: PicPacColors.ink,
                ),
                const SizedBox(width: PicPacSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.createLayoutTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: PicPacSpacing.xxs),
            Text(
              l10n.createLayoutBody(plan.sheetCount, current),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: FunnelText.secondary,
              ),
            ),
            const SizedBox(height: PicPacSpacing.xxs),
            Text(
              l10n.createLayoutHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: FunnelText.secondary,
              ),
            ),
            const SizedBox(height: PicPacSpacing.sm),
            MinTapTarget(
              child: FilledButton(
                onPressed: () => _apply(plan),
                child: Text(l10n.createLayoutAccept),
              ),
            ),
            const SizedBox(height: PicPacSpacing.xs),
            MinTapTarget(
              child: OutlinedButton(
                onPressed: () => setState(() => _dismissed = true),
                child: Text(l10n.createLayoutKeep),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _apply(LayoutPlan plan) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(designSessionProvider(widget.designId).notifier);
    final result = notifier.execute(plan.toCommand());
    if (result is CommandFailed) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
      return;
    }
    setState(() => _dismissed = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.createLayoutApplied),
          action: SnackBarAction(
            label: l10n.createEnhanceUndo,
            onPressed: notifier.undo,
          ),
        ),
      );
  }
}
