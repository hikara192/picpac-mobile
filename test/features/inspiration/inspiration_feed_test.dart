import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/router.dart';

import '../support/fixtures.dart';
import '../support/funnel_harness.dart';
import 'inspiration_fixtures.dart';

void main() {
  setUpAll(registerFunnelFallbacks);

  void stubCatalog(FunnelHarness harness) {
    when(() => harness.api.catalog())
        .thenAnswer((_) async => Ok<CatalogResponse>(catalogResponse()));
  }

  testWidgets('лента рендерит идеи из ответа и их названия из ARB', (
    tester,
  ) async {
    final harness = FunnelHarness();
    stubCatalog(harness);
    when(
      () => harness.api.inspirationFeed(tag: null, limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => Ok<InspirationFeedPage>(
        feedOf(<InspirationItem>[duoIdea(), quadIdea()]),
      ),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.inspiration);
    await harness.settle(tester);

    expect(find.text('Две истории'), findsOneWidget);
    expect(find.text('Сетка 2×2'), findsOneWidget);
    expect(find.text('Все'), findsOneWidget);
    expect(find.text('Семья'), findsWidgets);
  });

  testWidgets(
    'карточка — один элемент для скринридера с названием и числом фото',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final harness = FunnelHarness();
      stubCatalog(harness);
      when(
        () =>
            harness.api.inspirationFeed(tag: null, limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async =>
            Ok<InspirationFeedPage>(feedOf(<InspirationItem>[duoIdea()])),
      );

      await harness.pump(tester);
      harness.go(AppRoutes.inspiration);
      await harness.settle(tester);

      expect(
        find.bySemanticsLabel(RegExp('Шаблон: Две истории, 2 фото')),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

  testWidgets('фильтр по тегу запрашивает сервер и оставляет идеи тега', (
    tester,
  ) async {
    final harness = FunnelHarness();
    stubCatalog(harness);
    when(
      () => harness.api.inspirationFeed(tag: null, limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => Ok<InspirationFeedPage>(
        feedOf(<InspirationItem>[duoIdea(), quadIdea()]),
      ),
    );
    when(
      () => harness.api.inspirationFeed(
        tag: 'путешествие',
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async =>
          Ok<InspirationFeedPage>(feedOf(<InspirationItem>[quadIdea()])),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.inspiration);
    await harness.settle(tester);

    await tester.tap(find.byKey(const Key('inspiration-tag-путешествие')));
    await harness.settle(tester);

    expect(find.text('Сетка 2×2'), findsOneWidget);
    expect(find.text('Две истории'), findsNothing);
    verify(
      () => harness.api.inspirationFeed(
        tag: 'путешествие',
        limit: any(named: 'limit'),
      ),
    ).called(1);
  });

  testWidgets('пустое избранное объясняет, как его пополнить', (tester) async {
    final harness = FunnelHarness();
    stubCatalog(harness);
    when(
      () => harness.api.inspirationFeed(tag: null, limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async =>
          Ok<InspirationFeedPage>(feedOf(<InspirationItem>[duoIdea()])),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.inspiration);
    await harness.settle(tester);

    await tester.tap(find.byKey(const Key('inspiration-favorites-filter')));
    await harness.settle(tester);

    expect(find.text('Здесь пока пусто'), findsOneWidget);
    expect(find.text('Сохраняйте идеи — они появятся здесь'), findsOneWidget);
  });

  testWidgets('ошибка ленты показывает сообщение и повторяет запрос', (
    tester,
  ) async {
    final harness = FunnelHarness();
    stubCatalog(harness);
    var calls = 0;
    when(
      () => harness.api.inspirationFeed(tag: null, limit: any(named: 'limit')),
    ).thenAnswer((_) async {
      calls++;
      return calls == 1
          ? Err<InspirationFeedPage>(ApiFailure.networkUnavailable())
          : Ok<InspirationFeedPage>(feedOf(<InspirationItem>[duoIdea()]));
    });

    await harness.pump(tester);
    harness.go(AppRoutes.inspiration);
    await harness.settle(tester);

    expect(
      find.text('Нет соединения. Проверьте сеть и попробуйте снова.'),
      findsOneWidget,
    );
    expect(find.text('Две истории'), findsNothing);

    await tester.tap(find.text('Повторить'));
    await harness.settle(tester);

    expect(calls, 2);
    expect(find.text('Две истории'), findsOneWidget);
  });

  testWidgets('сетка переживает масштаб текста 2.0 без переполнения', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = FunnelHarness();
    stubCatalog(harness);
    when(
      () => harness.api.inspirationFeed(tag: null, limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => Ok<InspirationFeedPage>(
        feedOf(<InspirationItem>[duoIdea(), quadIdea()]),
      ),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.inspiration);
    await harness.settle(tester);

    expect(find.text('Две истории'), findsOneWidget);
    expect(find.text('Сетка 2×2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
