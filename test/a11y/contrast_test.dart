import 'dart:math' as math;

import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/app/theme/app_theme.dart';
import 'package:picpac_mobile/app/theme/tokens.dart';
import 'package:picpac_mobile/core/presentation/text_tones.dart';

import '../features/support/mock_harness.dart';

double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double contrastRatio(Color foreground, Color background) {
  final a = _luminance(foreground);
  final b = _luminance(background);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  group('контраст: текст на фоне', () {
    const pairs = <({String name, Color fg, Color bg, double min})>[
      (
        name: 'ink на background',
        fg: PicPacColors.ink,
        bg: PicPacColors.background,
        min: 4.5,
      ),
      (
        name: 'ink на surface',
        fg: PicPacColors.ink,
        bg: PicPacColors.surface,
        min: 4.5,
      ),
      (
        name: 'ink на backgroundAlt',
        fg: PicPacColors.ink,
        bg: PicPacColors.backgroundAlt,
        min: 4.5,
      ),
      (
        name: 'ink на surfaceMuted',
        fg: PicPacColors.ink,
        bg: PicPacColors.surfaceMuted,
        min: 4.5,
      ),
      (
        name: 'secondaryText на background',
        fg: PicPacColors.secondaryText,
        bg: PicPacColors.background,
        min: 4.5,
      ),
      (
        name: 'secondaryText на surface',
        fg: PicPacColors.secondaryText,
        bg: PicPacColors.surface,
        min: 4.5,
      ),
      (
        name: 'secondaryText на backgroundAlt',
        fg: PicPacColors.secondaryText,
        bg: PicPacColors.backgroundAlt,
        min: 4.5,
      ),
      (
        name: 'secondaryText на surfaceMuted',
        fg: PicPacColors.secondaryText,
        bg: PicPacColors.surfaceMuted,
        min: 4.5,
      ),
      (
        name: 'accentText на background',
        fg: PicPacColors.accentText,
        bg: PicPacColors.background,
        min: 4.5,
      ),
      (
        name: 'accentText на surface',
        fg: PicPacColors.accentText,
        bg: PicPacColors.surface,
        min: 4.5,
      ),
      (
        name: 'accentText на backgroundAlt',
        fg: PicPacColors.accentText,
        bg: PicPacColors.backgroundAlt,
        min: 4.5,
      ),
      (
        name: 'accentText на surfaceMuted',
        fg: PicPacColors.accentText,
        bg: PicPacColors.surfaceMuted,
        min: 4.5,
      ),
      (
        name: 'surface на ink (кнопка)',
        fg: PicPacColors.surface,
        bg: PicPacColors.ink,
        min: 4.5,
      ),
      (
        name: 'inkStrong на fillMint',
        fg: PicPacColors.inkStrong,
        bg: PicPacColors.fillMint,
        min: 4.5,
      ),
      (
        name: 'inkStrong на fillBlue',
        fg: PicPacColors.inkStrong,
        bg: PicPacColors.fillBlue,
        min: 4.5,
      ),
      (
        name: 'inkStrong на fillStone',
        fg: PicPacColors.inkStrong,
        bg: PicPacColors.fillStone,
        min: 4.5,
      ),
      (
        name: 'inkStrong на fillBeige',
        fg: PicPacColors.inkStrong,
        bg: PicPacColors.fillBeige,
        min: 4.5,
      ),
      (
        name: 'ink на accentSoft (выбранный чип)',
        fg: PicPacColors.ink,
        bg: PicPacColors.accentSoft,
        min: 4.5,
      ),
      (
        name: 'ink на fillBeige',
        fg: PicPacColors.ink,
        bg: PicPacColors.fillBeige,
        min: 4.5,
      ),
      (
        name: 'ink на fillBlue',
        fg: PicPacColors.ink,
        bg: PicPacColors.fillBlue,
        min: 4.5,
      ),
      (
        name: 'ink на fillMint',
        fg: PicPacColors.ink,
        bg: PicPacColors.fillMint,
        min: 4.5,
      ),
      (
        name: 'accent на background (только крупный)',
        fg: PicPacColors.accent,
        bg: PicPacColors.background,
        min: 3.0,
      ),
      (
        name: 'surface на accent (только ≥18/500)',
        fg: PicPacColors.surface,
        bg: PicPacColors.accent,
        min: 3.0,
      ),
      (
        name: 'muted на background (только крупный)',
        fg: PicPacColors.muted,
        bg: PicPacColors.background,
        min: 3.0,
      ),
    ];

    for (final pair in pairs) {
      test(pair.name, () {
        expect(
          contrastRatio(pair.fg, pair.bg),
          greaterThanOrEqualTo(pair.min),
          reason:
              '${pair.name}: '
              '${contrastRatio(pair.fg, pair.bg).toStringAsFixed(2)} '
              '< ${pair.min}',
        );
      });
    }
  });

  group('тона, которые нельзя использовать мелким текстом', () {
    test('muted ниже AA для 14 px — только крупный второстепенный', () {
      expect(
        contrastRatio(PicPacColors.muted, PicPacColors.background),
        lessThan(4.5),
      );
    });

    test('mutedLight — декор, не текст', () {
      expect(
        contrastRatio(PicPacColors.mutedLight, PicPacColors.background),
        lessThan(3),
      );
    });

    test('коралл на мягком коралле не годится для мелкого текста', () {
      expect(
        contrastRatio(PicPacColors.accentText, PicPacColors.accentSoft),
        lessThan(4.5),
      );
    });

    test('FunnelText.secondary — это тот же тон, что secondaryText темы', () {
      expect(FunnelText.secondary, PicPacColors.secondaryText);
    });
  });

  group('контраст реально настроенных компонентов темы', () {
    final theme = AppTheme.light();

    test('подписи навигации на белой панели', () {
      final style = theme.navigationBarTheme.labelTextStyle!;
      for (final states in <Set<WidgetState>>[
        <WidgetState>{},
        <WidgetState>{WidgetState.selected},
      ]) {
        final resolved = style.resolve(states)!;
        expect(
          contrastRatio(resolved.color!, PicPacColors.surface),
          greaterThanOrEqualTo(4.5),
          reason: 'навигация $states',
        );
      }
    });

    test('ошибка поля на бежевом фоне', () {
      final style = theme.inputDecorationTheme.errorStyle!;
      expect(
        contrastRatio(style.color!, PicPacColors.backgroundAlt),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('лейбл и подсказка поля на бежевом фоне', () {
      for (final style in <TextStyle?>[
        theme.inputDecorationTheme.labelStyle,
        theme.inputDecorationTheme.hintStyle,
      ]) {
        expect(
          contrastRatio(style!.color!, PicPacColors.backgroundAlt),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('текст снекбара на ink', () {
      final style = theme.snackBarTheme.contentTextStyle!;
      expect(
        contrastRatio(style.color!, theme.snackBarTheme.backgroundColor!),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('заголовок и тело диалога на белом', () {
      for (final style in <TextStyle?>[
        theme.dialogTheme.titleTextStyle,
        theme.dialogTheme.contentTextStyle,
      ]) {
        expect(
          contrastRatio(style!.color!, theme.dialogTheme.backgroundColor!),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('заголовок экрана на кремовом фоне', () {
      final style = theme.appBarTheme.titleTextStyle!;
      expect(
        contrastRatio(style.color!, PicPacColors.background),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('CTA: белый текст на ink, отключённый — muted на fillGray', () {
      final filled = theme.filledButtonTheme.style!;
      expect(
        contrastRatio(
          filled.foregroundColor!.resolve(<WidgetState>{})!,
          filled.backgroundColor!.resolve(<WidgetState>{})!,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(
          filled.foregroundColor!.resolve(<WidgetState>{WidgetState.disabled})!,
          filled.backgroundColor!.resolve(<WidgetState>{WidgetState.disabled})!,
        ),
        greaterThanOrEqualTo(2.0),
      );
    });
  });

  group('контраст фактических стилей экранов', () {
    Color backgroundOf(Element element) {
      Color? found;
      element.visitAncestorElements((ancestor) {
        final widget = ancestor.widget;
        if (widget is Material && widget.color != null) {
          found = widget.color;
          return false;
        }
        if (widget is ColoredBox) {
          found = widget.color;
          return false;
        }
        if (widget is Container) {
          final decoration = widget.decoration;
          if (decoration is BoxDecoration && decoration.color != null) {
            found = decoration.color;
            return false;
          }
          final color = widget.color;
          if (color != null) {
            found = color;
            return false;
          }
        }
        if (widget is DecoratedBox) {
          final decoration = widget.decoration;
          if (decoration is BoxDecoration && decoration.color != null) {
            found = decoration.color;
            return false;
          }
        }
        return true;
      });
      return found ?? Theme.of(element).scaffoldBackgroundColor;
    }

    ({double ratio, double size, FontWeight weight, Color fg, Color bg})
    measure(WidgetTester tester, Finder finder) {
      final element = tester.element(finder);
      final text = element.widget as Text;
      final style = text.style ?? DefaultTextStyle.of(element).style;
      final context = element;
      final theme = Theme.of(context);
      final fg = style.color ?? theme.colorScheme.onSurface;
      final bg = backgroundOf(element);
      final size = style.fontSize ?? theme.textTheme.bodyMedium?.fontSize ?? 14;
      final weight =
          style.fontWeight ??
          theme.textTheme.bodyMedium?.fontWeight ??
          FontWeight.w400;
      return (
        ratio: contrastRatio(fg, bg),
        size: size,
        weight: weight,
        fg: fg,
        bg: bg,
      );
    }

    double minimumFor(double size, FontWeight weight) =>
        size >= 24 || (size >= 18.66 && weight.value >= FontWeight.w500.value)
        ? 3.0
        : 4.5;

    void expectAa(WidgetTester tester, Finder finder, String what) {
      final m = measure(tester, finder);
      expect(
        m.ratio,
        greaterThanOrEqualTo(minimumFor(m.size, m.weight)),
        reason:
            '$what: ${m.ratio.toStringAsFixed(2)}:1 '
            '(${m.fg} on ${m.bg}, ${m.size}px/${m.weight.value})',
      );
    }

    testWidgets('корзина: строки, единица и сумма', (tester) async {
      final live = await MockHarness.forWidgetTest(tester);
      final design = await live.setup(
        tester,
        () => live.createPrintDesign(sheets: 3),
      );
      await live.setup(tester, () => live.addToCart(design.id, quantity: 3));
      await live.pump(tester, location: AppRoutes.cart);

      expectAa(
        tester,
        find.text('Печать фотографий 10×15'),
        'название позиции',
      );
      expectAa(tester, find.text('3 листа'), 'единица позиции');
      expectAa(tester, find.text('Итого'), 'подпись суммы');
      expectAa(tester, find.text('3,90 BYN').first, 'сумма корзины');

      await live.disposeForTest(tester);
    });

    testWidgets('заказ: чип статуса и итог', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final live = await MockHarness.forWidgetTest(tester);
      final order = await live.setup(tester, () => live.placeOrder());
      await live.pump(tester, location: AppRoutes.orderFor(order.id));
      await live.settle(tester);

      expectAa(tester, find.text('Заказ ${order.number}'), 'заголовок заказа');
      expectAa(tester, find.text('Оплата'), 'подпись оси оплаты');
      expectAa(tester, find.text('Ожидает оплаты'), 'чип статуса оплаты');
      expectAa(tester, find.text('Оформлен').first, 'чип статуса готовности');

      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await live.settle(tester);
      expectAa(tester, find.text('Итого').first, 'подпись итога');

      await live.disposeForTest(tester);
    });

    testWidgets('вход: обещание и подсказка', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final live = await MockHarness.forWidgetTest(
        tester,
        role: UserRole.unknown,
      );
      await live.pump(tester, location: AppRoutes.login);

      expectAa(tester, find.text('Вход в PicPac'), 'заголовок экрана');
      expectAa(
        tester,
        find.text('Храните воспоминания красиво'),
        'обещание экрана',
      );

      await live.disposeForTest(tester);
    });
  });
}
