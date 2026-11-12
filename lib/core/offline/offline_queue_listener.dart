import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_queue.dart';

class OfflineQueueListener extends ConsumerStatefulWidget {
  const OfflineQueueListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<OfflineQueueListener> createState() =>
      _OfflineQueueListenerState();
}

class _OfflineQueueListenerState extends ConsumerState<OfflineQueueListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _retry());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _retry();
  }

  void _retry() {
    if (!mounted) return;
    final pending = ref.read(pendingActionsControllerProvider).value;
    if (pending == null || pending.isEmpty) return;
    unawaited(ref.read(pendingActionsControllerProvider.notifier).run());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
