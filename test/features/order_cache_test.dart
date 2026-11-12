import 'package:api_contract/api_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/core/clock.dart';
import 'package:picpac_mobile/core/orders/order_cache.dart';
import 'package:picpac_mobile/core/storage/app_database.dart';

import 'support/fixtures.dart';

void main() {
  late AppDatabase database;
  late OrderCache cache;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    cache = OrderCache(database: database, clock: FixedClock(testNow));
  });

  tearDown(() async {
    await database.close();
  });

  test('кеш хранит и отдаёт последний Order без потери сумм', () async {
    await cache.save(orderFixture());

    final loaded = await cache.load('ord_1');

    expect(loaded, isNotNull);
    expect(loaded!.number, 'PP-1001');
    expect(loaded.totals.total.amountMinor, 2600);
    expect(loaded.totals.total.currency, 'BYN');
    expect(loaded.paymentStatus.isPaid, isFalse);
    expect(await cache.recent(), hasLength(1));
  });

  test('повторное сохранение обновляет, а не дублирует заказ', () async {
    await cache.save(orderFixture());
    await cache.save(orderFixture(paymentStatus: PaymentStatus.succeeded));

    final recent = await cache.recent();
    expect(recent, hasLength(1));
    expect(recent.single.paymentStatus, PaymentStatus.succeeded);
  });

  test('битый payload не роняет чтение кеша', () async {
    await database
        .into(database.ordersCache)
        .insert(
          OrdersCacheCompanion.insert(
            orderId: 'broken',
            number: 'X',
            payload: '{not json',
            updatedAt: testNow,
          ),
        );

    expect(await cache.load('broken'), isNull);
    expect(await cache.recent(), isEmpty);
  });

  test('clear удаляет все заказы', () async {
    await cache.save(orderFixture());
    await cache.clear();
    expect(await cache.recent(), isEmpty);
  });
}
