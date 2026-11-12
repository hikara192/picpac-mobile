import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/features/inspiration/presentation/inspiration_detail_page.dart';

import '../support/fixtures.dart';
import '../support/funnel_harness.dart';
import 'inspiration_fixtures.dart';

void main() {
  setUpAll(registerFunnelFallbacks);

  Future<FunnelHarness> pumpFeed(WidgetTester tester) async {
    final harness = FunnelHarness();
    when(() => harness.api.catalog())
        .thenAnswer((_) async => Ok<CatalogResponse>(catalogResponse()));
    when(
      () => harness.api.inspirationFeed(tag: null, limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async =>
          Ok<InspirationFeedPage>(feedOf(<InspirationItem>[duoIdea()])),
    );
    await harness.pump(tester);
    harness.go(AppRoutes.inspiration);
    await harness.settle(tester);
    return harness;
  }

  Finder heart(IconData icon) => find.descendant(
    of: find.byKey(const Key('inspiration-card-idea_duo')),
    matching: find.byIcon(icon),
  );

  testWidgets('сердечко обновляется сразу, не дожидаясь сервера', (
    tester,
  ) async {
    final pending = Completer<Result<FavoriteState>>();
    final harness = await pumpFeed(tester);
    when(() => harness.api.addFavorite('idea_duo'))
        .thenAnswer((_) => pending.future);

    expect(heart(Icons.favorite_border), findsOneWidget);

    await tester.tap(find.byKey(const Key('inspiration-favorite-idea_duo')));
    await tester.pump();

    expect(heart(Icons.favorite), findsOneWidget);
    expect(find.byType(InspirationDetailPage), findsNothing);

    pending.complete(
      const Ok<FavoriteState>(
        FavoriteState(templateId: 'idea_duo', isFavorite: true),
      ),
    );
    await harness.settle(tester);

    expect(heart(Icons.favorite), findsOneWidget);
    verify(() => harness.api.addFavorite('idea_duo')).called(1);
  });

  testWidgets('ошибка сохранения откатывает сердечко и объясняет причину', (
    tester,
  ) async {
    final pending = Completer<Result<FavoriteState>>();
    final harness = await pumpFeed(tester);
    when(() => harness.api.addFavorite('idea_duo'))
        .thenAnswer((_) => pending.future);

    await tester.tap(find.byKey(const Key('inspiration-favorite-idea_duo')));
    await tester.pump();
    expect(heart(Icons.favorite), findsOneWidget);

    pending.complete(Err<FavoriteState>(ApiFailure.networkUnavailable()));
    await harness.settle(tester);

    expect(heart(Icons.favorite_border), findsOneWidget);
    expect(
      find.text(
        'Не удалось обновить избранное. Проверьте связь и попробуйте ещё раз.',
      ),
      findsOneWidget,
    );
  });
}
