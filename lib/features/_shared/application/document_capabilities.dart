import 'package:flutter_riverpod/flutter_riverpod.dart';

final class DocumentCapabilities {
  const DocumentCapabilities({
    this.rotate = true,
    this.swap = true,
    this.layoutPlanner = true,
  });

  final bool rotate;

  final bool swap;

  final bool layoutPlanner;
}

final Provider<DocumentCapabilities> documentCapabilitiesProvider =
    Provider<DocumentCapabilities>((ref) => const DocumentCapabilities());
