import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme_extensions.dart';
import 'tokens.dart';

abstract final class AppTheme {
  static const TextStyle rootTabTitle = TextStyle(
    fontFamily: 'FuturaPT',
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 1.15,
    letterSpacing: -0.2,
    color: PicPacColors.ink,
  );

  static const TextStyle detailTitle = TextStyle(
    fontFamily: 'FuturaPT',
    fontSize: 24,
    fontWeight: FontWeight.w400,
    color: PicPacColors.ink,
  );

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: PicPacColors.ink,
      onPrimary: PicPacColors.surface,
      secondary: PicPacColors.accent,
      onSecondary: PicPacColors.surface,
      secondaryContainer: PicPacColors.accentSoft,
      onSecondaryContainer: PicPacColors.ink,
      error: PicPacColors.accentHover,
      onError: PicPacColors.surface,
      surface: PicPacColors.surface,
      onSurface: PicPacColors.ink,
      outline: PicPacColors.border,
      outlineVariant: PicPacColors.borderStrong,
      surfaceContainerHighest: PicPacColors.backgroundAlt,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PicPacColors.background,
      fontFamily: 'FuturaPT',
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
      focusColor: PicPacColors.accent.withValues(alpha: 0.14),
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: PicPacColors.background,
        foregroundColor: PicPacColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: detailTitle,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: PicPacColors.ink,
          foregroundColor: PicPacColors.surface,
          disabledBackgroundColor: PicPacColors.fillGray,
          disabledForegroundColor: PicPacColors.muted,
          textStyle: const TextStyle(
            fontFamily: 'FuturaPT',
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          shape: const StadiumBorder(),
        ).copyWith(side: _focusSide(Colors.transparent)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: PicPacColors.ink,
          foregroundColor: PicPacColors.surface,
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: 'FuturaPT',
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          shape: const StadiumBorder(),
        ).copyWith(side: _focusSide(Colors.transparent)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: PicPacColors.ink,
              disabledForegroundColor: PicPacColors.muted,
              side: const BorderSide(color: PicPacColors.border),
              textStyle: const TextStyle(
                fontFamily: 'FuturaPT',
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              shape: const StadiumBorder(),
            ).copyWith(
              side: _focusSide(PicPacColors.border, restWidth: 1),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              minimumSize: const Size(48, kMinTouchTarget),
              foregroundColor: PicPacColors.ink,
              disabledForegroundColor: PicPacColors.muted,
              textStyle: const TextStyle(
                fontFamily: 'FuturaPT',
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return PicPacColors.ink.withValues(alpha: 0.10);
                }
                return null;
              }),
            ),
      ),
      cardTheme: CardThemeData(
        color: PicPacColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PicPacRadii.card),
          side: const BorderSide(color: PicPacColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PicPacColors.backgroundAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PicPacSpacing.mdPlus,
          vertical: PicPacSpacing.mdPlus,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'FuturaPT',
          fontSize: 14,
          color: PicPacColors.secondaryText,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'FuturaPT',
          fontSize: 16,
          color: PicPacColors.secondaryText,
        ),
        errorStyle: const TextStyle(
          fontFamily: 'FuturaPT',
          fontSize: 14,
          color: PicPacColors.accentText,
        ),
        border: _fieldBorder(PicPacColors.border),
        enabledBorder: _fieldBorder(PicPacColors.border),
        focusedBorder: _fieldBorder(PicPacColors.ink, width: 2),
        errorBorder: _fieldBorder(PicPacColors.accentText),
        focusedErrorBorder: _fieldBorder(PicPacColors.accentText),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: PicPacColors.surface,
        indicatorColor: PicPacColors.accentSoft,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'FuturaPT',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: selected ? PicPacColors.ink : PicPacColors.secondaryText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? PicPacColors.ink : PicPacColors.secondaryText,
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: PicPacColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PicPacRadii.card),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'FuturaPT',
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: PicPacColors.ink,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'FuturaPT',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: PicPacColors.ink,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PicPacColors.surface,
        modalBackgroundColor: PicPacColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PicPacRadii.card),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: PicPacColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PicPacColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: 'FuturaPT',
          fontSize: 16,
          color: PicPacColors.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PicPacRadii.field),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[PicPacTheme()],
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(PicPacRadii.field),
        borderSide: BorderSide(color: color, width: width),
      );

  static WidgetStateProperty<BorderSide?> _focusSide(
    Color rest, {
    double restWidth = 0,
    double focusedWidth = 2,
  }) => WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.focused)) {
      return BorderSide(color: PicPacColors.ink, width: focusedWidth);
    }
    return BorderSide(color: rest, width: restWidth);
  });

  static TextTheme _textTheme(TextTheme base) => base
      .copyWith(
        displayLarge: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w400,
        ),
        displayMedium: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w400,
        ),
        headlineLarge: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
        ),
        headlineMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
        ),
        headlineSmall: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w400,
        ),
        titleLarge: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
        titleMedium: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        titleSmall: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
        bodyMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        bodySmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        labelLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        labelMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        labelSmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      )
      .apply(
        bodyColor: PicPacColors.ink,
        displayColor: PicPacColors.ink,
        fontFamily: 'FuturaPT',
      );
}
