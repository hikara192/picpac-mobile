import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../context.dart';
import '../errors.dart';
import '../mock_server.dart';

void registerMockRoutes(Router router, MockServer server) {
  if (!server.mockControlsEnabled) return;

  router.post('/v1/mock/faults', (Request request) async {
    final ctx = contextOf(request);
    ctx.requireMockControl();
    final body = await ctx.jsonBody();
    final mode = body['mode'];
    if (mode is! String || !_supportedFaults.contains(mode)) {
      throw ApiException.validation(
        'unknown fault mode',
        fieldErrors: <String, String>{
          'mode': mode is String ? 'unknown_mode' : 'required',
        },
      );
    }
    server.armFault(mode);
    ctx.audit(
      action: 'mock.fault_arm',
      objectType: 'fault',
      objectId: mode,
      actorRole: ActorRole.system,
      details: <String, Object?>{'mode': mode},
    );
    return ctx.json(<String, Object?>{'mode': mode, 'armed': true});
  });

  router.delete('/v1/mock/faults', (Request request) {
    final ctx = contextOf(request);
    ctx.requireMockControl();
    server.clearFaults();
    ctx.audit(
      action: 'mock.fault_clear',
      objectType: 'fault',
      objectId: 'all',
      actorRole: ActorRole.system,
    );
    return ctx.json(<String, Object?>{'armed': 0});
  });

  router.post('/v1/mock/reset', (Request request) {
    final ctx = contextOf(request);
    ctx.requireMockControl();
    server.reset();
    return ctx.json(<String, Object?>{
      'status': 'ok',
      'seededAt': server.seededAt,
    });
  });

  router.post('/v1/mock/auth/challenge', (Request request) async {
    final ctx = contextOf(request);
    ctx.requireMockControl();
    final body = await ctx.jsonBody();
    final accountId = body['accountId'];
    if (accountId is! String || accountId.trim().isEmpty) {
      throw ApiException.validation(
        'accountId is required',
        fieldErrors: const <String, String>{'accountId': 'required'},
      );
    }
    if (server.customers[accountId] == null) {
      throw ApiException.notFound('unknown account');
    }
    final now = server.clock.now();
    final id = server.nextId('chl');
    final challenge = ChallengeRecord(
      id: id,
      accountId: accountId,
      code: demoOneTimeCode,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
    server.challenges[id] = challenge;
    ctx.audit(
      action: 'mock.challenge_create',
      objectType: 'challenge',
      objectId: id,
      actorRole: ActorRole.system,
    );
    return ctx.json(<String, Object?>{
      'challengeId': id,
      'code': demoOneTimeCode,
      'expiresAt': challenge.expiresAt.toUtc().toIso8601String(),
    });
  });
}

const String demoOneTimeCode = '0000';

const Set<String> _supportedFaults = <String>{'upload_interrupt'};
