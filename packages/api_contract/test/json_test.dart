import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('decodeJson', () {
    test('missing required field becomes invalid_response with a path', () {
      final result = decodeJson(<String, Object?>{}, AuthSession.fromJson);
      expect(result.isErr, isTrue);
      final failure = result.failureOrNull!;
      expect(failure.code, ApiErrorCode.invalidResponse);
      expect(failure.args['path'], r'$.token');
    });

    test('wrong type becomes invalid_response, never a TypeError', () {
      final result = decodeJson(<String, Object?>{
        'token': 42,
        'role': 'customer',
      }, AuthSession.fromJson);
      expect(result.failureOrNull!.code, ApiErrorCode.invalidResponse);
      expect(result.failureOrNull!.args['path'], r'$.token');
    });

    test('unknown fields are ignored', () {
      final result = decodeJson(<String, Object?>{
        'token': 't',
        'role': 'customer',
        'futureField': <String, Object?>{'a': 1},
      }, AuthSession.fromJson);
      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      expect(result.requireValue.role, UserRole.customer);
    });

    test('array payloads keep per-item paths', () {
      final result = decodeJsonList(<Object?>[
        <String, Object?>{'id': 1},
      ], (json, path) => Customer.fromJson(json, path));
      expect(result.failureOrNull!.args['path'], r'$[0].id');
    });

    test('an unexpected crash still yields invalid_response', () {
      final result = decodeJson(<String, Object?>{}, (json) {
        throw StateError('boom');
      });
      expect(result.failureOrNull!.code, ApiErrorCode.invalidResponse);
    });

    test('document parse failures map to invalid_response with the code', () {
      final json = <String, Object?>{
        'id': 'd1',
        'revision': 1,
        'updatedAt': '2026-11-11T09:00:00Z',
        'document': <String, Object?>{'schema': 99},
      };
      final result = decodeJson(json, DesignDto.fromJson);
      final failure = result.failureOrNull!;
      expect(failure.code, ApiErrorCode.invalidResponse);
      expect(failure.args['path'], r'$.document');
      expect(failure.args['documentCode'], 'schema_too_new');
    });
  });

  group('enum fallbacks', () {
    test('unknown order status maps to unknown without throwing', () {
      final parsed = roundTrip(
        orderJson(paymentStatus: 'teleported', fulfillmentStatus: 'teleported'),
        Order.fromJson,
      );
      expect(parsed.fulfillmentStatus, OrderStatus.unknown);
      expect(parsed.paymentStatus, PaymentStatus.unknown);
      expect(parsed.hasUnknownStatus, isTrue);
      expect(parsed.toJson()['fulfillmentStatus'], 'unknown');
    });

    test('unknown role and ticket status fall back to unknown', () {
      final session = AuthSession.fromJson(<String, Object?>{
        'token': 't',
        'role': 'superuser',
      });
      expect(session.role, UserRole.unknown);

      final ticket = SupportTicket.fromJson(<String, Object?>{
        'id': 't1',
        'subject': 's',
        'type': 'telepathy',
        'status': 'limbo',
        'createdAt': '2026-11-11T09:00:00Z',
        'updatedAt': '2026-11-11T09:00:00Z',
      });
      expect(ticket.status, TicketStatus.unknown);
      expect(ticket.type, TicketType.unknown);
    });

    test('missing enum value falls back instead of failing', () {
      final json = orderJson()..remove('paymentStatus');
      final parsed = Order.fromJson(json);
      expect(parsed.paymentStatus, PaymentStatus.unknown);
    });
  });

  group('ApiFailure', () {
    test('parses a server error envelope and keeps unknown codes', () {
      final failure = ApiFailure.fromJson(<String, Object?>{
        'code': 'brand_new_code',
        'message': 'nope',
        'statusCode': 418,
        'requestId': 'r-1',
        'fieldErrors': <String, Object?>{'phone': 'invalid'},
      });
      expect(failure.code, 'brand_new_code');
      expect(failure.statusCode, 418);
      expect(failure.requestId, 'r-1');
      expect(failure.fieldErrors['phone'], 'invalid');
      expect(failure.isRetryable, isFalse);
    });

    test('a malformed error body degrades to server_error', () {
      final failure = ApiFailure.fromJson(const <String, Object?>{});
      expect(failure.code, ApiErrorCode.serverError);
      expect(failure.message, 'server error');
    });

    test('retryable and auth-related flags follow the code', () {
      expect(ApiFailure.networkUnavailable().isRetryable, isTrue);
      expect(ApiFailure.timeout().isRetryable, isTrue);
      expect(
        const ApiFailure(
          code: ApiErrorCode.conflictRevision,
          message: 'x',
        ).isRevisionConflict,
        isTrue,
      );
      expect(
        const ApiFailure(
          code: ApiErrorCode.forbidden,
          message: 'x',
        ).isAuthRelated,
        isTrue,
      );
    });
  });
}
