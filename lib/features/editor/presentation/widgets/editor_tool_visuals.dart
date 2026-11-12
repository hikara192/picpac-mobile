import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/editor_tools.dart';

extension EditorToolVisuals on EditorTool {
  String label(AppLocalizations l10n) => switch (this) {
    EditorTool.frame => l10n.editorToolFrame,
    EditorTool.light => l10n.editorToolLight,
    EditorTool.warmth => l10n.editorToolWarmth,
    EditorTool.style => l10n.editorToolStyle,
    EditorTool.rotate => l10n.editorToolRotate,
    EditorTool.replace => l10n.editorToolReplace,
    EditorTool.swap => l10n.editorToolSwap,
    EditorTool.background => l10n.editorToolBackground,
  };

  IconData get icon => switch (this) {
    EditorTool.frame => Icons.crop_free,
    EditorTool.light => Icons.wb_sunny_outlined,
    EditorTool.warmth => Icons.thermostat,
    EditorTool.style => Icons.auto_awesome_outlined,
    EditorTool.rotate => Icons.rotate_90_degrees_cw,
    EditorTool.replace => Icons.photo_library_outlined,
    EditorTool.swap => Icons.swap_horiz,
    EditorTool.background => Icons.format_color_fill,
  };

  IconData get selectedIcon => switch (this) {
    EditorTool.frame => Icons.crop,
    EditorTool.light => Icons.wb_sunny,
    EditorTool.warmth => Icons.thermostat,
    EditorTool.style => Icons.auto_awesome,
    EditorTool.rotate => Icons.rotate_90_degrees_cw,
    EditorTool.replace => Icons.photo_library,
    EditorTool.swap => Icons.swap_horiz,
    EditorTool.background => Icons.format_color_fill,
  };
}
