import 'dart:io';

import 'package:design_core/design_core.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../_shared/application/design_session.dart';
import '../../../_shared/application/media_providers.dart';
import '../../../../core/presentation/a11y.dart';
import '../../../_shared/presentation/photo_reveal.dart';
import '../../../../core/presentation/text_tones.dart';
import '../../application/editor_tools.dart';

final adjustmentLimitLookupProvider =
    Provider<AdjustmentLimit Function(PhotoAdjustmentField)>(
      (ref) => AdjustmentLimits.of,
    );

class EditorToolPanel extends StatelessWidget {
  const EditorToolPanel({
    required this.designId,
    required this.tool,
    required this.state,
    required this.spread,
    required this.slot,
    required this.onAddPhotos,
    this.swapFromIndex,
    this.onCancelSwap,
    super.key,
  });

  final String designId;

  final EditorTool tool;

  final DesignSessionState state;

  final Spread spread;

  final Slot? slot;

  final VoidCallback onAddPhotos;

  final int? swapFromIndex;

  final VoidCallback? onCancelSwap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = switch (tool) {
      EditorTool.frame => _FramePanel(
        designId: designId,
        spread: spread,
        slot: slot,
      ),
      EditorTool.light => _TonePanel(
        designId: designId,
        slot: slot,
        field: PhotoAdjustmentField.exposure,
        title: l10n.editorToolLight,
        hint: l10n.editorLightHint,
        icon: Icons.wb_sunny_outlined,
        format: (value) => l10n.editorLightValue(_signedDecimal(value)),
        semantic: (value) => l10n.editorLightValue(_signedDecimal(value)),
      ),
      EditorTool.warmth => _TonePanel(
        designId: designId,
        slot: slot,
        field: PhotoAdjustmentField.temperature,
        title: l10n.editorToolWarmth,
        hint: l10n.editorWarmthHint,
        icon: Icons.thermostat,
        format: (value) => l10n.editorWarmthValue(_signedWhole(value)),
        semantic: (value) => l10n.editorWarmthValue(_signedWhole(value)),
      ),
      EditorTool.style => _StylePanel(designId: designId, state: state),
      EditorTool.replace => _ReplacePanel(
        designId: designId,
        spread: spread,
        slot: slot,
        state: state,
        onAddPhotos: onAddPhotos,
      ),
      EditorTool.background => _BackgroundPanel(
        designId: designId,
        spread: spread,
      ),
      EditorTool.rotate => _RotatePanel(
        designId: designId,
        spread: spread,
        slot: slot,
      ),
      EditorTool.swap => _SwapPanel(
        swapFromIndex: swapFromIndex,
        onCancel: onCancelSwap,
      ),
    };

    return Container(
      decoration: const BoxDecoration(
        color: PicPacColors.surface,
        border: Border(top: BorderSide(color: PicPacColors.border)),
      ),
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.fromLTRB(
        PicPacSpacing.lg,
        PicPacSpacing.sm,
        PicPacSpacing.lg,
        PicPacSpacing.md,
      ),
      child: content,
    );
  }
}

class _FramePanel extends ConsumerWidget {
  const _FramePanel({
    required this.designId,
    required this.spread,
    required this.slot,
  });

  final String designId;
  final Spread spread;
  final Slot? slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = slot;
    if (selected == null || selected.photoId == null) {
      return _PanelHint(text: l10n.editorNoPhotoSelected);
    }
    final controller = ref.read(designSessionProvider(designId).notifier);
    void setZoom(double zoom) {
      controller.execute(
        SetCrop(
          spreadId: spread.id,
          slotId: selected.id,
          crop: selected.crop,
          zoom: zoom,
          anchor: selected.anchor,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.zoom_in, size: 20, color: FunnelText.secondary),
            Expanded(
              child: Slider(
                value: selected.zoom.clamp(Slot.minZoom, Slot.maxZoom),
                min: Slot.minZoom,
                max: Slot.maxZoom,
                divisions: 28,
                label: NumberFormat('0.#', 'ru').format(selected.zoom),
                semanticFormatterCallback: (value) => sliderSemanticValue(
                  l10n,
                  l10n.editorToolFrame,
                  l10n.editorZoomValue(NumberFormat('0.#', 'ru').format(value)),
                ),
                onChangeStart: (_) => controller.beginGesture('gesture.zoom'),
                onChanged: setZoom,
                onChangeEnd: (_) => controller.endGesture(),
              ),
            ),
            Text(
              l10n.editorZoomValue(
                NumberFormat('0.#', 'ru').format(selected.zoom),
              ),
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
        MinTapTarget(
          child: OutlinedButton.icon(
            onPressed: () {
              controller.beginGesture('gesture.center');
              controller.execute(
                SetCrop(
                  spreadId: spread.id,
                  slotId: selected.id,
                  crop: selected.crop,
                  zoom: selected.zoom,
                  anchor: NormalizedPoint.center,
                ),
              );
              controller.endGesture();
            },
            icon: const Icon(Icons.center_focus_strong_outlined, size: 20),
            label: Text(l10n.editorCenter),
          ),
        ),
      ],
    );
  }
}

