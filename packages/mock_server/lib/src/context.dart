import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:api_contract/api_contract.dart';
import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';

import 'errors.dart';
import 'mock_server.dart';
import 'records.dart';

final class MockContext {
  MockContext({
    required this.server,
    required this.request,
    required this.requestId,
    this.session,
  });

  final MockServer server;

  final Request request;

  final String requestId;

  final SessionRecord? session;

  String get origin => request.requestedUri.origin;

  String? header(String name) {
    final lower = name.toLowerCase();
    return request.headers[lower] ?? request.headers[name];
  }

  String get clientIp {
    final info = request.context['shelf.io.connection_info'];
    if (info is HttpConnectionInfo) {
      try {
        final address = info.remoteAddress.address;
        if (address.isNotEmpty) return address;
      } on StateError {
      }
    }
    final forwarded = header('x-forwarded-for')?.split(',').first.trim();
    if (forwarded != null && forwarded.isNotEmpty) return forwarded;
    return 'local';
  }

  List<int>? _bodyBytes;
  String? _bodyText;

  Future<List<int>> bodyBytes({int maxBytes = 1 << 20}) async {
    final cached = _bodyBytes;
    if (cached != null) return cached;
    final declared = request.contentLength;
    if (declared != null && declared > maxBytes) throw Failures.payloadTooLarge;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request.read()) {
      builder.add(chunk);
      if (builder.length > maxBytes) throw Failures.payloadTooLarge;
    }
    final bytes = builder.takeBytes();
    _bodyBytes = bytes;
    return bytes;
  }

  Future<String> bodyText({int maxBytes = 1 << 20}) async {
    final cached = _bodyText;
    if (cached != null) return cached;
    final bytes = await bodyBytes(maxBytes: maxBytes);
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw Failures.invalidJson;
    }
    _bodyText = text;
    return text;
  }

  JsonMap? _json;

  Future<JsonMap> jsonBody({int maxBytes = 1 << 20}) async {
    final cached = _json;
    if (cached != null) return cached;
    final text = await bodyText(maxBytes: maxBytes);
    if (text.trim().isEmpty) {
      _json = <String, Object?>{};
      return _json!;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw Failures.invalidJson;
    }
    final Map<String, Object?> map;
    if (decoded is Map<String, Object?>) {
      map = decoded;
    } else if (decoded is Map) {
      map = decoded.cast<String, Object?>();
    } else {
      throw Failures.invalidJson;
    }
    _json = map;
    return map;
  }

  Future<({int bytes, String sha256, List<int> prefix})> readVerifiableBinary({
    required int maxBytes,
    int prefixLength = 8,
  }) async {
    final digestSink = _DigestCollector();
    final input = sha256.startChunkedConversion(digestSink);
    final prefix = <int>[];
    var total = 0;
    await for (final chunk in request.read()) {
      total += chunk.length;
      if (total > maxBytes) {
        input.close();
        throw Failures.payloadTooLarge;
      }
      if (prefix.length < prefixLength) {
        final take = prefixLength - prefix.length;
        prefix.addAll(chunk.length <= take ? chunk : chunk.sublist(0, take));
      }
      input.add(chunk);
    }
    input.close();
    final digest = digestSink.digest;
    if (digest == null) throw Failures.internal;
    return (bytes: total, sha256: digest.toString(), prefix: prefix);
  }

  SessionRecord requireSession() {
    final current = session;
    if (current == null) throw ApiException.unauthorized();
    return current;
  }

  CustomerRecord requireUser({bool allowGuest = true}) {
    final current = requireSession();
    final customer = server.customerById(current.customerId);
    if (customer == null || customer.deleted) {
      throw ApiException.unauthorized('the account is no longer available');
    }
    if (!allowGuest && customer.isGuest) {
      throw ApiException.forbidden(
        'sign in to a customer account to continue: guest sessions cannot '
        'place orders',
      );
    }
    return customer;
  }

  CustomerRecord requireCustomer() {
    final current = requireSession();
    final customer = requireUser(allowGuest: false);
    if (current.role != UserRole.customer) {
      throw ApiException.forbidden(
        'a customer account is required for this operation',
      );
    }
    return customer;
  }

  SessionRecord requireSupport() {
    final current = requireSession();
    if (current.role != UserRole.supportAgent) {
      throw ApiException.forbidden('support role is required');
    }
    return current;
  }

  void requireMockControl() {
    if (server.allowAnonymousMockControls) return;
    requireSupport();
  }

  void audit({
    required String action,
    required String objectType,
    required String objectId,
    String result = 'success',
    Map<String, Object?> details = const <String, Object?>{},
    ActorRole? actorRole,
    String? actorId,
  }) {
    server.audit(
      action: action,
      objectType: objectType,
      objectId: objectId,
      result: result,
      actorRole: actorRole ?? MockServer.actorRoleOf(session),
      actorId: actorId ?? session?.customerId,
      details: details,
    );
  }

  Response json(
    Object? body, {
    int status = 200,
    Map<String, String> headers = const <String, String>{},
  }) => Response(
    status,
    body: jsonEncode(body),
    headers: <String, String>{
      'content-type': 'application/json; charset=utf-8',
      ...headers,
    },
  );

  Response noContent() => Response(204);

  Response html(
    String body, {
    int status = 200,
    Map<String, String> headers = const <String, String>{},
  }) => Response(
    status,
    body: body,
    headers: <String, String>{
      'content-type': 'text/html; charset=utf-8',
      'x-frame-options': 'DENY',
      'referrer-policy': 'no-referrer',
      'content-security-policy':
          "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'",
      ...headers,
    },
  );
}

String maskPhoneLast4(String last4) => '***$last4';

final class _DigestCollector implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}

const String mockContextKey = 'mock.context';

MockContext contextOf(Request request) {
  final context = request.context[mockContextKey];
  if (context is! MockContext) {
    throw StateError('request was not created by createHandler');
  }
  return context;
}

String digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

String escapeHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
