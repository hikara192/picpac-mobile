import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/core/session/guest_work.dart';
import 'package:picpac_mobile/core/session/session_controller.dart';

import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  const forbidden = ApiFailure(
    code: ApiErrorCode.forbidden,
    message: 'the design belongs to another customer',
    statusCode: 403,
  );

  testWidgets('403 показывает «гостевая сессия» и собирает проект заново', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 2);
    await tester.runAsync(
      () => harness.drafts.saveNow(
        document,
        designId: 'dsg_1',
        productId: 'photo_print',
      ),
    );
    harness.stubBasics(designFailure: forbidden);
    when(() => harness.api.createDesign(any())).thenAnswer(
      (_) async => Ok<DesignDto>(
        DesignDto(
          id: 'dsg_new',
          revision: 1,
          document: document,
          updatedAt: DateTime.utc(2026, 11, 11, 12, 5),
        ),
      ),
    );

    await harness.pump(tester, location: '/create/dsg_1');

    expect(find.text('Проект принадлежит гостевой сессии'), findsOneWidget);
    expect(
      find.textContaining('Фотографии сохранены на устройстве'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('guest-project-catalog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('guest-project-restart')));
    await harness.settleReal(tester, frames: 30);

    final captured = verify(() => harness.api.createDesign(captureAny()))
        .captured;
    final rebuilt = captured.single as DesignDocument;
    expect(rebuilt.assets, hasLength(document.assets.length));
    expect(
      rebuilt.assets.map((asset) => asset.sha256),
      document.assets.map((asset) => asset.sha256),
    );
    expect(
      harness.container.read(routerProvider).state.uri.path,
      '/create/dsg_new',
    );

    await harness.disposeForTest(tester);
  });

  testWidgets('без снапшота предлагает только каталог, без пустого экрана', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = await DesignHarness.forWidgetTest(tester);
    harness.stubBasics(designFailure: forbidden);

    await harness.pump(tester, location: '/create/dsg_1');

    expect(find.text('Проект принадлежит гостевой сессии'), findsOneWidget);
    expect(find.textContaining('Соберите проект заново'), findsOneWidget);
    expect(find.byKey(const Key('guest-project-restart')), findsNothing);
    expect(find.byKey(const Key('guest-project-catalog')), findsOneWidget);

    await harness.disposeForTest(tester);
  });

  testWidgets('гостевой проект не теряет указатель после входа', (
    tester,
  ) async {
    final harness = await DesignHarness.forWidgetTest(tester);
    harness.stubBasics();

    await harness.pump(tester);
    harness.container
        .read(guestWorkProvider.notifier)
        .rememberDesign('dsg_guest', role: UserRole.guest);
    expect(harness.container.read(guestWorkProvider).designId, 'dsg_guest');

    await tester.runAsync(
      () => harness.container
          .read(sessionControllerProvider.notifier)
          .signedIn(
            const AuthSession(token: 'customer', role: UserRole.customer),
          ),
    );
    final work = harness.container.read(guestWorkProvider);
    expect(work.designId, 'dsg_guest');
    expect(work.signedInSince, isTrue);

    await harness.disposeForTest(tester);
  });
}
