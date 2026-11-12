import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:picpac_mobile/app/di.dart';
import 'package:picpac_mobile/app/theme/app_theme.dart';
import 'package:picpac_mobile/app/theme/tokens.dart';
import 'package:picpac_mobile/core/clock.dart';
import 'package:picpac_mobile/payments/presentation/payment_sheet.dart';
import 'package:picpac_mobile/l10n/app_localizations.dart';
import 'package:picpac_mobile/payments/hosted_page_launcher.dart';
import 'package:picpac_mobile/payments/payment_controller.dart';
import 'package:picpac_mobile/payments/payment_port.dart'
    show paymentPortProvider;

import '../features/support/fixtures.dart';
import '../payments/support/payment_fakes.dart';

void main() {
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

  Future<void> pumpFrames(WidgetTester tester, {int frames = 8}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<FocusNode> pumpSheet(
    WidgetTester tester, {
    required FakePaymentPort port,
    FakeLauncher? launcher,
    bool scaled = false,
  }) async {
    if (scaled) {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    final openerFocus = FocusNode(debugLabel: 'sheet-opener');
    addTearDown(openerFocus.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          paymentPortProvider.overrideWithValue(port),
          hostedPageLauncherProvider.overrideWithValue(
            launcher ?? FakeLauncher(),
          ),
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
                  focusNode: openerFocus,
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
    openerFocus.requestFocus();
    await tester.pump();
    await tester.tap(find.text('open'));
    await pumpFrames(tester);
    return openerFocus;
  }

  FakePaymentPort bynPort({
    Future<Result<PaymentIntent>> Function(String key)? onCreate,
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
    onStatus: (_) async => Ok<PaymentIntent>(intent(PaymentStatus.succeeded)),
  );

  testWidgets('панель оплаты: 320×640 при textScaler 2.0 без переполнений', (
    tester,
  ) async {
    await pumpSheet(tester, port: bynPort(), scaled: true);

    expect(tester.takeException(), isNull);
    final pay = find.byKey(const Key('payment-pay'));
    expect(tester.getSize(pay).height, greaterThanOrEqualTo(kMinTouchTarget));

    await tester.scrollUntilVisible(
      find.byKey(const Key('payment-methods')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Картой онлайн'), findsOneWidget);
  });

  testWidgets('открытие панели переводит фокус внутрь, Esc возвращает его', (
    tester,
  ) async {
    final opener = await pumpSheet(tester, port: bynPort());

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'payment-sheet-title',
      reason: 'фокус входит в модальную панель',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpFrames(tester);

    expect(find.byKey(const Key('payment-pay')), findsNothing);
    expect(opener.hasPrimaryFocus, isTrue, reason: 'фокус вернулся к кнопке');
  });

  testWidgets('панель идёт по порядку чтения, а не по порядку вставки', (
    tester,
  ) async {
    await pumpSheet(tester, port: bynPort());
    final group = tester.widget<FocusTraversalGroup>(
      find
          .ancestor(
            of: find.byKey(const Key('payment-methods')),
            matching: find.byType(FocusTraversalGroup),
          )
          .first,
    );
    expect(group.policy, isA<ReadingOrderTraversalPolicy>());
  });

  testWidgets('«Заказ оплачен» объявляется и забирает фокус', (tester) async {
    final announcements = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        if (message is Map && message['type'] == 'announce') {
          final data = message['data'];
          if (data is Map && data['message'] is String) {
            announcements.add(data['message'] as String);
          }
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );

    await pumpSheet(tester, port: bynPort());
    await tester.tap(find.byKey(const Key('payment-pay')));
    await pumpFrames(tester);

    expect(find.text('Заказ оплачен'), findsOneWidget);
    expect(announcements, contains('Заказ оплачен'));
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'payment-sheet-status',
      reason: 'фокус на результате, а не на кнопке',
    );
  });
}
