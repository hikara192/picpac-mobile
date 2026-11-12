import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

enum EmptyMotif {
  heart,

  arrow,

  stroke,

  prints;

  static EmptyMotif forIcon(IconData icon) {
    if (icon == Icons.favorite_border || icon == Icons.favorite) {
      return EmptyMotif.heart;
    }
    if (icon == Icons.search_off || icon == Icons.explore_outlined) {
      return EmptyMotif.arrow;
    }
    if (icon == Icons.photo_library_outlined ||
        icon == Icons.photo_album_outlined ||
        icon == Icons.photo_outlined ||
        icon == Icons.inbox_outlined ||
        icon == Icons.shopping_bag_outlined ||
        icon == Icons.storefront_outlined ||
        icon == Icons.receipt_long_outlined) {
      return EmptyMotif.prints;
    }
    return EmptyMotif.stroke;
  }
}

class EmptyIllustration extends StatelessWidget {
  const EmptyIllustration({
    this.motif = EmptyMotif.stroke,
    this.size = 96,
    super.key,
  });

  final EmptyMotif motif;

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _EmptyIllustrationPainter(motif)),
    ),
  );
}

class _EmptyIllustrationPainter extends CustomPainter {
  const _EmptyIllustrationPainter(this.motif);

  final EmptyMotif motif;

  static const Color _stroke = PicPacColors.accent;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    final unit = size.shortestSide / 96;
    final plate = switch (motif) {
      EmptyMotif.heart => PicPacColors.accentSoft,
      EmptyMotif.prints => PicPacColors.fillBeige,
      EmptyMotif.arrow => PicPacColors.fillMint,
      EmptyMotif.stroke => PicPacColors.fillBeige,
    };
    canvas.drawCircle(
      box.center.translate(0, 2 * unit),
      27 * unit,
      Paint()
        ..color = plate
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 * unit),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * unit
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = _stroke;

    switch (motif) {
      case EmptyMotif.heart:
        _paintHeart(canvas, box.center, unit, paint);
      case EmptyMotif.arrow:
        _paintArrow(canvas, box.center, unit, paint);
      case EmptyMotif.stroke:
        _paintStroke(canvas, box.center, unit, paint);
      case EmptyMotif.prints:
        _paintPrints(canvas, box.center, unit, paint);
    }
  }

  void _paintHeart(Canvas canvas, Offset center, double unit, Paint paint) {
    final half = 19 * unit;
    final top = center.dy - 14 * unit;
    final path = Path()
      ..moveTo(center.dx, top + 10 * unit)
      ..cubicTo(
        center.dx - 22 * unit,
        center.dy - 8 * unit,
        center.dx - half + 2 * unit,
        center.dy + 8 * unit,
        center.dx,
        center.dy + 22 * unit,
      )
      ..cubicTo(
        center.dx + half - 2 * unit,
        center.dy + 8 * unit,
        center.dx + 22 * unit,
        center.dy - 8 * unit,
        center.dx,
        top + 10 * unit,
      );
    canvas.drawPath(path, paint);
  }

  void _paintArrow(Canvas canvas, Offset center, double unit, Paint paint) {
    final start = center.translate(-20 * unit, 4 * unit);
    final end = center.translate(20 * unit, -4 * unit);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(center.dx, center.dy + 14 * unit, end.dx, end.dy);
    canvas.drawPath(path, paint);
    canvas.drawLine(end, end.translate(-10 * unit, 5 * unit), paint);
    canvas.drawLine(end, end.translate(-2 * unit, -10 * unit), paint);
  }

  void _paintStroke(Canvas canvas, Offset center, double unit, Paint paint) {
    final path = Path()
      ..moveTo(center.dx - 26 * unit, center.dy + 10 * unit)
      ..cubicTo(
        center.dx - 8 * unit,
        center.dy - 26 * unit,
        center.dx + 6 * unit,
        center.dy + 24 * unit,
        center.dx + 26 * unit,
        center.dy - 12 * unit,
      );
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      center.translate(6 * unit, -22 * unit),
      2.5 * unit,
      Paint()..color = _stroke,
    );
  }

  void _paintPrints(Canvas canvas, Offset center, double unit, Paint paint) {
    for (var index = 0; index < 3; index++) {
      final offset = Offset(-2 * unit, -3 * unit) * index.toDouble();
      final rect = Rect.fromCenter(
        center: center.translate(-6 * unit, 8 * unit) + offset,
        width: 34 * unit,
        height: 26 * unit,
      );
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate((index == 2 ? -0.10 : 0.0) + index * 0.03);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: rect.width,
            height: rect.height,
          ),
          Radius.circular(4 * unit),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_EmptyIllustrationPainter oldDelegate) =>
      oldDelegate.motif != motif;
}
