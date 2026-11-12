import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../render/sheet_layout.dart';

class CropHandles extends StatelessWidget {
  const CropHandles({
    required this.layout,
    required this.slotId,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    this.visible = true,
    super.key,
  });

  final SheetLayout layout;

  final String slotId;

  final VoidCallback onStart;

  final void Function(CropCorner corner, Offset delta) onUpdate;

  final VoidCallback onEnd;

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final rect = layout.rectOf(slotId);
    if (rect.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: l10n.editorZoom,
      child: Stack(
        children: <Widget>[
          for (final entry in layout.handlesOf(slotId).entries)
            _Handle(
              corner: entry.key,
              position: entry.value,
              area: layout.area,
              label: l10n.editorCropHandle(_cornerName(l10n, entry.key)),
              onStart: onStart,
              onUpdate: (delta) => onUpdate(entry.key, delta),
              onEnd: onEnd,
            ),
        ],
      ),
    );
  }

  static String _cornerName(AppLocalizations l10n, CropCorner corner) =>
      switch (corner) {
        CropCorner.topLeft => l10n.editorCornerTopLeft,
        CropCorner.topRight => l10n.editorCornerTopRight,
        CropCorner.bottomLeft => l10n.editorCornerBottomLeft,
        CropCorner.bottomRight => l10n.editorCornerBottomRight,
      };
}

class _Handle extends StatefulWidget {
  const _Handle({
    required this.corner,
    required this.position,
    required this.area,
    required this.label,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final CropCorner corner;
  final Offset position;

  final Size area;
  final String label;
  final VoidCallback onStart;
  final void Function(Offset delta) onUpdate;
  final VoidCallback onEnd;

  @override
  State<_Handle> createState() => _HandleState();
}

class _HandleState extends State<_Handle> {
  Offset _origin = Offset.zero;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    const size = kMinTouchTarget;
    final left = (widget.position.dx - size / 2)
        .clamp(0.0, (widget.area.width - size).clamp(0.0, double.infinity))
        .toDouble();
    final top = (widget.position.dy - size / 2)
        .clamp(0.0, (widget.area.height - size).clamp(0.0, double.infinity))
        .toDouble();
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: Semantics(
        slider: false,
        container: true,
        label: widget.label,
        onIncrease: () =>
            widget.onUpdate(Offset(widget.corner.dx, widget.corner.dy) * 12),
        onDecrease: () =>
            widget.onUpdate(Offset(-widget.corner.dx, -widget.corner.dy) * 12),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            _origin = details.localPosition;
            _dragging = true;
            widget.onStart();
          },
          onPanUpdate: (details) {
            if (!_dragging) return;
            widget.onUpdate(details.localPosition - _origin);
          },
          onPanEnd: (details) {
            if (!_dragging) return;
            _dragging = false;
            widget.onEnd();
          },
          onPanCancel: () {
            if (!_dragging) return;
            _dragging = false;
            widget.onEnd();
          },
          child: Center(
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: PicPacColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: PicPacColors.accent, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
