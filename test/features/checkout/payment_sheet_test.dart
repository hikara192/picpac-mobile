import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:picpac_mobile/app/di.dart';
import 'package:picpac_mobile/app/theme/app_theme.dart';
import 'package:picpac_mobile/core/clock.dart';
import 'package:picpac_mobile/l10n/app_localizations.dart';
import 'package:picpac_mobile/payments/hosted_page_launcher.dart';
import 'package:picpac_mobile/payments/payment_controller.dart';
import 'package:picpac_mobile/payments/payment_port.dart'
    show paymentPortProvider;
import 'package:picpac_mobile/payments/presentation/payment_sheet.dart';

import '../../payments/support/payment_fakes.dart';
import '../support/fixtures.dart';

void main() {
  PaymentIntent intent(
    PaymentStatus status, {
    String id = 'int_1',
    String? hostedPageUrl,
    String? eripCode,
  }) => PaymentIntent(
    id: id,
    orderId: 'ord_1',
    status: status,
    amount: byn(2600),
    provider: 'bepaid',
    createdAt: testNow,
    methodId: 'bank_card',
    hostedPageUrl: hostedPageUrl,
    eripCode: eripCode,
  );

  Future<void> pumpFrames(WidgetTester tester, {int frames = 8}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<FakeLauncher> pumpSheet(
    WidgetTester tester, {
    required FakePaymentPort port,
    FakeLauncher? launcher,
    Size size = const Size(390, 844),
  }) async {
    final browser = launcher ?? FakeLauncher();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          paymentPortProvider.overrideWithValue(port),
          hostedPageLauncherProvider.overrideWithValue(browser),
          paymentDelayProvider.overrideWithValue((_) async {}),
          clockProvider.overrideWithValue(FixedClock(testNow)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: const Locale('ru'),
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () =>
                      showPaymentSheet(context, order: orderFixture()),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await pumpFrames(tester);
    return browser;
  }

  FakePaymentPort bynPort({
    Future<Result<PaymentIntent>> Function(String key)? onCreate,
    Future<Result<PaymentIntent>> Function(String intentId)? onStatus,
    Future<Result<Receipt>> Function(String orderId)? onReceipt,
  }) => FakePaymentPort(
    methodsByRegion: <String, List<PaymentMethodInfo>>{
      'BY': <PaymentMethodInfo>[cardMethod(), eripMethod(), codMethod()],
      'RU': <PaymentMethodInfo>[cardMethod(region: 'RU', currency: 'RUB')],
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
    onReceipt: onReceipt,
  );

  testWidgets('панель показывает методы, сумму и кнопку оплаты', (
    tester,
  ) async {
    await pumpSheet(tester, port: bynPort());

    expect(find.text('Оплата заказа'), findsOneWidget);
    expect(find.text('К оплате 26,00 BYN'), findsOneWidget);
    expect(find.text('Картой онлайн'), findsOneWidget);
    expect(find.text('ЕРИП'), findsOneWidget);
    expect(find.text('При получении'), findsOneWidget);
    expect(find.byKey(const Key('payment-pay')), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('«Оплатить» открывает hosted page и доводит до «оплачен»', (
    tester,
  ) async {
    final port = bynPort();
    final launcher = await pumpSheet(tester, port: port);

    await tester.tap(find.byKey(const Key('payment-pay')));
    await pumpFrames(tester);

    expect(launcher.opened, hasLength(1));
    expect(launcher.opened.single.host, 'pay.example.test');
    expect(find.text('Заказ оплачен'), findsOneWidget);
    expect(find.byKey(const Key('payment-receipt')), findsOneWidget);
    expect(find.byKey(const Key('payment-pay')), findsNothing);
  });

  testWidgets('отказ предлагает повторить с новым ключом', (tester) async {
    var attempt = 0;
    final port = bynPort(
      onCreate: (key) async {
        attempt++;
        return Ok<PaymentIntent>(
          intent(
            attempt == 1 ? PaymentStatus.failed : PaymentStatus.succeeded,
            hostedPageUrl: 'https://pay.example.test/int_$attempt?token=abc',
          ),
        );
      },
      onStatus: (id) async => Ok<PaymentIntent>(intent(PaymentStatus.failed)),
    );
    await pumpSheet(tester, port: port);

    await tester.tap(find.byKey(const Key('payment-pay')));
    await pumpFrames(tester);

    expect(find.text('Оплата не прошла'), findsOneWidget);
    expect(find.text('Попробовать снова'), findsOneWidget);

    await tester.tap(find.byKey(const Key('payment-retry')));
    await pumpFrames(tester);

    expect(port.createKeys, hasLength(2));
    expect(port.createKeys.first, isNot(port.createKeys.last));
  });

  testWidgets('оплата при получении не открывает браузер', (tester) async {
    final port = bynPort(
      onCreate: (key) async =>
          Ok<PaymentIntent>(intent(PaymentStatus.pendingOnDelivery)),
    );
    final launcher = await pumpSheet(tester, port: port);

    await tester.tap(find.byKey(const Key('payment-method-cash_on_delivery')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const Key('payment-pay')));
    await pumpFrames(tester);

    expect(launcher.opened, isEmpty);
    expect(port.statusCalls, isEmpty);
    expect(find.text('Оплата при получении'), findsWidgets);
  });

  testWidgets('серверное «уже оплачено» объясняется словами', (tester) async {
    final port = bynPort(
      onCreate: (key) async => Err<PaymentIntent>(
        const ApiFailure(
          code: 'payment_already_paid',
          message: 'the order is already paid',
          statusCode: 409,
        ),
      ),
    );
    await pumpSheet(tester, port: port);

    await tester.tap(find.byKey(const Key('payment-pay')));
    await pumpFrames(tester);

    expect(find.text('Заказ оплачен'), findsOneWidget);
    expect(
      find.text('Заказ уже оплачен — новый платёж не нужен'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('payment-pay')), findsNothing);
  });

  testWidgets('если браузер не открылся, есть повтор и объяснение', (
    tester,
  ) async {
    final port = bynPort();
    final launcher = await pumpSheet(
      tester,
      port: port,
      launcher: FakeLauncher(outcome: HostedPageLaunch.failed),
    );

    await tester.tap(find.byKey(const Key('payment-pay')));
    await pumpFrames(tester);

    expect(launcher.opened, hasLength(1));
    expect(
      find.text('Не удалось открыть страницу оплаты. Попробуйте ещё раз.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('payment-open-page')), findsOneWidget);
  });

  testWidgets('переключатель региона перезапрашивает методы', (tester) async {
    final port = bynPort();
    await pumpSheet(tester, port: port);

    await tester.tap(find.text('Россия'));
    await pumpFrames(tester);

    expect(port.methodRegions, <String>['BY', 'RU']);
    expect(find.text('Картой онлайн'), findsOneWidget);
    expect(find.text('ЕРИП'), findsNothing);
  });

  testWidgets('успех показывает чек с номером и суммой', (tester) async {
    final port = bynPort(
      onCreate: (key) async =>
          Ok<PaymentIntent>(intent(PaymentStatus.succeeded)),
      onReceipt: (orderId) async => Ok<Receipt>(
        Receipt(
          id: 'rcp_1',
          orderId: orderId,
          fiscalId: 'FISC-PP-1001-1',
          amount: byn(2600),
          issuedAt: testNow,
        ),
      ),
    );
    await pumpSheet(tester, port: port);

    await tester.tap(find.byKey(const Key('payment-pay')));
    await pumpFrames(tester);
    expect(find.text('Заказ оплачен'), findsOneWidget);

    await tester.tap(find.byKey(const Key('payment-receipt')));
    await pumpFrames(tester);

    expect(find.text('Чек'), findsWidgets);
    expect(find.text('FISC-PP-1001-1'), findsOneWidget);
    expect(find.text('26,00 BYN'), findsWidgets);
    expect(find.byKey(const Key('receipt-share')), findsOneWidget);
  });
}