class _TonePanel extends ConsumerWidget {
  const _TonePanel({
    required this.designId,
    required this.slot,
    required this.field,
    required this.title,
    required this.hint,
    required this.icon,
    required this.format,
    required this.semantic,
  });

  final String designId;
  final Slot? slot;
  final PhotoAdjustmentField field;
  final String title;
  final String hint;
  final IconData icon;
  final String Function(double value) format;
  final String Function(double value) semantic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final photoId = slot?.photoId;
    if (photoId == null) {
      return _PanelHint(text: l10n.editorNoPhotoSelected);
    }
    final limit = ref.watch(adjustmentLimitLookupProvider)(field);
    final min = limit.uiLower;
    final max = limit.uiUpper;
    final divisions = ((max - min) / limit.step).round();
    final adjustment = ref
        .watch(designSessionProvider(designId))
        .value
        ?.document
        .adjustmentFor(photoId);
    final value = (adjustment?.valueOf(field) ?? 0).clamp(min, max).toDouble();
    final controller = ref.read(designSessionProvider(designId).notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 20, color: FunnelText.secondary),
            const SizedBox(width: PicPacSpacing.sm),
            Expanded(child: Text(title, style: theme.textTheme.labelLarge)),
            Text(format(value), style: theme.textTheme.labelMedium),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions > 0 ? divisions : null,
          label: format(value),
          semanticFormatterCallback: (next) =>
              sliderSemanticValue(l10n, title, semantic(next)),
          onChangeStart: (_) =>
              controller.beginGesture('gesture.${field.wire}'),
          onChanged: (next) => controller.execute(
            SetPhotoAdjustment(photoId: photoId, field: field, value: next),
          ),
          onChangeEnd: (_) => controller.endGesture(),
        ),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: FunnelText.secondary,
          ),
        ),
      ],
    );
  }
}

class _StylePanel extends ConsumerStatefulWidget {
  const _StylePanel({required this.designId, required this.state});

  final String designId;
  final DesignSessionState state;

  @override
  ConsumerState<_StylePanel> createState() => _StylePanelState();
}

class _StylePanelState extends ConsumerState<_StylePanel> {
  double _strength = 1;

  @override
  void initState() {
    super.initState();
    final photos = widget.state.document.assets;
    if (photos.isNotEmpty) {
      final look = widget.state.document.adjustmentFor(photos.first.id).look;
      if (look != null) _strength = look.strength;
    }
  }

  DesignSessionController get _controller =>
      ref.read(designSessionProvider(widget.designId).notifier);

  List<String> get _photoIds => <String>[
    for (final asset in widget.state.document.assets) asset.id,
  ];

  void _pick(String? lookId) {
    final ids = _photoIds;
    if (ids.isEmpty) return;
    if (lookId == null || lookId == LookLibrary.neutralId) {
      _controller.execute(
        CompositeCommand(<DesignCommand>[
          for (final photoId in ids) SetLook(photoId: photoId, look: null),
        ], label: 'clearLook'),
      );
      return;
    }
    _controller.execute(
      ApplyLook(photoIds: ids, lookId: lookId, strength: _strength),
    );
  }

  void _setStrength(double value) {
    setState(() => _strength = value);
    final applied = _appliedId;
    if (applied == null) return;
    _controller.execute(
      ApplyLook(photoIds: _photoIds, lookId: applied, strength: value),
    );
  }

