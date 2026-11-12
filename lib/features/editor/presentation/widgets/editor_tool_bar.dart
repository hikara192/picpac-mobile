import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/editor_tools.dart';
import '../assistant_button.dart';
import 'editor_tool_visuals.dart';

class EditorToolBar extends StatelessWidget {
  const EditorToolBar({
    required this.selected,
    required this.isEnabled,
    required this.onSelect,
    required this.onAssistant,
    required this.canAssist,
    super.key,
  });

  final EditorTool? selected;

  final bool Function(EditorTool tool) isEnabled;

  final ValueChanged<EditorTool> onSelect;

  final VoidCallback onAssistant;

  final bool canAssist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: PicPacColors.surface,
        border: Border(top: BorderSide(color: PicPacColors.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: PicPacSpacing.xxs),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: PicPacSpacing.sm),
            child: Row(
              children: <Widget>[
                for (final tool in EditorTool.values)
                  _ToolButton(
                    tool: tool,
                    selected: tool == selected,
                    enabled: isEnabled(tool),
                    label: tool.label(l10n),
                    pendingLabel: l10n.editorToolPending,
                    onTap: () => onSelect(tool),
                  ),
                AssistantToolButton(onTap: onAssistant, enabled: canAssist),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tool,
    required this.selected,
    required this.enabled,
    required this.label,
    required this.pendingLabel,
    required this.onTap,
  });

  final EditorTool tool;
  final bool selected;
  final bool enabled;
  final String label;
  final String pendingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = enabled ? PicPacColors.ink : PicPacColors.muted;
    final plate = selected ? PicPacColors.accentSoft : Colors.transparent;
    return Tooltip(
      message: enabled ? label : pendingLabel,
      child: SizedBox(
        width: 92,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: plate,
            borderRadius: BorderRadius.circular(PicPacRadii.field),
            child: InkWell(
              key: ValueKey<String>('editor_tool_${tool.name}'),
              borderRadius: BorderRadius.circular(PicPacRadii.field),
              onTap: enabled ? onTap : null,
              child: Semantics(
                button: true,
                enabled: enabled,
                selected: selected,
                label: label,
                hint: enabled ? null : pendingLabel,
                excludeSemantics: true,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 88),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PicPacRadii.field),
                    border: Border.all(
                      color: selected ? PicPacColors.ink : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: PicPacSpacing.xxs,
                    vertical: PicPacSpacing.xs,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        selected ? tool.selectedIcon : tool.icon,
                        size: 22,
                        color: foreground,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w500
                              : FontWeight.w400,
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
