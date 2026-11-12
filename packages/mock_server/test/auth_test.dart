import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late MockApi api;

  setUp(() => api = MockApi());

  group('anonymous sessions', () {
    test('create a guest session and expose the profile', () async {
      final response = await api.call(
        'POST',
        '/v1/auth/anonymous',
        body: <String, Object?>{'locale': 'ru', 'deviceId': 'install-1'},
      );
      expect(response.status, 200, reason: response.text);

      final session = AuthSession.fromJson(response.object);
      expect(session.role, UserRole.guest);
      expect(session.isGuest, isTrue);
      expect(session.customerId, isNotNull);
      expect(session.expiresAt, isNotNull);
      expect(
        session.expiresAt!.difference(api.clock.now()),
        const Duration(hours: 24),
      );

      final me = await api.call('GET', '/v1/me', token: session.token);
      expect(me.status, 200, reason: me.text);
      final customer = Customer.fromJson(me.object);
      expect(customer.isGuest, isTrue);
      expect(customer.email, isNull);
    });

    test('a guest cannot place an order', () async {
      final token = await api.anonymous();
      final response = await api.call(
        'POST',
        '/v1/checkout',
        token: token,
        headers: <String, String>{'idempotency-key': 'guest-key'},
        body: <String, Object?>{
          'cartId': 'cart_gone',
          'delivery': <String, Object?>{'kind': 'pickup'},
          'contact': <String, Object?>{
            'name': 'Гость',
            'phone': '+375291234567',
          },
        },
      );
      expectError(response, 403, ApiErrorCode.forbidden);
      expect(response.object['message'], contains('sign in'));
    });
  });

  group('login', () {
    test('accepts the seeded customer and support accounts', () async {
      for (final email in <String>[
        'customer@picpac.test',
        'support@picpac.test',
      ]) {
        final response = await api.call(
          'POST',
          '/v1/auth/login',
          body: <String, Object?>{'email': email, 'password': 'Test1234'},
        );
        expect(response.status, 200, reason: response.text);
        final session = AuthSession.fromJson(response.object);
        expect(session.token, isNotEmpty);
        expect(
          session.role,
          email.startsWith('support')
              ? UserRole.supportAgent
              : UserRole.customer,
        );
        expect(session.customer, isNotNull);
        expect(session.expiresAt!.isAfter(api.clock.now()), isTrue);
      }
    });

    test(
      'answers the same 401 for a wrong password and an unknown email',
      () async {
        final wrongPassword = await api.call(
          'POST',
          '/v1/auth/login',
          body: <String, Object?>{
            'email': 'customer@picpac.test',
            'password': 'wrong',
          },
        );
        final unknownEmail = await api.call(
          'POST',
          '/v1/auth/login',
          body: <String, Object?>{
            'email': 'nobody@picpac.test',
            'password': 'x',
          },
        );
        expectError(wrongPassword, 401, ApiErrorCode.unauthorized);
        expectError(unknownEmail, 401, ApiErrorCode.unauthorized);
        expect(wrongPassword.object['message'], unknownEmail.object['message']);
      },
    );

    test('five failed logins lock the email for fifteen minutes', () async {
      Future<MockResponse> attempt(String password) => api.call(
        'POST',
        '/v1/auth/login',
        headers: <String, String>{'x-forwarded-for': '198.51.100.4'},
        body: <String, Object?>{
          'email': 'customer@picpac.test',
          'password': password,
        },
      );

      for (var i = 0; i < 5; i++) {
        expectError(await attempt('wrong-$i'), 401, ApiErrorCode.unauthorized);
      }
      final limited = await attempt('Test1234');
      expectError(limited, 429, ApiErrorCode.rateLimited);
      expect(limited.object['retryAfterSeconds'], isA<int>());
      expect(limited.header('retry-after'), isNotNull);

      final otherEmail = await api.call(
        'POST',
        '/v1/auth/login',
        body: <String, Object?>{
          'email': 'support@picpac.test',
          'password': 'Test1234',
        },
      );
      expect(otherEmail.status, 200, reason: otherEmail.text);

      api.clock.advance(const Duration(minutes: 15, seconds: 1));
      final recovered = await attempt('Test1234');
      expect(recovered.status, 200, reason: recovered.text);
    });

    test('a successful login clears the failure counter', () async {
      Future<MockResponse> login(String password) => api.call(
        'POST',
        '/v1/auth/login',
        body: <String, Object?>{
          'email': 'customer@picpac.test',
          'password': password,
        },
      );

      for (var i = 0; i < 4; i++) {
        await login('wrong-$i');
      }
      expect((await login('Test1234')).status, 200);

      for (var i = 0; i < 4; i++) {
        expectError(await login('again-$i'), 401, ApiErrorCode.unauthorized);
      }
      expect((await login('Test1234')).status, 200);
      expect(api.server.isLocked('login|customer@picpac.test'), isFalse);
    });
  });

  group('one-time code', () {
    test('the seeded challenge is completed with 0000', () async {
      final response = await api.call(
        'POST',
        '/v1/auth/verify',
        body: <String, Object?>{
          'challengeId': 'challenge_demo',
          'code': '0000',
        },
      );
      expect(response.status, 200, reason: response.text);
      final session = AuthSession.fromJson(response.object);
      expect(session.role, UserRole.customer);
      expect(session.customerId, 'cus_demo');

      final replay = await api.call(
        'POST',
        '/v1/auth/verify',
        body: <String, Object?>{
          'challengeId': 'challenge_demo',
          'code': '0000',
        },
      );
      expectError(replay, 410, 'challenge_expired');
    });

    test('rejects a wrong code and an unknown challenge', () async {
      final wrong = await api.call(
        'POST',
        '/v1/auth/verify',
        body: <String, Object?>{
          'challengeId': 'challenge_demo',
          'code': '1111',
        },
      );
      expectError(wrong, 422, ApiErrorCode.validationFailed);
      expect(fieldErrors(wrong)['code'], 'invalid_code');

      final unknown = await api.call(
        'POST',
        '/v1/auth/verify',
        body: <String, Object?>{'challengeId': 'nope', 'code': '0000'},
      );
      expectError(unknown, 404, ApiErrorCode.notFound);
    });

    test('five wrong codes burn the challenge with 410', () async {
      for (var i = 0; i < 4; i++) {
        final wrong = await api.call(
          'POST',
          '/v1/auth/verify',
          body: <String, Object?>{
            'challengeId': 'challenge_demo',
            'code': '1111',
          },
        );
        expectError(wrong, 422, ApiErrorCode.validationFailed);
      }
      final fifth = await api.call(
        'POST',
        '/v1/auth/verify',
        body: <String, Object?>{
          'challengeId': 'challenge_demo',
          'code': '1111',
        },
      );
      expectError(fifth, 410, 'challenge_expired');

      final correct = await api.call(
        'POST',
        '/v1/auth/verify',
        body: <String, Object?>{
          'challengeId': 'challenge_demo',
          'code': '0000',
        },
      );
      expectError(correct, 410, 'challenge_expired');
      expect(api.server.challenges.containsKey('challenge_demo'), isFalse);
    });

    test('a new challenge restores access', () async {
      for (var i = 0; i < 5; i++) {
        await api.call(
          'POST',
          '/v1/auth/verify',
          body: <String, Object?>{
            'challengeId': 'challenge_demo',
            'code': '1111',
          },
        );
      }

      final issued = await api.call(
        'POST',
        '/v1/mock/auth/challenge',
        token: await api.loginSupport(),
        body: <String, Object?>{'accountId': 'cus_demo'},
      );
      expect(issued.status, 200, reason: issued.text);
      final challengeId = issued.object['challengeId']! as String;
      expect(challengeId, isNot('challenge_demo'));

      final verified = await api.call(
        'POST',
        '/v1/auth/verify',
        body: <String, Object?>{
          'challengeId': challengeId,
          'code': issued.object['code'],
        },
      );
      expect(verified.status, 200, reason: verified.text);
      expect(AuthSession.fromJson(verified.object).customerId, 'cus_demo');

      final replay = await api.call(
        'POST',
        '/v1/auth/verify',
        body: <String, Object?>{'challengeId': challengeId, 'code': '0000'},
      );
      expectError(replay, 410, 'challenge_expired');
    });

    test('an expired challenge answers 410', () async {
      api.clock.advance(const Duration(minutes: 16));
      final response = await api.call(
        'POST',
        '/v1/auth/verify',
        body: <String, Object?>{
          'challengeId': 'challenge_demo',
          'code': '0000',
        },
      );
      expectError(response, 410, 'challenge_expired');
    });
  });

  group('bearer tokens', () {
    test('reject an expired token after 24 hours', () async {
      final token = await api.login();
      expect((await api.call('GET', '/v1/me', token: token)).status, 200);

      api.clock.advance(const Duration(hours: 24, minutes: 1));
      final expired = await api.call('GET', '/v1/me', token: token);
      expectError(expired, 401, ApiErrorCode.unauthorized);
    });

    test('reject a tampered token', () async {
      final token = await api.login();
      final parts = token.split('.');
      final tampered = '${parts[0]}.${parts[1]}.${'A' * parts[2].length}';
      final response = await api.call('GET', '/v1/me', token: tampered);
      expectError(response, 401, ApiErrorCode.unauthorized);
    });

    test('reject a malformed Authorization header', () async {
      final response = await api.call(
        'GET',
        '/v1/me',
        headers: <String, String>{'authorization': 'Token abc'},
      );
      expectError(response, 401, ApiErrorCode.unauthorized);
    });

    test('require a token on /v1/me', () async {
      final response = await api.call('GET', '/v1/me');
      expectError(response, 401, ApiErrorCode.unauthorized);
    });
  });
}
