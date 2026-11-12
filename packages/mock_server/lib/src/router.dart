import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'context.dart';
import 'errors.dart';
import 'mock_server.dart';
import 'routes/ai.dart';
import 'routes/audit.dart';
import 'routes/auth.dart';
import 'routes/cart.dart';
import 'routes/catalog.dart';
import 'routes/designs.dart';
import 'routes/inspiration.dart';
import 'routes/mock.dart';
import 'routes/orders.dart';
import 'routes/payments.dart';
import 'routes/support.dart';
import 'routes/uploads.dart';

Router buildRouter(MockServer server) {
  final router = Router(
    notFoundHandler: (Request request) => throw Failures.routeNotFound,
  );

  router.get('/health', (Request request) {
    final ctx = contextOf(request);
    return ctx.json(<String, Object?>{
      'status': 'ok',
      'seededAt': server.seededAt,
      'now': server.clock.now().toIso8601String(),
    });
  });

  registerAuthRoutes(router, server);
  registerCatalogRoutes(router, server);
  registerUploadRoutes(router, server);
  registerDesignRoutes(router, server);
  registerInspirationRoutes(router, server);
  registerCartRoutes(router, server);
  registerOrderRoutes(router, server);
  registerPaymentRoutes(router, server);
  registerSupportRoutes(router, server);
  registerAuditRoutes(router, server);
  registerAiRoutes(router, server);
  registerMockRoutes(router, server);

  return router;
}
