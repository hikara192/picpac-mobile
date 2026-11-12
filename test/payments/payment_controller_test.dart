import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/app/di.dart';
import 'package:picpac_mobile/core/clock.dart';
import 'package:picpac_mobile/payments/hosted_page_launcher.dart';
import 'package:picpac_mobile/payments/payment_controller.dart';
import 'package:picpac_mobile/payments/payment_flow.dart';
import 'package:picpac_mobile/payments/payment_port.dart';

import '../features/support/fixtures.dart';
import 'support/payment_fakes.dart';

void main() {
  const orderRef = PaymentOrderRef(orderId: 'ord_1', currency: 'BYN');

  PaymentMethodInfo card({String region = 'BY', String currency = 'BYN'}) =>
      cardMethod(region: region, currency: currency);

  PaymentMethodInfo cod() => codMethod();

  PaymentIntent intent(
    PaymentStatus status, {
    String id = 'int_1',
    String? hostedPageUrl,
  }) => PaymentIntent(
    id: id,
    orderId: 'ord_1',
    status: status,
    amount: byn(2600),
    provider: 'bepaid',
    createdAt: testNow,
    methodId: 'bank_card',
    hostedPageUrl: hostedPageUrl,
  );

  ({
    ProviderContainer container,
    PaymentController controller,
    FakePaymentPort port,
    FakeLauncher launcher,
  })
  harness({
    Map<String, List<PaymentMethodInfo>>? methods,
    Future<Result<PaymentIntent>> Function(String key)? onCreate,
    Future<Result<PaymentIntent>> Function(String intentId)? onStatus,
  }) {
    final port = FakePaymentPort(
      methodsByRegion:
          methods ??
          <String, List<PaymentMethodInfo>>{
            'BY': <PaymentMethodInfo>[card(), cod()],
            'RU': <PaymentMethodInfo>[card(region: 'RU', currency: 'RUB')],
          },
      onCreate:
          onCreate ??
          (key) async => Ok<PaymentIntent>(
            intent(
              PaymentStatus.requiresAction,
              hostedPageUrl: 'https://pay.example.test/int_1?token=abc',
            ),
          ),
      onStatus:
          onStatus ??
          (id) async => Ok<PaymentIntent>(intent(PaymentStatus.succeeded)),
    );
    final launcher = FakeLauncher();
    final container = ProviderContainer(
      overrides: <Override>[
        paymentPortProvider.overrideWithValue(port),
        hostedPageLauncherProvider.overrideWithValue(launcher),
        paymentDelayProvider.overrideWithValue((_) async {}),
        clockProvider.overrideWithValue(FixedClock(testNow)),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen<PaymentState>(
      paymentControllerProvider(orderRef),
      (previous, next) {},
    );
    addTearDown(subscription.close);
    return (
      container: container,
      controller: container.read(paymentControllerProvider(orderRef).notifier),
      port: port,
      launcher: launcher,
    );
  }

  test(
    'методы приходят по региону и перезапрашиваются при переключении',
    () async {
      final h = harness();
      await h.controller.loadMethods();

      expect(h.port.methodRegions, <String>['BY']);
      expect(
        h.container.read(paymentControllerProvider(orderRef)).methods,
        hasLength(2),
      );
      expect(
        h.container.read(paymentControllerProvider(orderRef)).selected?.id,
        'bank_card',
      );

      await h.controller.selectRegion('RU');
      expect(h.port.methodRegions, <String>['BY', 'RU']);
      final state = h.container.read(paymentControllerProvider(orderRef));
      expect(state.region, 'RU');
      expect(state.methods.single.id, 'bank_card');
      expect(state.selected?.currency, 'RUB');
    },
  );

  test('ключ идемпотентности переиспользуется при ретрае создания', () async {
    var attempt = 0;
    final h = harness(
      onCreate: (key) async {
        attempt++;
        if (attempt == 1) {
          return Err<PaymentIntent>(ApiFailure.networkUnavailable());
        }
        return Ok<PaymentIntent>(intent(PaymentStatus.succeeded));
      },
    );
    await h.controller.loadMethods();

    await h.controller.pay();
    await h.controller.pay();

    expect(h.port.createKeys, hasLength(2));
    expect(h.port.createKeys.first, h.port.createKeys.last);
    expect(h.port.createKeys.first, isNotEmpty);
    expect(
      h.container.read(paymentControllerProvider(orderRef)).flow.phase,
      PaymentPhase.succeeded,
    );
  });

  test('после успеха второй intent не создаётся', () async {
    final h = harness(
      onCreate: (key) async =>
          Ok<PaymentIntent>(intent(PaymentStatus.succeeded)),
    );
    await h.controller.loadMethods();

    await h.controller.pay();
    await h.controller.pay();

    expect(h.port.createKeys, hasLength(1));
    expect(
      h.container.read(paymentControllerProvider(orderRef)).canPay,
      isFalse,
    );
  });

  test('«Попробовать снова» после неудачи берёт новый ключ', () async {
    var attempt = 0;
    final h = harness(
      onCreate: (key) async {
        attempt++;
        return Ok<PaymentIntent>(
          intent(attempt == 1 ? PaymentStatus.failed : PaymentStatus.succeeded),
        );
      },
      onStatus: (id) async => Ok<PaymentIntent>(intent(PaymentStatus.failed)),
    );
    await h.controller.loadMethods();

    await h.controller.pay();
    expect(
      h.container.read(paymentControllerProvider(orderRef)).flow.phase,
      PaymentPhase.failed,
    );

    await h.controller.retry();

    expect(h.port.createKeys, hasLength(2));
    expect(h.port.createKeys.first, isNot(h.port.createKeys.last));
    expect(
      h.container.read(paymentControllerProvider(orderRef)).flow.phase,
      PaymentPhase.succeeded,
    );
  });

  test('карта открывает hosted page в браузере и доводит до успеха', () async {
    final h = harness();
    await h.controller.loadMethods();

    await h.controller.pay();

    expect(h.launcher.opened, hasLength(1));
    expect(h.launcher.opened.single.host, 'pay.example.test');
    expect(h.port.statusCalls, isNotEmpty);
    expect(
      h.container.read(paymentControllerProvider(orderRef)).flow.phase,
      PaymentPhase.succeeded,
    );
  });

  test('оплата при получении не открывает браузер и не поллит', () async {
    final h = harness(
      onCreate: (key) async =>
          Ok<PaymentIntent>(intent(PaymentStatus.pendingOnDelivery)),
    );
    await h.controller.loadMethods();
    h.controller.select(
      h.container.read(paymentControllerProvider(orderRef)).methods.last,
    );

    await h.controller.pay();

    expect(h.launcher.opened, isEmpty);
    expect(h.port.statusCalls, isEmpty);
    expect(
      h.container.read(paymentControllerProvider(orderRef)).flow.phase,
      PaymentPhase.onDelivery,
    );
  });

  test(
    'серверное «уже оплачено» объясняется, а не создаёт второй платёж',
    () async {
      final h = harness(
        onCreate: (key) async => Err<PaymentIntent>(
          const ApiFailure(
            code: 'payment_already_paid',
            message: 'the order is already paid',
            statusCode: 409,
          ),
        ),
      );
      await h.controller.loadMethods();

      await h.controller.pay();

      final state = h.container.read(paymentControllerProvider(orderRef));
      expect(state.flow.phase, PaymentPhase.succeeded);
      expect(state.canPay, isFalse);
    },
  );
}
