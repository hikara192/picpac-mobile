import 'package:flutter/material.dart';

import 'tokens.dart';

@immutable
final class PicPacTheme extends ThemeExtension<PicPacTheme> {
  const PicPacTheme({
    this.spacing = PicPacSpacing.xl,
    this.cardRadius = PicPacRadii.card,
    this.fieldRadius = PicPacRadii.field,
  });

  final double spacing;
  final double cardRadius;
  final double fieldRadius;

  @override
  PicPacTheme copyWith({
    double? spacing,
    double? cardRadius,
    double? fieldRadius,
  }) => PicPacTheme(
    spacing: spacing ?? this.spacing,
    cardRadius: cardRadius ?? this.cardRadius,
    fieldRadius: fieldRadius ?? this.fieldRadius,
  );

  @override
  PicPacTheme lerp(PicPacTheme? other, double t) {
    if (other == null) return this;
    return PicPacTheme(
      spacing: _lerp(spacing, other.spacing, t),
      cardRadius: _lerp(cardRadius, other.cardRadius, t),
      fieldRadius: _lerp(fieldRadius, other.fieldRadius, t),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
