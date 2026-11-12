import 'dart:math' as math;

import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';

class TemplatePreview extends StatelessWidget {
  const TemplatePreview({
    required this.slots,
    required this.aspect,
    this.selectedSlot,
    this.semanticLabel,
    this.background = PicPacColors.surface,
    super.key,
  });

  final List<TemplateSlot> slots;

  final double aspect;

  final int? selectedSlot;

  final String? semanticLabel;

  final Color background;

  static const double insetFraction = 0.04;

  static int? slotAt(Offset position, Size size, List<TemplateSlot> slots) {
    if (slots.isEmpty || size.shortestSide <= 0) return null;
    final inset = size.shortestSide * insetFraction;
    final area = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    for (var index = 0; index < slots.length; index++) {
      final normalized = slots[index].rect;
      final rect = Rect.fromLTWH(
        area.left + normalized.x * area.width,
        area.top + normalized.y * area.height,
        normalized.w * area.width,
        normalized.h * area.height,
      );
      if (rect.contains(position)) return index;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final picture = CustomPaint(
      painter: _TemplatePreviewPainter(
        slots: slots,
        selectedSlot: selectedSlot,
        background: background,
      ),
      child: const SizedBox.expand(),
    );
    final label = semanticLabel;
    return AspectRatio(
      aspectRatio: aspect.isFinite && aspect > 0 ? aspect : 1,
      child: label == null
          ? ExcludeSemantics(child: picture)
          : Semantics(
              container: true,
              image: true,
              label: label,
              child: picture,
            ),
    );
  }
}

class _TemplatePreviewPainter extends CustomPainter {
  _TemplatePreviewPainter({
    required this.slots,
    required this.selectedSlot,
    required this.background,
  });

  final List<TemplateSlot> slots;
  final int? selectedSlot;
  final Color background;

  static const List<Color> _fills = <Color>[
    PicPacColors.fillBeige,
    PicPacColors.fillMint,
    PicPacColors.fillBlue,
    PicPacColors.fillLavender,
    PicPacColors.fillStone,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sheet = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(PicPacRadii.sm),
    );
    canvas.drawRRect(sheet, Paint()..color = background);
    if (slots.isEmpty || size.shortestSide <= 0) return;

    final inset = size.shortestSide * TemplatePreview.insetFraction;
    final area = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );

    for (var index = 0; index < slots.length; index++) {
      final normalized = slots[index].rect;
      final rect = Rect.fromLTWH(
        area.left + normalized.x * area.width,
        area.top + normalized.y * area.height,
        normalized.w * area.width,
        normalized.h * area.height,
      ).deflate(0.5);
      if (rect.width <= 0 || rect.height <= 0) continue;

      final radius = Radius.circular(math.min(4, rect.shortestSide / 4));
      final rrect = RRect.fromRectAndRadius(rect, radius);
      canvas.drawRRect(rrect, Paint()..color = _fills[index % _fills.length]);
      if (index == selectedSlot) {
        canvas.drawRRect(
          rrect.deflate(1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = PicPacColors.accent,
        );
      }
      _paintNumber(canvas, rect, index + 1);
    }
  }

  void _paintNumber(Canvas canvas, Rect rect, int number) {
    if (rect.width < 26 || rect.height < 26) return;
    const badgeRadius = 9.0;
    final center = Offset(
      rect.left + badgeRadius + 4,
      rect.top + badgeRadius + 4,
    );
    canvas.drawCircle(
      center,
      badgeRadius,
      Paint()..color = PicPacColors.surface,
    );
    final text = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          color: PicPacColors.ink,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    text.dispose();
  }

  @override
  bool shouldRepaint(_TemplatePreviewPainter oldDelegate) =>
      oldDelegate.selectedSlot != selectedSlot ||
      oldDelegate.background != background ||
      !identical(oldDelegate.slots, slots);
}
