import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/app.dart';
import 'package:picpac_mobile/app/di.dart';
import 'package:picpac_mobile/app/env.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/core/clock.dart';
import 'package:picpac_mobile/core/storage/app_database.dart';
import 'package:picpac_mobile/features/_shared/application/design_format.dart';
import 'package:picpac_mobile/network/token_store.dart';

import 'fixtures.dart';

class FakeApi extends Mock implements ApiPort {}

final class FunnelHarness {
  FunnelHarness({
    UserRole role = UserRole.customer,
    this.extraOverrides = const <Override>[],
  }) {
    api = FakeApi();
    tokens = TokenStore(InMemorySecureStore());
    database = AppDatabase(NativeDatabase.memory());
    draftRoot = Directory.systemTemp.createTempSync('picpac_funnel_');
    env = const AppEnv(apiMode: ApiMode.embedded, flavor: AppFlavor.dev);
    clock = FixedClock(testNow);
    if (role != UserRole.unknown) {
      tokens.save(AuthSession(token: 'test-token', role: role));
    }
  }

  final List<Override> extraOverrides;

  late final FakeApi api;
  late final TokenStore tokens;
  late final AppDatabase database;
  late final AppEnv env;
  late final FixedClock clock;
  late final Directory draftRoot;
  late ProviderContainer container;

  Future<void> signIn(UserRole role) async {
    await tokens.save(AuthSession(token: 'test-token', role: role));
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...appOverrides(
            env: env,
            api: api,
            tokens: tokens,
            database: database,
            clock: clock,
          ),
          draftRootProvider.overrideWithValue(() async => draftRoot),
          ...extraOverrides,
        ],
        child: PicPacApp(env: env),
      ),
    );
    await settle(tester);
    container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
  }

  void go(String location, {Object? extra}) {
    container.read(routerProvider).go(location, extra: extra);
  }

  void push(String location, {Object? extra}) {
    container.read(routerProvider).push(location, extra: extra);
  }

  Future<void> settle(WidgetTester tester, {int frames = 6}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

void registerFunnelFallbacks() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  registerFallbackValue(const AnonymousSessionRequest(locale: 'ru'));
  registerFallbackValue(const LoginRequest(email: 'a@b.c', password: 'x'));
  registerFallbackValue(<String, String>{});
  registerFallbackValue(const PriceRequest(productId: 'p', formatId: 'f'));
  registerFallbackValue(const AddCartItemRequest(designId: 'd'));
  registerFallbackValue(const UpdateCartItemRequest(itemId: 'i'));
  registerFallbackValue(
    const CheckoutRequest(
      cartId: 'c',
      delivery: DeliverySelection(kind: DeliveryKind.pickup),
      contact: ContactInfo(name: 'n', phone: '1'),
    ),
  );
  registerFallbackValue(
    const CreateTicketRequest(
      subject: 's',
      body: 'b',
      type: TicketType.question,
    ),
  );
  registerFallbackValue(
    const PostTicketMessageRequest(ticketId: 't', body: 'b'),
  );
  registerFallbackValue(
    const CreateOrderRequest(
      lines: <OrderLineRequest>[],
      delivery: DeliverySelection(kind: DeliveryKind.pickup),
      contact: ContactInfo(name: 'n', phone: '1'),
    ),
  );
  registerFallbackValue(
    DesignDocument.start(
      product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
    ),
  );
  registerFallbackValue(
    const CreatePaymentIntentRequest(orderId: 'o', methodId: 'bank_card'),
  );
}