  String? get _appliedId {
    final photos = widget.state.document.assets;
    if (photos.isEmpty) return null;
    final id = widget.state.document.adjustmentFor(photos.first.id).look?.id;
    return id == LookLibrary.neutralId ? null : id;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final applied = _appliedId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final preset in LookLibrary.presets)
                _LookChip(
                  label: _lookLabel(l10n, preset.id),
                  selected: preset.id == LookLibrary.neutralId
                      ? applied == null
                      : applied == preset.id,
                  onTap: () => _pick(preset.id),
                  child: preset.id == LookLibrary.neutralId
                      ? const Icon(
                          Icons.block,
                          size: 16,
                          color: PicPacColors.muted,
                        )
                      : _LookSwatch(presetId: preset.id),
                ),
            ],
          ),
        ),
        Row(
          children: <Widget>[
            Text(
              l10n.editorStyleStrength,
              style: theme.textTheme.labelMedium?.copyWith(
                color: FunnelText.secondary,
              ),
            ),
            Expanded(
              child: Slider(
                value: _strength,
                divisions: 10,
                label: '${(_strength * 100).round()}%',
                semanticFormatterCallback: (value) => sliderSemanticValue(
                  l10n,
                  l10n.editorStyleStrength,
                  '${(value * 100).round()}%',
                ),
                onChangeStart: applied == null
                    ? null
                    : (_) => _controller.beginGesture('gesture.look'),
                onChanged: applied == null ? null : _setStrength,
                onChangeEnd: applied == null
                    ? null
                    : (_) => _controller.endGesture(),
              ),
            ),
            Text(
              '${(_strength * 100).round()}%',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ],
    );
  }
}

class _RotatePanel extends ConsumerWidget {
  const _RotatePanel({
    required this.designId,
    required this.spread,
    required this.slot,
  });

  final String designId;
  final Spread spread;
  final Slot? slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = slot;
    if (selected == null || selected.photoId == null) {
      return _PanelHint(text: l10n.editorNoPhotoSelected);
    }
    final controller = ref.read(designSessionProvider(designId).notifier);
    void orient({required int rotation, required bool flipH}) {
      controller.execute(
        SetSlotOrientation(
          spreadId: spread.id,
          slotId: selected.id,
          rotation: rotation,
          flipH: flipH,
        ),
      );
    }

    final rotate = OutlinedButton.icon(
      onPressed: () => orient(
        rotation: (selected.rotation.degrees + 90) % 360,
        flipH: selected.flipH,
      ),
      icon: const Icon(Icons.rotate_90_degrees_cw, size: 20),
      label: Text(l10n.editorRotateCw, textAlign: TextAlign.center),
    );
    final flip = OutlinedButton.icon(
      onPressed: () =>
          orient(rotation: selected.rotation.degrees, flipH: !selected.flipH),
      icon: const Icon(Icons.flip, size: 20),
      label: Text(l10n.editorFlip, textAlign: TextAlign.center),
    );
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 20;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.editorRotateHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: FunnelText.secondary,
          ),
        ),
        const SizedBox(height: PicPacSpacing.xs),
        if (stacked) ...<Widget>[
          MinTapTarget(child: rotate),
          const SizedBox(height: PicPacSpacing.sm),
          MinTapTarget(child: flip),
        ] else
          Row(
            children: <Widget>[
              Expanded(child: MinTapTarget(child: rotate)),
              const SizedBox(width: PicPacSpacing.sm),
              Expanded(child: MinTapTarget(child: flip)),
            ],
          ),
      ],
    );
  }
}

class _SwapPanel extends StatelessWidget {
  const _SwapPanel({required this.swapFromIndex, required this.onCancel});

  final int? swapFromIndex;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final from = swapFromIndex;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            from == null
                ? l10n.editorSwapPickFirst
                : l10n.editorSwapPickSecond(from),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: FunnelText.secondary,
            ),
          ),
        ),
        if (from != null && onCancel != null)
          TextButton(onPressed: onCancel, child: Text(l10n.actionCancel)),
      ],
    );
  }
}

class _ReplacePanel extends ConsumerWidget {
  const _ReplacePanel({
    required this.designId,
    required this.spread,
    required this.slot,
    required this.state,
    required this.onAddPhotos,
  });

