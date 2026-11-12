import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/di.dart';
import 'ai_router.dart';
import 'http_ai.dart';
import 'mock_ai.dart';

final aiRouterProvider = Provider<AiRouter>((ref) {
  final env = ref.watch(envProvider);
  final api = ref.watch(apiPortProvider);
  return AiRouter(
    remote: HttpAi(api: api),
    local: const MockAi(),
    enabled: env.aiEnabled,
  );
});
