import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/app/theme/tokens.dart';
import 'package:picpac_mobile/core/presentation/a11y.dart';

import '../features/support/fixtures.dart';
import '../features/support/funnel_harness.dart';

void main() {
  setUpAll(registerFunnelFallbacks);

  Future<void> stubShell(FunnelHarness harness) async {
    when(() => harness.api.catalog())
        .thenAnswer((_) async => Ok<CatalogResponse>(catalogResponse()));
  }

  testWidgets('карточка товара читается одним элементом: название и цена', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final harness = FunnelHarness();
    await stubShell(harness);

    await harness.pump(tester);
    harness.go(AppRoutes.catalog);
    await harness.settle(tester);

    final card = tester.getSemantics(
      find.bySemanticsLabel(RegExp('Печать фотографий.*от 1,30 BYN')),
    );
    expect(card.label, contains('Печать фотографий'));
    expect(card.label, contains('от 1,30 BYN'));
    expect(card.flagsCollection.isButton, isTrue);
    expect(card.flagsCollection.isImage, isFalse);

    handle.dispose();
  });

  testWidgets('строка корзины — один элемент: название и количество', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final harness = FunnelHarness();
    await stubShell(harness);
    when(() => harness.api.cart())
        .thenAnswer((_) async => Ok<Cart>(bookCartFixture()));
    when(() => harness.api.design('dsg_book'))
        .thenAnswer((_) async => Ok<DesignDto>(bookDesignFixture()));

    await harness.pump(tester);
    harness.go(AppRoutes.cart);
    await harness.settle(tester);

    expect(
      find.bySemanticsLabel('Фотокнига Classic 20×20, 1 книга · 10 разворотов'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Количество: 1'), findsOneWidget);
    expect(find.byTooltip('Удалить'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('статусы заказа объявлены как live region', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = FunnelHarness();
    await stubShell(harness);
    when(() => harness.api.order('ord_1'))
        .thenAnswer((_) async => Ok<Order>(orderFixture()));
    when(() => harness.api.pickupPoints()).thenAnswer(
      (_) async => Ok<List<PickupPoint>>(<PickupPoint>[pickupPoint()]),
    );
    when(() => harness.api.deliveryOptions()).thenAnswer(
      (_) async => Ok<List<DeliveryOption>>(<DeliveryOption>[deliveryOption()]),
    );

    await harness.pump(tester);
    harness.push(AppRoutes.orderFor('ord_1'));
    await harness.settle(tester);

    for (final label in <String>['Ожидает оплаты', 'Оформлен']) {
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(node.flagsCollection.isLiveRegion, isTrue, reason: label);
    }

    handle.dispose();
  });

  testWidgets('карточка обращения читается одной кнопкой', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = FunnelHarness();
    await stubShell(harness);
    when(() => harness.api.supportTickets()).thenAnswer(
      (_) async => Ok<List<SupportTicket>>(<SupportTicket>[
        supportTicketFixture(subject: 'Фото с полосой'),
      ]),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.support);
    await harness.settle(tester);

    final card = tester.getSemantics(
      find.bySemanticsLabel('Фото с полосой, Открыто'),
    );
    expect(card.flagsCollection.isButton, isTrue);

    handle.dispose();
  });

  testWidgets('диалог получает фокус, Esc закрывает и возвращает его', (
    tester,
  ) async {
    final harness = FunnelHarness();
    await stubShell(harness);
    when(() => harness.api.cart())
        .thenAnswer((_) async => Ok<Cart>(cartFixture()));
    when(() => harness.api.design('dsg_1'))
        .thenAnswer((_) async => Ok<DesignDto>(printDesignFixture()));

    await harness.pump(tester);
    harness.go(AppRoutes.cart);
    await harness.settle(tester);

    final removeIcon = find.descendant(
      of: find.byTooltip('Удалить'),
      matching: find.byType(Icon),
    );
    final initiator = Focus.of(tester.element(removeIcon));
    initiator.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await harness.settle(tester);

    expect(find.text('Удалить позицию?'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    var insideDialog = false;
    (FocusManager.instance.primaryFocus?.context as Element?)
        ?.visitAncestorElements((ancestor) {
          if (ancestor.widget is AlertDialog) {
            insideDialog = true;
            return false;
          }
          return true;
        });
    expect(insideDialog, isTrue, reason: 'фокус внутри диалога');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await harness.settle(tester);

    expect(find.text('Удалить позицию?'), findsNothing);
    expect(initiator.hasPrimaryFocus, isTrue, reason: 'фокус вернулся');
  });

  testWidgets('фокус на карточке виден: 2 dp коралловый ринг', (tester) async {
    final harness = FunnelHarness();
    await stubShell(harness);

    await harness.pump(tester);
    harness.go(AppRoutes.catalog);
    await harness.settle(tester);

    final ring = find.byType(FocusRing).first;
    bool ringPainted() => find
        .descendant(
          of: ring,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).border?.top.color ==
                    PicPacColors.accent,
          ),
        )
        .evaluate()
        .isNotEmpty;

    expect(ringPainted(), isFalse);
    final node = Focus.of(tester.element(find.text('Печать фотографий').first));
    node.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(ringPainted(), isTrue);
  });

  testWidgets('иконочные кнопки несут подсказку и не дублируют её', (
    tester,
  ) async {
    final harness = FunnelHarness();
    await stubShell(harness);

    await harness.pump(tester);
    harness.go(AppRoutes.catalog);
    await harness.settle(tester);

    expect(find.byTooltip('Открыть корзину'), findsOneWidget);
    expect(find.byTooltip('Мои проекты'), findsOneWidget);
  });

  testWidgets('поля чекаута объявляют автозаполнение и действия клавиатуры', (
    tester,
  ) async {
    final harness = FunnelHarness();
    await stubShell(harness);
    when(() => harness.api.cart()).thenAnswer(
      (_) async => Ok<Cart>(cartFixture(quantity: 1, subtotal: 1300)),
    );
    when(() => harness.api.design('dsg_1'))
        .thenAnswer((_) async => Ok<DesignDto>(designFixture()));
    when(() => harness.api.deliveryOptions()).thenAnswer(
      (_) async => Ok<List<DeliveryOption>>(<DeliveryOption>[deliveryOption()]),
    );
    when(() => harness.api.pickupPoints()).thenAnswer(
      (_) async => Ok<List<PickupPoint>>(<PickupPoint>[pickupPoint()]),
    );
    when(() => harness.api.price(any()))
        .thenAnswer((_) async => Ok<PriceQuote>(priceQuote(total: 1300)));

    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await harness.pump(tester);
    harness.go(AppRoutes.checkout);
    await harness.settle(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('checkout-name')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final name = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('checkout-name')),
        matching: find.byType(TextField),
      ),
    );
    final phone = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('checkout-phone')),
        matching: find.byType(TextField),
      ),
    );
    expect(name.autofillHints, contains(AutofillHints.name));
    expect(name.textInputAction, TextInputAction.next);
    expect(phone.autofillHints, contains(AutofillHints.telephoneNumber));

    tester.state<FormState>(find.byType(Form)).validate();
    await tester.pump();
    expect(find.text('Укажите телефон'), findsOneWidget);
  });
}
