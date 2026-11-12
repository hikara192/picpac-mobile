import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';
import 'package:picpac_mobile/features/create/application/projects_controller.dart';

import 'support/mock_harness.dart';

void main() {
  testWidgets('проект без фото не попадает в «Мои проекты»', (tester) async {
    final live = await MockHarness.forWidgetTest(tester);
    final project = await live.seedProject(tester, photos: 3);
    await live.seedLocalDraft(tester, photos: 0);

    await live.pump(tester, location: AppRoutes.projects);
    await live.settleReal(tester);

    expect(find.text('Мои проекты'), findsOneWidget);
    expect(find.byKey(Key('project-${project.id}')), findsOneWidget);
    expect(find.byKey(const Key('project-local_test')), findsNothing);

    final projects = live.container.read(projectsProvider).value!;
    expect(projects, hasLength(1));
    expect(projects.single.photoCount, 3);

    await live.disposeForTest(tester);
  });

  testWidgets('404 после рестарта backend открывает локальную копию', (
    tester,
  ) async {
    final live = await MockHarness.forWidgetTest(tester);
    final project = await live.seedProject(tester, photos: 2);
    final order = <String>[
      for (final asset in project.document.assets) asset.sha256,
    ];

    live.backend.restart();
    await live.setup(tester, live.signOut);
    await live.setup(tester, () => live.signIn(UserRole.customer));

    await live.pump(tester, location: AppRoutes.createFor(project.id));
    await live.settleReal(tester);

    expect(find.textContaining('Локальная копия'), findsOneWidget);
    expect(find.textContaining('Что-то пошло не так'), findsNothing);

    final session = live.container
        .read(designSessionProvider(project.id))
        .value!;
    expect(session.localCopy, isTrue);
    expect(session.document.photoCount, 2);
    expect(session.document.assets.map((asset) => asset.sha256), order);

    final reads = live.backend.callsTo('GET', '/v1/designs/${project.id}');
    expect(reads, isNotEmpty);
    expect(reads.last.status, 404);

    await live.disposeForTest(tester);
  });

  testWidgets('10 фото → рестарт приложения → порядок и листы целы', (
    tester,
  ) async {
    final live = await MockHarness.forWidgetTest(tester);
    final project = await live.seedProject(tester, photos: 10);
    final order = <String>[
      for (final asset in project.document.assets) asset.sha256,
    ];
    expect(project.document.spreads, hasLength(10));

    await live.pump(tester, location: AppRoutes.projects);
    await live.settleReal(tester);
    expect(find.textContaining('10 фото'), findsOneWidget);
    expect(find.textContaining('10 листов'), findsOneWidget);

    await live.pump(tester, location: AppRoutes.projects);
    await live.settleReal(tester);
    final projects = live.container.read(projectsProvider).value!;
    expect(projects, hasLength(1));
    expect(projects.single.designId, project.id);
    expect(projects.single.photoCount, 10);

    live.go(AppRoutes.createFor(project.id));
    await live.settleReal(tester);
    final session = live.container
        .read(designSessionProvider(project.id))
        .value!;
    expect(session.document.assets.map((asset) => asset.sha256), order);
    expect(session.document.spreads, hasLength(10));
    expect(session.restoredFromCache, isFalse, reason: 'сервер доступен');

    await live.disposeForTest(tester);
  });

  testWidgets('проект открывается по тапу и удаляется с подтверждением', (
    tester,
  ) async {
    final live = await MockHarness.forWidgetTest(tester);
    final project = await live.seedProject(tester, photos: 2);

    await live.pump(tester, location: AppRoutes.projects);
    await live.settleReal(tester);
    await tester.tap(find.byKey(Key('project-${project.id}')));
    await live.settleReal(tester);
    expect(find.text('Проект'), findsWidgets);
    expect(
      live.container
          .read(designSessionProvider(project.id))
          .value
          ?.document
          .photoCount,
      2,
    );

    live.go(AppRoutes.projects);
    await live.settleReal(tester);
    await tester.tap(find.byTooltip('Удалить проект'));
    await live.settle(tester);
    expect(find.text('Удалить проект?'), findsOneWidget);
    await tester.tap(find.text('Удалить').last);
    await live.settleReal(tester);

    expect(find.text('Проектов пока нет'), findsOneWidget);
    final after = await live.setup(tester, () => live.drafts.load(project.id));
    expect(after, isNull);
    expect(
      live.backend.callsTo('DELETE', '/v1/designs/${project.id}'),
      hasLength(1),
    );

    await live.disposeForTest(tester);
  });
}
