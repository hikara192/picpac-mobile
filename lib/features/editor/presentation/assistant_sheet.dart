import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/motion.dart';
import '../../../app/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../_shared/application/design_session.dart';
import '../../_shared/application/frame_analyzer.dart';
import '../../_shared/application/media_providers.dart';
import '../../../core/presentation/a11y.dart';
import '../../_shared/presentation/preflight_messages.dart';
import '../../_shared/presentation/sheet_scene.dart';
import '../../../core/presentation/text_tones.dart';
import 'assistant_messages.dart';
import 'assistant_service.dart';

Future<bool> showAssistantSheet(
  BuildContext context, {
  required String designId,
  required String spreadId,
}) async {
  final opener = FocusManager.instance.primaryFocus;
  final applied = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: PicPacColors.background,
    sheetAnimationStyle: AnimationStyle(
      duration: motionDuration(context, Motion.sheet),
      reverseDuration: motionDuration(context, Motion.reveal),
    ),
    builder: (_) => AssistantSheet(designId: designId, spreadId: spreadId),
  );
  if (opener != null && opener.context != null) opener.requestFocus();
  return applied ?? false;
}

enum _Phase {
  idle,

  asking,

  ready,

  failed,
}

class AssistantSheet extends ConsumerStatefulWidget {
  const AssistantSheet({
    required this.designId,
    required this.spreadId,
    super.key,
  });

  final String designId;

  final String spreadId;

