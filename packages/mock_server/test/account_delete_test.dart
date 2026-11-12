import 'package:api_contract/api_contract.dart';
import 'package:mock_server/mock_server.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late MockApi api;
  late String token;

  setUp(() async {
    api = MockApi();
    token = await api.login();
  });

  test('DELETE /me cascades and anonymises the audit trail', () async {
    final design = await api.createPrintDesign(token);
    final cart = await api.addToCart(token, design['id']! as String);
    final order = await api.checkout(
      token,
      cartId: cart['id']! as String,
      idempotencyKey: 'delete-order',
    );
    expect(order.status, 201, reason: order.text);
    final orderId = order.object['id']! as String;

    final ticket = await api.call(
      'POST',
      '/v1/support/tickets',
      token: token,
      headers: <String, String>{'idempotency-key': 'delete-ticket'},
      body: <String, Object?>{
        'subject': 'Удаление аккаунта',
        'body': 'Проверка каскада',
        'type': 'other',
      },
    );
    expect(ticket.status, 201, reason: ticket.text);

    final upload = await api.call(
      'POST',
      '/v1/uploads/presign',
      token: token,
      body: <String, Object?>{
        'fileName': 'photo.jpg',
        'mimeType': 'image/jpeg',
        'bytes': 1024,
        'sha256': List<String>.filled(64, 'e').join(),
      },
    );
    expect(upload.status, 200);

    expect(api.server.designs, isNotEmpty);
    expect(api.server.orders, isNotEmpty);
    expect(api.server.tickets, isNotEmpty);
    expect(api.server.uploads, isNotEmpty);

    final deleted = await api.call('DELETE', '/v1/me', token: token);
    expect(deleted.status, 204, reason: deleted.text);

    expect(api.server.designs, isEmpty);
    expect(api.server.orders, isEmpty);
    expect(api.server.tickets, isEmpty);
    expect(api.server.uploads, isEmpty);
    expect(api.server.intents, isEmpty);
    expect(api.server.receipts, isEmpty);
    expect(api.server.carts, isEmpty);
    expect(api.server.customerById('cus_demo')!.deleted, isTrue);

    final stale = await api.call('GET', '/v1/me', token: token);
    expectError(stale, 401, ApiErrorCode.unauthorized);

    final support = await api.loginSupport();
    final anonymized = MockServer.anonymizedActorId('cus_demo');
    final audit = await api.call('GET', '/v1/audit?limit=200', token: support);
    expect(audit.status, 200, reason: audit.text);
    final records = <AuditRecord>[
      for (final raw in audit.list)
        AuditRecord.fromJson((raw! as Map).cast<String, Object?>()),
    ];
    expect(records.any((record) => record.actorId == anonymized), isTrue);
    expect(records.any((record) => record.actorId == 'cus_demo'), isFalse);
    expect(audit.text, isNot(contains('+375291234567')));
    expect(records.any((record) => record.action == 'account.delete'), isTrue);

    final supportOrder = await api.call(
      'GET',
      '/v1/orders/$orderId',
      token: support,
    );
    expectError(supportOrder, 404, ApiErrorCode.notFound);
  });

  test(
    'a guest can delete the anonymous session without touching customers',
    () async {
      final guest = await api.anonymous();
      final deleted = await api.call('DELETE', '/v1/me', token: guest);
      expect(deleted.status, 204);
      final stale = await api.call('GET', '/v1/me', token: guest);
      expectError(stale, 401, ApiErrorCode.unauthorized);
      expect(api.server.customerById('cus_demo')!.deleted, isFalse);
    },
  );
}
