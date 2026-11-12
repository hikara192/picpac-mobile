import 'package:api_contract/api_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/core/clock.dart';
import 'package:picpac_mobile/payments/payment_poller.dart';

import '../features/support/fixtures.dart';

void main() {
  PaymentIntent intentWith(PaymentStatus status) => PaymentIntent(
    id: 'int_1',
    orderId: 'ord_1',
    status: status,
    amount: byn(2600),
    provider: 'bepaid',
    createdAt: testNow,
    methodId: 'bank_card',
  );

  test('пауза растёт 0.5 → 1 → 2 → 4 и упирается в 30 с', () async {
    final clock = _MutableClock(testNow);
    final pauses = <Duration>[];
    final statuses = <PaymentStatus>[
      PaymentStatus.processing,
      PaymentStatus.processing,
      PaymentStatus.processing,
      PaymentStatus.processing,
      PaymentStatus.processing,
      PaymentStatus.processing,
      PaymentStatus.processing,
      PaymentStatus.processing,
    ];
    final poller = PaymentPoller(
      fetch: (intentId) async => Ok<PaymentIntent>(
        intentWith(
          statuses.isEmpty ? PaymentStatus.succeeded : statuses.removeAt(0),
        ),
      ),
      delay: (duration) async {
        pauses.add(duration);
        clock.advance(duration);
      },
      clock: clock,
    );

    final outcome = await poller.start('int_1');

    expect(outcome.stop, PaymentPollStop.status);
    expect(outcome.intent?.status, PaymentStatus.succeeded);
    expect(pauses.take(8), <Duration>[
      const Duration(milliseconds: 500),
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
      const Duration(seconds: 8),
      const Duration(seconds: 16),
      const Duration(seconds: 30),
      const Duration(seconds: 30),
    ]);
  });

  test('таймаут 5 минут останавливает опрос', () async {
    final clock = _MutableClock(testNow);
    final poller = PaymentPoller(
      fetch: (intentId) async =>
          Ok<PaymentIntent>(intentWith(PaymentStatus.processing)),
      delay: (duration) async {
        clock.advance(duration);
      },
      clock: clock,
    );

    final outcome = await poller.start('int_1');

    expect(outcome.stop, PaymentPollStop.timeout);
    expect(outcome.attempts, greaterThan(5));
    expect(
      clock.now().difference(testNow),
      greaterThanOrEqualTo(const Duration(minutes: 5)),
    );
    expect(poller.isActive, isFalse);
  });

  test('отмена прекращает опрос без нового запроса', () async {
    final clock = _MutableClock(testNow);
    var calls = 0;
    late final PaymentPoller poller;
    poller = PaymentPoller(
      fetch: (intentId) async {
        calls++;
        poller.cancel(); // as if the screen went away mid-flight
        return Ok<PaymentIntent>(intentWith(PaymentStatus.processing));
      },
      delay: (duration) async {
        clock.advance(duration);
      },
      clock: clock,
    );

    final outcome = await poller.start('int_1');

    expect(outcome.stop, PaymentPollStop.canceled);
    expect(calls, 1);
    expect(poller.isActive, isFalse);
  });

  test('на один intent — один активный опрос', () async {
    final clock = _MutableClock(testNow);
    var calls = 0;
    late final PaymentPoller poller;
    poller = PaymentPoller(
      fetch: (intentId) async {
        calls++;
        if (calls < 3) {
          final duplicate = await poller.start('int_1');
          expect(duplicate.stop, PaymentPollStop.duplicate);
        }
        return Ok<PaymentIntent>(
          intentWith(
            calls >= 3 ? PaymentStatus.succeeded : PaymentStatus.processing,
          ),
        );
      },
      delay: (duration) async {
        clock.advance(duration);
      },
      clock: clock,
    );

    final outcome = await poller.start('int_1');

    expect(outcome.stop, PaymentPollStop.status);
    expect(calls, 3);
    expect(outcome.attempts, 3);
  });

  test('сетевые ошибки не превращают платёж в неудачу', () async {
    final clock = _MutableClock(testNow);
    var calls = 0;
    final poller = PaymentPoller(
      fetch: (intentId) async {
        calls++;
        if (calls < 4) {
          return Err<PaymentIntent>(ApiFailure.networkUnavailable());
        }
        return Ok<PaymentIntent>(intentWith(PaymentStatus.succeeded));
      },
      delay: (duration) async {
        clock.advance(duration);
      },
      clock: clock,
    );

    final outcome = await poller.start('int_1');

    expect(outcome.stop, PaymentPollStop.status);
    expect(outcome.intent?.status, PaymentStatus.succeeded);
    expect(calls, 4);
  });
}

final class _MutableClock implements Clock {
  _MutableClock(this._instant);

  DateTime _instant;

  void advance(Duration duration) => _instant = _instant.add(duration);

  @override
  DateTime now() => _instant.toUtc();
}
