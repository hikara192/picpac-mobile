import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../context.dart';
import '../errors.dart';
import '../mock_server.dart';

void registerAuditRoutes(Router router, MockServer server) {
  router.get('/v1/audit', (Request request) {
    final ctx = contextOf(request);
    ctx.requireSupport();
    final query = request.url.queryParameters;
    final actorId = query['actorId'];
    final objectType = query['objectType'];
    final objectId = query['objectId'];
    final limit = int.tryParse(query['limit'] ?? '') ?? 50;
    if (limit < 1 || limit > 500) {
      throw ApiException.validation(
        'limit must be within 1..500',
        fieldErrors: const <String, String>{'limit': 'out_of_range'},
      );
    }

    final matches = <Object?>[];
    for (
      var i = server.auditLength - 1;
      i >= 0 && matches.length < limit;
      i--
    ) {
      final entry = server.auditAt(i);
      if (actorId != null && entry.actorId != actorId) continue;
      if (objectType != null && entry.objectType != objectType) continue;
      if (objectId != null && entry.objectId != objectId) continue;
      matches.add(entry.toDto().toJson());
    }
    return ctx.json(matches);
  });
}
