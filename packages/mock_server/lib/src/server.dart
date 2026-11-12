import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'clock.dart';
import 'context.dart';
import 'errors.dart';
import 'mock_server.dart';
import 'records.dart';
import 'router.dart';
import 'routes/payments.dart';

Handler createHandler(MockServer server) {
  final router = buildRouter(server);

  return (Request request) async {
    final requestId = server.newRequestId();
    SessionRecord? session;
    ApiException? authFailure;

    final authorization = _header(request, 'authorization');
    if (authorization != null) {
      try {
        session = server.authenticate(_bearerToken(authorization));
      } on ApiException catch (error) {
        authFailure = error;
      }
    }

    final ctx = MockContext(
      server: server,
      request: request,
      requestId: requestId,
      session: session,
    );

    Response response;
    try {
      if (authFailure != null) throw authFailure;
      applyDueWebhooks(server);
      final routed = request.change(
        context: <String, Object?>{...request.context, mockContextKey: ctx},
      );
      response = await router.call(routed);
    } on ApiException catch (error) {
      response = ctx.json(
        error.toJson(requestId),
        status: error.statusCode,
        headers: error.headers,
      );
    } on ApiFailure catch (failure) {
      response = ctx.json(
        ApiException.validation(
          failure.message,
          fieldErrors: <String, String>{'body': failure.code},
        ).toJson(requestId),
        status: 422,
      );
    } on DesignFormatException catch (failure) {
      response = ctx.json(
        ApiException.validation(
          failure.message,
          fieldErrors: <String, String>{'document': failure.code},
        ).toJson(requestId),
        status: 422,
      );
    } catch (error) {
      server.log(
        '[$requestId] unhandled ${error.runtimeType} on '
        '${request.method} /${request.url.path}',
      );
      response = ctx.json(
        Failures.internal.toJson(requestId),
        status: Failures.internal.statusCode,
      );
    }

    final finished = response.change(
      headers: <String, String>{
        ...response.headers,
        'x-request-id': requestId,
        'cache-control': 'no-store',
      },
    );
    server.log(
      '$requestId ${request.method} /${request.url.path} '
      '${finished.statusCode}',
    );
    return finished;
  };
}

Future<HttpServer> startMockServer({
  int port = 8080,
  String? seedPath,
  Clock? clock,
  InternetAddress? address,
  void Function(String line)? logSink,
}) async {
  final server = MockServer(
    clock: clock ?? const SystemClock(),
    seedPath: seedPath,
    logSink: logSink,
  );
  final handler = createHandler(server);
  return shelf_io.serve(handler, address ?? InternetAddress.loopbackIPv4, port);
}

String? _header(Request request, String name) {
  final lower = name.toLowerCase();
  return request.headers[lower] ?? request.headers[name];
}

String _bearerToken(String header) {
  final parts = header.trim().split(RegExp(r'\s+'));
  if (parts.length != 2 || parts.first.toLowerCase() != 'bearer') {
    throw ApiException.unauthorized('malformed Authorization header');
  }
  return parts.last;
}
