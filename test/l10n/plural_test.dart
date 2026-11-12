import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/l10n/app_localizations.dart';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final be = lookupAppLocalizations(const Locale('be'));

  group('ru: категории 1 / 2 / 5 / 11 / 21', () {
    test('листы', () {
      expect(ru.cartSheetsUnit(1), '1 лист');
      expect(ru.cartSheetsUnit(2), '2 листа');
      expect(ru.cartSheetsUnit(5), '5 листов');
      expect(ru.cartSheetsUnit(11), '11 листов');
      expect(ru.cartSheetsUnit(21), '21 лист');
    });

    test('книги и развороты', () {
      expect(ru.cartBooksUnit(1), '1 книга');
      expect(ru.cartBooksUnit(3), '3 книги');
      expect(ru.cartBooksUnit(8), '8 книг');
      expect(ru.cartSpreadsUnit(1), '1 разворот');
      expect(ru.cartSpreadsUnit(4), '4 разворота');
      expect(ru.cartSpreadsUnit(20), '20 разворотов');
    });

    test('фото, попытки и черновики', () {
      expect(ru.projectsPhotos(1), '1 фото');
      expect(ru.projectsPhotos(5), '5 фото');
      expect(ru.profileQueueAttempts(1), '1 попытка');
      expect(ru.profileQueueAttempts(2), '2 попытки');
      expect(ru.profileQueueAttempts(5), '5 попыток');
      expect(ru.profileDeleteTestDataDone(1), contains('Удалён 1 черновик'));
      expect(ru.profileDeleteTestDataDone(2), contains('Удалено 2 черновика'));
      expect(ru.profileDeleteTestDataDone(5), contains('Удалено 5 черновиков'));
    });

    test('раскладка «на N листов меньше»', () {
      expect(ru.createLayoutBody(4, 10), '4 листа вместо 10');
      expect(ru.createLayoutBody(1, 5), '1 лист вместо 5');
      expect(ru.createLayoutBody(7, 10), '7 листов вместо 10');
    });
  });

  group('be: категории 1 / 2 / 5 / 11 / 21', () {
    test('лісты', () {
      expect(be.cartSheetsUnit(1), '1 ліст');
      expect(be.cartSheetsUnit(2), '2 лісты');
      expect(be.cartSheetsUnit(5), '5 лістоў');
      expect(be.cartSheetsUnit(11), '11 лістоў');
      expect(be.cartSheetsUnit(21), '21 ліст');
      expect(be.cartSheetsUnit(22), '22 лісты');
    });

    test('кнігі і развароты', () {
      expect(be.cartBooksUnit(1), '1 кніга');
      expect(be.cartBooksUnit(3), '3 кнігі');
      expect(be.cartBooksUnit(8), '8 кніг');
      expect(be.cartSpreadsUnit(1), '1 разварот');
      expect(be.cartSpreadsUnit(4), '4 развароты');
      expect(be.cartSpreadsUnit(20), '20 разваротаў');
    });

    test('фота, спробы і чарнавікі', () {
      expect(be.projectsPhotos(1), '1 фота');
      expect(be.projectsPhotos(5), '5 фота');
      expect(be.profileQueueAttempts(1), '1 спроба');
      expect(be.profileQueueAttempts(2), '2 спробы');
      expect(be.profileQueueAttempts(5), '5 спроб');
      expect(be.profileQueueAttempts(11), '11 спроб');
      expect(be.profileDeleteTestDataDone(1), contains('Выдалены 1 чарнавік'));
      expect(be.profileDeleteTestDataDone(2), contains('Выдалена 2 чарнавікі'));
      expect(
        be.profileDeleteTestDataDone(5),
        contains('Выдалена 5 чарнавікоў'),
      );
    });

    test('раскладка «на N лістоў менш»', () {
      expect(be.createLayoutBody(4, 10), '4 лісты замест 10');
      expect(be.createLayoutBody(1, 5), '1 ліст замест 5');
      expect(be.createLayoutBody(7, 10), '7 лістоў замест 10');
    });
  });

  test('плюрал не оставляет фигурных скобок на экране', () {
    for (final AppLocalizations l10n in <AppLocalizations>[ru, be]) {
      for (final int count in <int>[1, 2, 5, 11, 21]) {
        expect(l10n.cartSheetsUnit(count), isNot(contains('{')));
        expect(l10n.profileQueueAttempts(count), isNot(contains('{')));
      }
    }
  });
}
