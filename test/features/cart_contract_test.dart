import 'package:api_contract/api_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/app/bootstrap.dart';
import 'package:picpac_mobile/app/env.dart';
import 'package:picpac_mobile/core/orders/cart_pricing.dart';
import 'package:picpac_mobile/core/orders/cart_repository.dart';
import 'package:picpac_mobile/core/session/session_service.dart';
import 'package:picpac_mobile/core/storage/app_database.dart';
import 'package:picpac_mobile/network/token_store.dart';

void main() {
  Future<AppDependencies> boot() async {
    final dependencies = await bootstrap(
      env: const AppEnv(apiMode: ApiMode.embedded, flavor: AppFlavor.dev),
      secureStore: InMemorySecureStore(),
      database: AppDatabase(NativeDatabase.memory()),
    );
    addTearDown(dependencies.dispose);
    return dependencies;
  }

  DesignDocument printDesign({required int sheets, int revision = 1}) =>
      DesignDocument(
        revision: revision,
        product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
        spreads: <Spread>[
          for (var index = 0; index < sheets; index++)
            Spread(
              id: 'sheet_${index + 1}',
              templateId: 'single_10x15',
              background: SpreadBackground.color('#FAF5ED'),
              slots: <Slot>[
                Slot(
                  id: 'main',
                  photoId: 'photo_${index + 1}',
                  crop: Crop.full,
                  zoom: Slot.minZoom,
                  anchor: NormalizedPoint.center,
                ),
              ],
            ),
        ],
        spreadsCount: sheets,
        assets: <PhotoAsset>[
          for (var index = 0; index < sheets; index++)
            PhotoAsset(
              id: 'photo_${index + 1}',
              sha256: '${index + 1}'.padLeft(64, 'a'),
              widthPx: 1600,
              heightPx: 2400,
              mimeType: 'image/jpeg',
              bytes: 220000,
            ),
        ],
      );

  test('10 листов стоят как 10 листов, а не как один', () async {
    final dependencies = await boot();
    await dependencies.api.login(
      const LoginRequest(email: 'customer@picpac.test', password: 'Test1234'),
    );

    final created = await dependencies.api.createDesign(
      printDesign(sheets: 10),
    );
    final design = created.requireValue;
    final format = (await dependencies.api.formats('photo_print')).requireValue
        .firstWhere((candidate) => candidate.id == '10x15');

    final quantity = cartQuantityFor(format: format, document: design.document);
    expect(quantity, 10);

    final added = await dependencies.api.addCartItem(
      AddCartItemRequest(designId: design.id, quantity: quantity),
    );
    final cart = added.requireValue;
    expect(cart.items.single.quantity, 10);
    expect(cart.subtotal.amountMinor, 1300);
    expect(cart.items.single.quote.total.amountMinor, 1300);

    final quote = await dependencies.api.price(
      PriceRequest(
        productId: 'photo_print',
        formatId: '10x15',
        spreadsCount: quantity,
      ),
    );
    expect(quote.requireValue.total.amountMinor, 1300);
  });

  test('две добавленные фотографии пересчитывают корзину на сервере', () async {
    final dependencies = await boot();
    await dependencies.api.login(
      const LoginRequest(email: 'customer@picpac.test', password: 'Test1234'),
    );
    final session = SessionService(
      api: dependencies.api,
      tokens: dependencies.tokens,
    );
    final repository = CartRepository(api: dependencies.api, session: session);

    final created = await dependencies.api.createDesign(
      printDesign(sheets: 10),
    );
    final design = created.requireValue;
    final added = await dependencies.api.addCartItem(
      AddCartItemRequest(designId: design.id, quantity: 10),
    );
    expect(added.requireValue.subtotal.amountMinor, 1300);

    final updated = await dependencies.api.putDesign(
      design.id,
      printDesign(sheets: 12, revision: 2),
      ifMatchRevision: design.revision,
    );
    expect(updated.isOk, isTrue, reason: '${updated.failureOrNull}');

    final context = (await repository.load()).requireValue;
    expect(context.cart.items.single.quantity, 12);
    expect(context.cart.subtotal.amountMinor, 1560);
    expect(context.reconciled, isTrue);
  });

  test('плотная раскладка: 10 листов 13,00 BYN → 4 листа 5,20 BYN', () async {
    final dependencies = await boot();
    await dependencies.api.login(
      const LoginRequest(email: 'customer@picpac.test', password: 'Test1234'),
    );
    final session = SessionService(
      api: dependencies.api,
      tokens: dependencies.tokens,
    );
    final repository = CartRepository(api: dependencies.api, session: session);

    final format = (await dependencies.api.formats('photo_print')).requireValue
        .firstWhere((candidate) => candidate.id == '10x15');
    final document = AutoLayoutSheets(
      template: format.templates.first.toPrintTemplate(),
    ).applyCore(printDesign(sheets: 10));

    final created = await dependencies.api.createDesign(document);
    final design = created.requireValue;
    expect(design.document.spreads, hasLength(10));

    final added = await dependencies.api.addCartItem(
      AddCartItemRequest(designId: design.id, quantity: 10),
    );
    expect(added.requireValue.subtotal.amountMinor, 1300);

    final plan = LayoutPlanner.planSheets(
      photos: document.assets,
      templates: format.templateMap().values.toList(),
    );
    expect(plan.sheetCount, 4);
    final denser = plan.applyTo(document);
    expect(denser.spreads, hasLength(4));

    final updated = await dependencies.api.putDesign(
      design.id,
      denser,
      ifMatchRevision: design.revision,
    );
    expect(updated.isOk, isTrue, reason: '${updated.failureOrNull}');

    final context = (await repository.load()).requireValue;
    expect(context.cart.items.single.quantity, 4);
    expect(context.cart.subtotal.amountMinor, 520);
    expect(context.cart.items.single.quote.total.amountMinor, 520);
    expect(context.reconciled, isTrue);
  });
}
