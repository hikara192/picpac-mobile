import 'dart:io';
import 'dart:typed_data';

import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:integration_test/integration_test.dart';
import 'package:picpac_mobile/app/app.dart';
import 'package:picpac_mobile/app/bootstrap.dart';
import 'package:picpac_mobile/app/di.dart';
import 'package:picpac_mobile/app/env.dart';
import 'package:picpac_mobile/core/media/photo_picker.dart';
import 'package:picpac_mobile/features/_shared/application/media_providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('гость проходит путь до заказа и обращения', (tester) async {
    final dependencies = await bootstrap(
      env: const AppEnv(apiMode: ApiMode.embedded, flavor: AppFlavor.dev),
    );
    addTearDown(dependencies.dispose);
    await dependencies.tokens.clear();

    final directory = await Directory.systemTemp.createTemp('picpac-e2e');
    final photo = await _writePng(directory);
    final picker = _FixturePicker(photo);

    runApp(
      ProviderScope(
        overrides: <Override>[
          ...appOverrides(
            env: dependencies.env,
            api: dependencies.api,
            tokens: dependencies.tokens,
            database: dependencies.database,
          ),
          photoPickerProvider.overrideWithValue(picker),
        ],
        child: PicPacApp(env: dependencies.env),
      ),
    );
    await _pumpUntil(tester, find.byType(Navigator));

    await _buildProjectIntoCart(tester);

    await _pumpUntil(tester, find.text('Оформить'));
    await tester.tap(find.text('Оформить'));
    await tester.pump(const Duration(milliseconds: 300));
    if (find.text('Понятно, войти').evaluate().isNotEmpty) {
      await tester.tap(find.text('Понятно, войти'));
    }
    await _pumpUntil(tester, find.text('Вход в PicPac'));
    await screenshotPause(tester, 'login');

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'customer@picpac.test',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'Test1234');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));

    await _pumpUntil(tester, find.text('Корзина пуста'));
    await tester.tap(find.text('В каталог'));
    await _pumpUntil(tester, find.text('Печать фотографий'));

    await _buildProjectIntoCart(tester);
    await _pumpUntil(tester, find.text('Оформить'));
    await tester.tap(find.text('Оформить'));
    await _pumpUntil(tester, find.text('Самовывоз'));

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('PicPac на Минском').first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(
      find.byKey(const Key('checkout-name')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('checkout-name')),
      'Тестовый клиент',
    );
    await tester.enterText(
      find.byKey(const Key('checkout-phone')),
      '+375 29 123 45 67',
    );
    await tester.pump();
    await tester.tap(find.text('Оформить заказ'));
    await _pumpUntil(
      tester,
      find.textContaining('Заказ PP-'),
      timeout: const Duration(seconds: 30),
    );
    final orderNumber = tester
        .widgetList<Text>(find.textContaining('Заказ PP-'))
        .first
        .data!;

    await tester.scrollUntilVisible(
      find.text('Проблема с заказом'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Проблема с заказом'));
    await _pumpUntil(tester, find.text('Поддержка'));
    await screenshotPause(tester, 'support');

    await tester.tap(find.byTooltip('Новое обращение'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ticket-subject')),
      'Проверка пути',
    );
    await tester.enterText(
      find.byKey(const Key('ticket-body')),
      'Оформлено в конце сквозного теста $orderNumber.',
    );
    await tester.pump();
    await tester.tap(find.text('Создать обращение'));
    await _pumpUntil(tester, find.text('Проверка пути'));

    ScaffoldMessenger.of(tester.element(find.byType(Navigator).first))
        .clearSnackBars();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Профиль').last);
    await _pumpUntil(tester, find.text('customer@picpac.test'));
    await screenshotPause(tester, 'profile');

    expect(find.text('Клиент'), findsOneWidget);
    expect(find.text('Все действия отправлены.'), findsOneWidget);
  });
}

Future<void> _buildProjectIntoCart(WidgetTester tester) async {
  await _pumpUntil(tester, find.text('Печать фотографий'));
  await tester.tap(find.text('Печать фотографий').first);
  await _pumpUntil(tester, find.textContaining('Собрать'));

  await tester.tap(find.textContaining('Собрать').first);
  await _pumpUntil(tester, find.text('Добавить фото'));

  final addPhotos = find.text('Добавить фото').first;
  await tester.ensureVisible(addPhotos);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(addPhotos);
  await _pumpUntil(
    tester,
    find.text('Проверить'),
    timeout: const Duration(seconds: 30),
  );
  await tester.pump(const Duration(seconds: 3));

  await tester.tap(find.text('Проверить'));
  await _pumpUntil(
    tester,
    find.text('В корзину'),
    timeout: const Duration(seconds: 30),
  );
  await tester.tap(find.text('В корзину'));
}

Future<void> screenshotPause(WidgetTester tester, String name) async {
  // ignore: avoid_print
  print('PICSCREEN:$name');
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('timed out waiting for $finder');
}

final class _FixturePicker implements PhotoPickerPort {
  _FixturePicker(this._file);

  final File _file;

  @override
  Future<Result<List<PickedFile>>> pickImages({int? limit}) async {
    final bytes = await _file.length();
    return Ok<List<PickedFile>>(<PickedFile>[
      PickedFile(
        path: _file.path,
        name: 'e2e-photo.png',
        mimeType: 'image/png',
        bytes: bytes,
      ),
    ]);
  }

  @override
  Future<Result<List<PickedFile>>> recoverLostSelection() async =>
      const Ok<List<PickedFile>>(<PickedFile>[]);
}

Future<File> _writePng(Directory directory) async {
  const width = 600;
  const height = 400;
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < width; x++) {
      raw.add(<int>[
        180 + (x * 60 ~/ width),
        120 + (y * 80 ~/ height),
        110,
        255,
      ]);
    }
  }
  final idat = ZLibEncoder().convert(raw.takeBytes());
  final png = BytesBuilder()
    ..add(const <int>[137, 80, 78, 71, 13, 10, 26, 10])
    ..add(_chunk('IHDR', <int>[..._u32(width), ..._u32(height), 8, 6, 0, 0, 0]))
    ..add(_chunk('IDAT', idat))
    ..add(_chunk('IEND', const <int>[]));
  final file = File('${directory.path}/e2e-photo.png');
  await file.writeAsBytes(png.takeBytes());
  return file;
}

List<int> _u32(int value) => <int>[
  (value >> 24) & 0xff,
  (value >> 16) & 0xff,
  (value >> 8) & 0xff,
  value & 0xff,
];

List<int> _chunk(String type, List<int> data) {
  final payload = <int>[...type.codeUnits, ...data];
  return <int>[..._u32(data.length), ...payload, ..._u32(_crc32(payload))];
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
