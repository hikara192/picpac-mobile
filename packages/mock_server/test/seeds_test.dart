import 'dart:convert';
import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:mock_server/mock_server.dart';
import 'package:test/test.dart';

void main() {
  test('the embedded seeds match the JSON files', () {
    final directory = Directory('seeds');
    if (!directory.existsSync()) {
      markTestSkipped(
        'seed files are not reachable from this working directory',
      );
      return;
    }
    for (final name in const <String>[
      'accounts.json',
      'catalog.json',
      'delivery.json',
      'payments.json',
      'promotions.json',
    ]) {
      final file = File('seeds/$name');
      expect(file.existsSync(), isTrue, reason: 'missing $name');
      final onDisk = jsonDecode(file.readAsStringSync());
      final embedded = jsonDecode(Seeds.embeddedFiles[name]!);
      expect(
        embedded,
        onDisk,
        reason:
            '$name drifted from the embedded copy; run '
            '`dart run tool/embed_seeds.dart`',
      );
    }
  });

  test('the seed catalogue produces contract-valid DTOs', () {
    final seeds = Seeds.embedded();
    final catalog = seeds.catalog.toDto();
    final json = (jsonDecode(jsonEncode(catalog.toJson())) as Map)
        .cast<String, Object?>();
    final parsed = CatalogResponse.fromJson(json);
    expect(parsed.products, hasLength(4));
    expect(parsed.currency, 'BYN');
    for (final product in parsed.products) {
      expect(product.formats, isNotEmpty);
      for (final format in product.formats) {
        expect(format.widthMm, greaterThan(0));
        expect(format.heightMm, greaterThan(0));
        expect(format.templates, isNotEmpty);
      }
    }
  });

  test('the embedded seed prices are internally consistent', () {
    final seeds = Seeds.embedded();
    final classic = seeds.catalog.productById('photo_book_classic')!;
    final format = classic.formatById('20x20')!;
    expect(format.priceForUnits(10), 8100);
    expect(format.priceForUnits(11), 8400);
    expect(format.priceForUnits(30), 14100);

    final premium = seeds.catalog
        .productById('photo_book_premium')!
        .formatById('20x20')!;
    expect(premium.priceForUnits(5), 10050);
    expect(premium.priceForUnits(10), 13550);

    final lite = seeds.catalog
        .productById('photo_book_lite')!
        .formatById('20x20')!;
    expect(lite.priceForUnits(24), 7000);
    expect(lite.priceForUnits(26), 7200);
    expect(lite.priceForUnits(160), 20600);

    final print = seeds.catalog
        .productById('photo_print')!
        .formatById('10x15')!;
    expect(print.priceForUnits(10), 1300);
  });
}
