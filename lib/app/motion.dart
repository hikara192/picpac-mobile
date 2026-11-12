import 'package:flutter/material.dart';

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 120);

  static const Duration reveal = Duration(milliseconds: 180);

  static const Duration panel = Duration(milliseconds: 200);

  static const Duration screen = Duration(milliseconds: 220);

  static const Duration sheet = Duration(milliseconds: 240);

  static const Duration slow = Duration(milliseconds: 300);

  static const Curve easeOutCubic = Curves.easeOutCubic;
}

Duration motionDuration(BuildContext context, Duration duration) {
  final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return reduce ? Duration.zero : duration;
}

bool reducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