  final String designId;
  final Spread spread;
  final Slot? slot;
  final DesignSessionState state;
  final VoidCallback onAddPhotos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final target = slot;
    final assets = state.document.assets;
    final controller = ref.read(designSessionProvider(designId).notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.editorReplaceTitle,
          style: theme.textTheme.labelLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: PicPacSpacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _AddPhotoTile(label: l10n.createAddPhotos, onTap: onAddPhotos),
              for (var index = 0; index < assets.length; index++)
                _AssetTile(
                  designId: designId,
                  asset: assets[index],
                  index: index,
                  selected: target?.photoId == assets[index].id,
                  onTap: target == null
                      ? null
                      : () => controller.execute(
                          AssignPhoto(
                            spreadId: spread.id,
                            slotId: target.id,
                            photoId: assets[index].id,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BackgroundPanel extends ConsumerWidget {
  const _BackgroundPanel({required this.designId, required this.spread});

  final String designId;
  final Spread spread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(designSessionProvider(designId).notifier);
    final options = <({String hex, String label, Color color})>[
      (
        hex: '#FFFFFF',
        label: l10n.editorBackgroundPaper,
        color: const Color(0xFFFFFFFF),
      ),
      (
        hex: '#FAF5ED',
        label: l10n.editorBackgroundCream,
        color: PicPacColors.background,
      ),
      (
        hex: '#C4DAD6',
        label: l10n.editorBackgroundMint,
        color: PicPacColors.fillMint,
      ),
      (
        hex: '#EDE1D5',
        label: l10n.editorBackgroundBeige,
        color: PicPacColors.fillBeige,
      ),
    ];
    final current = spread.background.value.toUpperCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.editorBackgroundTitle,
          style: theme.textTheme.labelLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: PicPacSpacing.xs),
        Row(
          children: <Widget>[
            for (final option in options)
              Expanded(
                child: _BackgroundSwatch(
                  label: option.label,
                  color: option.color,
                  selected: current == option.hex,
                  onTap: () => controller.execute(
                    SetBackground(
                      spreadId: spread.id,
                      background: SpreadBackground.color(option.hex),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BackgroundSwatch extends StatelessWidget {
  const _BackgroundSwatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PicPacRadii.field),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTouchTarget),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? PicPacColors.accent : PicPacColors.border,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 18, color: PicPacColors.ink)
                    : null,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: FunnelText.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LookChip extends StatelessWidget {
  const _LookChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PicPacRadii.field),
        child: SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: PicPacColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(PicPacRadii.sm),
                    border: Border.all(
                      color: selected
                          ? PicPacColors.accent
                          : PicPacColors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox.expand(child: child),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? PicPacColors.ink : FunnelText.secondary,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssetTile extends ConsumerWidget {
  const _AssetTile({
    required this.designId,
    required this.asset,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final String designId;
  final PhotoAsset asset;
  final int index;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cache = ref.watch(designAssetCacheProvider);
    return Padding(
      padding: const EdgeInsets.only(right: PicPacSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        label: l10n.createPhotoNumber(index + 1),
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PicPacRadii.sm),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PicPacRadii.sm),
              border: Border.all(
                color: selected ? PicPacColors.ink : PicPacColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: FutureBuilder<File?>(
              future: cache.fileFor(designId, asset.sha256),
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file == null) {
                  return const ColoredBox(color: PicPacColors.fillStone);
                }
                return PhotoReveal(
                  child: Image.file(
                    file,
                    fit: BoxFit.cover,
                    cacheWidth: 192,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (context, error, stack) =>
                        const ColoredBox(color: PicPacColors.fillStone),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final factor = MediaQuery.textScalerOf(context).scale(12) / 12;
    final width = 72 * factor.clamp(1.0, 2.0);
    return Padding(
      padding: const EdgeInsets.only(right: PicPacSpacing.sm),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PicPacRadii.sm),
          child: Container(
            width: width,
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(vertical: PicPacSpacing.xs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PicPacRadii.sm),
              border: Border.all(color: PicPacColors.border),
              color: PicPacColors.surfaceMuted,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 20,
                  color: PicPacColors.ink,
                ),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelHint extends StatelessWidget {
  const _PanelHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: FunnelText.secondary,
        ),
      ),
    );
  }
}

String _lookLabel(AppLocalizations l10n, String id) => switch (id) {
  LookLibrary.neutralId => l10n.lookAsIs,
  'warm' => l10n.lookWarm,
  'film' => l10n.lookFilm,
  'bright' => l10n.lookBright,
  'soft' => l10n.lookSoft,
  'mono' => l10n.lookMono,
  _ => id,
};

class _LookSwatch extends StatelessWidget {
  const _LookSwatch({required this.presetId});

  final String presetId;

  @override
  Widget build(BuildContext context) {
    final colors = _swatchColors[presetId] ?? _neutralSwatch;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

const Map<String, List<Color>> _swatchColors = <String, List<Color>>{
  'warm': <Color>[Color(0xFFF6D8B8), Color(0xFFE9A97A)],
  'film': <Color>[Color(0xFFE6DCC8), Color(0xFFB9A98C)],
  'bright': <Color>[Color(0xFFCDE3D9), Color(0xFF7FB39F)],
  'soft': <Color>[Color(0xFFF3E4E4), Color(0xFFD9BFBF)],
  'mono': <Color>[Color(0xFFD9D9D9), Color(0xFF6E6E6E)],
};

const List<Color> _neutralSwatch = <Color>[
  Color(0xFFFAF7F7),
  Color(0xFFEFECE8),
];

String _signedDecimal(double value) =>
    NumberFormat('+0.0;-0.0;0.0', 'ru').format(value);

String _signedWhole(double value) =>
    NumberFormat('+0;-0;0', 'ru').format(value);
