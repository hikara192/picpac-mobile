import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import 'text_tones.dart';

class PicPacCard extends StatelessWidget {
  const PicPacCard({
    required this.child,
    this.padding = const EdgeInsets.all(PicPacSpacing.lg),
    this.color = PicPacColors.surface,
    this.borderColor = PicPacColors.border,
    this.radius = PicPacRadii.card,
    this.clipBehavior = Clip.none,
    super.key,
  });

  final Widget child;

  final EdgeInsetsGeometry padding;

  final Color color;

  final Color borderColor;

  final double radius;

  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: clipBehavior,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
    ),
    child: child,
  );
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.subtitle,
    this.action,
    this.center = false,
    this.titleStyle,
    super.key,
  });

  final String title;

  final String? subtitle;

  final Widget? action;

  final bool center;

  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Text(
      title,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: titleStyle ?? theme.textTheme.headlineSmall,
    );
    final body = subtitle == null
        ? null
        : Text(
            subtitle!,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: FunnelText.secondary,
            ),
          );
    if (center) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          heading,
          if (body != null) ...<Widget>[
            const SizedBox(height: PicPacSpacing.sm),
            body,
          ],
          if (action != null) ...<Widget>[
            const SizedBox(height: PicPacSpacing.xl),
            action!,
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              heading,
              if (body != null) ...<Widget>[
                const SizedBox(height: PicPacSpacing.xs),
                body,
              ],
            ],
          ),
        ),
        if (action != null) ...<Widget>[
          const SizedBox(width: PicPacSpacing.md),
          action!,
        ],
      ],
    );
  }
}