  @override
  ConsumerState<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends ConsumerState<AssistantSheet> {
  final TextEditingController _intent = TextEditingController();
  final FocusNode _titleFocus = FocusNode(debugLabel: 'assistant-sheet-title');

  _Phase _phase = _Phase.idle;
  AssistantProposal? _proposal;
  Failure? _failure;
  String _lastIntent = '';
  bool _lastLocalOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _intent.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(designSessionProvider(widget.designId)).value;
    final spread = session?.document.spreadById(widget.spreadId);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          PicPacSpacing.lg,
          PicPacSpacing.xs,
          PicPacSpacing.lg,
          PicPacSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Focus(
              focusNode: _titleFocus,
              child: Semantics(
                header: true,
                child: Text(
                  l10n.assistantTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: PicPacSpacing.xs),
            Text(
              l10n.assistantHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: FunnelText.secondary,
              ),
            ),
            const SizedBox(height: PicPacSpacing.md),
            _chips(l10n),
            const SizedBox(height: PicPacSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('assistant_intent_field'),
                    controller: _intent,
                    enabled: _phase != _Phase.asking,
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: l10n.assistantHint,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _askFreeForm(),
                  ),
                ),
                const SizedBox(width: PicPacSpacing.sm),
                MinTapTarget(
                  child: IconButton.filled(
                    onPressed: _phase == _Phase.asking ? null : _askFreeForm,
                    tooltip: l10n.assistantAsk,
                    icon: const Icon(Icons.send),
                  ),
                ),
              ],
            ),
            if (_phase == _Phase.asking)
              const Padding(
                padding: EdgeInsets.only(top: PicPacSpacing.md),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (spread == null)
              Padding(
                padding: const EdgeInsets.only(top: PicPacSpacing.md),
                child: Text(
                  l10n.assistantNoChange,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            AnimatedSwitcher(
              duration: motionDuration(context, Motion.reveal),
              switchInCurve: Motion.easeOutCubic,
              switchOutCurve: Motion.easeOutCubic,
              child: switch (_phase) {
                _Phase.asking => Padding(
                  key: const ValueKey<String>('assistant-busy'),
                  padding: const EdgeInsets.only(top: PicPacSpacing.sm),
                  child: Text(
                    l10n.assistantThinking,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: FunnelText.secondary,
                    ),
                  ),
                ),
                _Phase.failed => _failureBlock(l10n, theme),
                _Phase.ready when session != null && spread != null =>
                  _proposalBlock(l10n, theme, session, spread),
                _ => const SizedBox.shrink(
                  key: ValueKey<String>('assistant-idle'),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _chips(AppLocalizations l10n) {
    final chips = <(String, String)>[
      (AiIntents.warmer, l10n.assistantChipWarmer),
      (AiIntents.brighter, l10n.assistantChipBrighter),
      (AiIntents.mono, l10n.assistantChipMono),
      (AiIntents.fillSlots, l10n.assistantChipFill),
      (AiIntents.denser, l10n.assistantChipDenser),
      (AiIntents.alignFrames, l10n.assistantChipAlign),
    ];
    return Wrap(
      spacing: PicPacSpacing.xs,
      runSpacing: PicPacSpacing.xs,
      children: <Widget>[
        for (final (code, label) in chips)
          ActionChip(
            key: ValueKey<String>('assistant_chip_$code'),
            label: Text(label),
            onPressed: _phase == _Phase.asking
                ? null
                : () => _ask(code, localOnly: true, spokenText: label),
          ),
      ],
    );
  }

  Widget _failureBlock(AppLocalizations l10n, ThemeData theme) {
    final failure = _failure;
    final text = failure == null
        ? l10n.assistantRejected
        : assistantFailureText(l10n, failure);
    return Padding(
      key: const ValueKey<String>('assistant-failed'),
      padding: const EdgeInsets.only(top: PicPacSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                size: 20,
                color: PicPacColors.accent,
              ),
              const SizedBox(width: PicPacSpacing.xs),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium,
                  semanticsLabel: text,
                ),
              ),
            ],
          ),
          const SizedBox(height: PicPacSpacing.sm),
          if (failure == null || assistantCanRetry(failure))
            MinTapTarget(
              child: OutlinedButton(
                onPressed: _phase == _Phase.asking ? null : _retry,
                child: Text(l10n.assistantRetry),
              ),
            ),
        ],
      ),
    );
  }

  Widget _proposalBlock(
    AppLocalizations l10n,
    ThemeData theme,
    DesignSessionState session,
    Spread spread,
  ) {
    final proposal = _proposal;
    if (proposal == null) return const SizedBox.shrink();
    final after = proposal.previewOf(session.document);
    final afterSpread = after.spreadById(spread.id) ?? spread;
    final entries = proposal.plan.entries;

    return Padding(
      key: const ValueKey<String>('assistant-ready'),
      padding: const EdgeInsets.only(top: PicPacSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            aiModeText(l10n, proposal.mode),
            style: theme.textTheme.labelSmall?.copyWith(
              color: FunnelText.secondary,
            ),
          ),
          const SizedBox(height: PicPacSpacing.xs),
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _preview(
                    l10n,
                    session: session,
                    document: session.document,
                    spread: spread,
                    side: l10n.assistantBefore,
                  ),
                ),
                const SizedBox(width: PicPacSpacing.sm),
                Expanded(
                  child: _preview(
                    l10n,
                    session: session,
                    document: after,
                    spread: afterSpread,
                    side: l10n.assistantAfter,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PicPacSpacing.md),
          Text(l10n.assistantChangesTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: PicPacSpacing.xxs),
          for (final entry in entries)
            _ChangeLine(
              text: editPlanEntryText(l10n, entry),
              hint: editPlanEntryHint(l10n, entry),
              emphasized: entry.removesPhoto,
            ),
          if (proposal.warnings.isNotEmpty) ...<Widget>[
            const SizedBox(height: PicPacSpacing.md),
            Text(
              l10n.assistantWarningsTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: PicPacSpacing.xxs),
            for (final issue in proposal.warnings)
              _ChangeLine(text: preflightIssueText(l10n, issue)),
          ],
          const SizedBox(height: PicPacSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: MinTapTarget(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.actionCancel),
                  ),
                ),
              ),
              const SizedBox(width: PicPacSpacing.sm),
              Expanded(
                child: MinTapTarget(
                  child: FilledButton(
                    key: const ValueKey<String>('assistant_apply'),
                    onPressed: _apply,
                    child: Text(l10n.assistantApply),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preview(
    AppLocalizations l10n, {
    required DesignSessionState session,
    required DesignDocument document,
    required Spread spread,
    required String side,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: Center(
            child: SheetScene(
              designId: widget.designId,
              document: document,
              spread: spread,
              template: session.templateOf(spread),
              spec: session.spec,
              maxSide: 512,
              semanticLabel: l10n.assistantPreviewLabel(side),
            ),
          ),
        ),
        const SizedBox(height: PicPacSpacing.xxs),
        Text(
          side,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: FunnelText.secondary),
        ),
      ],
    );
  }

  void _askFreeForm() {
    final text = _intent.text.trim();
    if (text.isEmpty) return;
    _ask(text, localOnly: false, spokenText: text);
  }

  void _retry() {
    if (_lastIntent.isEmpty) return;
    _ask(_lastIntent, localOnly: _lastLocalOnly, spokenText: _lastIntent);
  }

  Future<void> _ask(
    String intent, {
    required bool localOnly,
    required String spokenText,
  }) async {
    final session = ref.read(designSessionProvider(widget.designId)).value;
    if (session == null) return;
    final spread = session.document.spreadById(widget.spreadId);
    if (spread == null) return;

    setState(() {
      _phase = _Phase.asking;
      _failure = null;
      _lastIntent = intent;
      _lastLocalOnly = localOnly;
    });

    final request = AssistantRequest(
      designId: widget.designId,
      intent: intent,
      localeName: Localizations.localeOf(context).toLanguageTag(),
      state: session,
      spread: spread,
      images: ref.read(
        assetImageStoreProvider((designId: widget.designId, maxSide: 512)),
      ),
      cache: ref.read(designAssetCacheProvider),
      analyzer: ref.read(frameAnalyzerProvider),
      localOnly: localOnly,
    );
    final result = await ref.read(assistantServiceProvider).ask(request);
    if (!mounted) return;

    switch (result) {
      case Ok<AssistantProposal>(:final value):
        setState(() {
          _phase = _Phase.ready;
          _proposal = value;
          _failure = null;
        });
        final l10n = AppLocalizations.of(context);
        announceToScreenReader(
          context,
          l10n.assistantResultReady(value.plan.length, spokenText),
        );
      case Err<AssistantProposal>(:final error):
        setState(() {
          _phase = _Phase.failed;
          _proposal = null;
          _failure = error;
        });
    }
  }

  void _apply() {
    final proposal = _proposal;
    if (proposal == null) return;
    final controller = ref.read(
      designSessionProvider(widget.designId).notifier,
    );
    final result = controller.applyAiPatch(proposal.suggestion.patch);
    if (!mounted) return;
    switch (result) {
      case Ok<PatchResolution>():
        announceToScreenReader(
          context,
          AppLocalizations.of(context).assistantApplied,
        );
        Navigator.of(context).pop(true);
      case Err<PatchResolution>(:final error):
        setState(() {
          _phase = _Phase.failed;
          _failure = error;
          _proposal = null;
        });
    }
  }
}

class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.text, this.hint, this.emphasized = false});

  final String text;

  final String? hint;

  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = this.hint;
    return Padding(
      padding: const EdgeInsets.only(bottom: PicPacSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            emphasized ? Icons.warning_amber_rounded : Icons.check,
            size: 16,
            color: emphasized ? PicPacColors.accentText : PicPacColors.ink,
          ),
          const SizedBox(width: PicPacSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(text, style: theme.textTheme.bodyMedium),
                if (hint != null)
                  Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: FunnelText.secondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
