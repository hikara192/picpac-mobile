import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/app/theme/app_theme.dart';
import 'package:picpac_mobile/app/theme/tokens.dart';
import 'package:picpac_mobile/core/presentation/text_tones.dart';
import 'package:picpac_mobile/render/sheet_painter.dart';

double _luminance(int argb) {
  double channel(int value) {
    final srgb = value / 255;
    return srgb <= 0.03928
        ? srgb / 12.92
        : math.pow((srgb + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = channel((argb >> 16) & 0xFF);
  final g = channel((argb >> 8) & 0xFF);
  final b = channel(argb & 0xFF);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrast(int foreground, int background) {
  final a = _luminance(foreground);
  final b = _luminance(background);
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('brand contrast', () {
    test('ink on background is AAA', () {
      expect(
        contrast(
          PicPacColors.ink.toARGB32(),
          PicPacColors.background.toARGB32(),
        ),
        greaterThanOrEqualTo(7),
      );
    });

    test('accentText on background is AA for small text', () {
      expect(
        contrast(
          PicPacColors.accentText.toARGB32(),
          PicPacColors.background.toARGB32(),
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('accent is not used for small text (documents the rule)', () {
      final ratio = contrast(
        PicPacColors.accent.toARGB32(),
        PicPacColors.background.toARGB32(),
      );
      expect(ratio, lessThan(4.5));
    });

    test('white on ink is AAA', () {
      expect(
        contrast(PicPacColors.surface.toARGB32(), PicPacColors.ink.toARGB32()),
        greaterThanOrEqualTo(7),
      );
    });
  });

  group('theme', () {
    test('uses the brand font and pill buttons', () {
      final theme = AppTheme.light();
      expect(theme.textTheme.bodyMedium?.fontFamily, 'FuturaPT');
      expect(
        theme.filledButtonTheme.style?.shape?.resolve(<WidgetState>{}),
        isA<StadiumBorder>(),
      );
      expect(theme.scaffoldBackgroundColor, PicPacColors.background);
    });

    test('minimum touch target is at least 48 dp', () {
      final theme = AppTheme.light();
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
      final size = theme.filledButtonTheme.style?.minimumSize?.resolve(
        <WidgetState>{},
      );
      expect(size!.height, greaterThanOrEqualTo(48));
    });
  });

  group('small text is AA', () {
    test('navigation labels: 14 px ink on the white bar', () {
      final theme = AppTheme.light();
      final style = theme.navigationBarTheme.labelTextStyle!;
      final selected = style.resolve(<WidgetState>{WidgetState.selected});
      final rest = style.resolve(<WidgetState>{});
      expect(selected!.fontSize, 14);
      expect(selected.fontWeight, FontWeight.w500);
      expect(rest!.fontSize, 14);
      for (final colour in <Color>[selected.color!, rest.color!]) {
        expect(
          contrast(colour.toARGB32(), PicPacColors.surface.toARGB32()),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('field label and hint on the beige field are AA', () {
      final theme = AppTheme.light();
      final label = theme.inputDecorationTheme.labelStyle!;
      final hint = theme.inputDecorationTheme.hintStyle!;
      expect(label.color, PicPacColors.secondaryText);
      expect(hint.color, PicPacColors.secondaryText);
      expect(
        contrast(
          label.color!.toARGB32(),
          PicPacColors.backgroundAlt.toARGB32(),
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('the visible muted tone is documented as too weak for small text', () {
      expect(
        contrast(
          PicPacColors.muted.toARGB32(),
          PicPacColors.backgroundAlt.toARGB32(),
        ),
        lessThan(4.5),
      );
    });

    test('secondaryText stays in sync with the funnel alias', () {
      expect(FunnelText.secondary, PicPacColors.secondaryText);
    });
  });

  group('hierarchy and shapes', () {
    test('app bar title is headlineSmall 24/400, cards keep 20/500', () {
      final theme = AppTheme.light();
      final title = theme.appBarTheme.titleTextStyle!;
      expect(title.fontSize, theme.textTheme.headlineSmall!.fontSize);
      expect(title.fontSize, 24);
      expect(title.fontWeight, FontWeight.w400);
      expect(theme.textTheme.titleMedium!.fontSize, 20);
      expect(theme.textTheme.titleMedium!.fontWeight, FontWeight.w500);
    });

    test('dialogs and sheets use the 20 px brand radius on white', () {
      final theme = AppTheme.light();

      final dialogShape = theme.dialogTheme.shape! as RoundedRectangleBorder;
      final dialogRadius = dialogShape.borderRadius as BorderRadius;
      expect(dialogRadius.topLeft.x, 20);
      expect(theme.dialogTheme.backgroundColor, PicPacColors.surface);
      expect(theme.dialogTheme.titleTextStyle!.fontSize, 20);

      final sheetShape =
          theme.bottomSheetTheme.shape! as RoundedRectangleBorder;
      final sheetRadius = sheetShape.borderRadius as BorderRadius;
      expect(sheetRadius.topLeft.x, 20);
      expect(sheetRadius.bottomLeft.x, 0);
      expect(theme.bottomSheetTheme.backgroundColor, PicPacColors.surface);
    });

    test('soft coral plate carries ink text, not small coral text', () {
      expect(
        contrast(
          PicPacColors.accentText.toARGB32(),
          PicPacColors.accentSoft.toARGB32(),
        ),
        lessThan(4.5),
      );
      expect(
        contrast(
          PicPacColors.ink.toARGB32(),
          PicPacColors.accentSoft.toARGB32(),
        ),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('scene palette', () {
    test('empty slots use brand tokens, not off-palette greys', () {
      const palette = SheetPalette();
      expect(palette.emptyFill, PicPacColors.fillStone);
      expect(palette.emptyBorder, PicPacColors.borderStrong);
      expect(palette.emptyGlyph, PicPacColors.mutedLight);
      expect(palette.paper, PicPacColors.surface);
      expect(palette.outline, PicPacColors.border);
      expect(palette.selection, PicPacColors.accent);
    });
  });

  group('app icon', () {
    test('iOS icon is the brand plate, opaque', () async {
      final file = File(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      );
      final bytes = file.readAsBytesSync();
      expect(bytes[25], 2);

      final image = await _decode(bytes);
      expect(await _pixel(image, 4, 4), PicPacColors.background.toARGB32());
      expect(await _pixel(image, 512, 200), PicPacColors.accent.toARGB32());
    });

    test('Android adaptive foreground keeps the emblem inside the safe zone', () async {
      final file = File(
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png',
      );
      final image = await _decode(file.readAsBytesSync());
      expect(image.width, 432);
      expect(await _pixel(image, 2, 2), 0x00000000);
      expect(await _pixel(image, 216, 216), PicPacColors.accent.toARGB32());
    });
  });
}

Future<ui.Image> _decode(List<int> bytes) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  return (await codec.getNextFrame()).image;
}

Future<int> _pixel(ui.Image image, int x, int y) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final offset = (y * image.width + x) * 4;
  final r = data!.getUint8(offset);
  final g = data.getUint8(offset + 1);
  final b = data.getUint8(offset + 2);
  final a = data.getUint8(offset + 3);
  return (a << 24) | (r << 16) | (g << 8) | b;
}
