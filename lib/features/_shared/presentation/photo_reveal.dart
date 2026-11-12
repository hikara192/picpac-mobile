import 'package:flutter/material.dart';

import '../../../app/motion.dart';

class PhotoReveal extends StatefulWidget {
  const PhotoReveal({required this.child, super.key});

  final Widget child;

  @override
  State<PhotoReveal> createState() => _PhotoRevealState();
}

class _PhotoRevealState extends State<PhotoReveal> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final duration = motionDuration(context, Motion.reveal);
    if (duration == Duration.zero) return widget.child;
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: duration,
      curve: Motion.easeOutCubic,
      child: AnimatedScale(
        scale: _shown ? 1 : 0.98,
        duration: duration,
        curve: Motion.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
