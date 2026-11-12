import 'package:flutter/material.dart';

abstract final class PicPacColors {
  static const Color background = Color(0xFFFAF5ED);
  static const Color backgroundAlt = Color(0xFFF6EFE6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFFAF7F7);
  static const Color ink = Color(0xFF364C49);
  static const Color inkStrong = Color(0xFF38524F);
  static const Color muted = Color(0xFF7C807F);
  static const Color mutedLight = Color(0xFFAEB4B3);

  static const Color secondaryText = Color(0xFF536562);
  static const Color accent = Color(0xFFDD5757);
  static const Color accentHover = Color(0xFFEC1923);
  static const Color accentText = Color(0xFFB93B3B);
  static const Color accentSoft = Color(0xFFEDD5D5);
  static const Color border = Color(0xFFCCC7BF);
  static const Color borderStrong = Color(0xFFBCBFB7);
  static const Color fillBeige = Color(0xFFEDE1D5);
  static const Color fillMint = Color(0xFFC4DAD6);
  static const Color fillBlue = Color(0xFFCFDDE7);
  static const Color fillLavender = Color(0xFFE0DCE8);
  static const Color fillGray = Color(0xFFDEDBDC);
  static const Color fillStone = Color(0xFFDEDFDC);
  static const Color accentOrange = Color(0xFFE8996C);
  static const Color accentBlue = Color(0xFF568CDE);
  static const Color accentPurple = Color(0xFF8C71D8);
}

abstract final class PicPacSpacing {
  static const double xxs = 4;
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double mdPlus = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 36;
  static const double huge = 40;
}

abstract final class PicPacRadii {
  static const double xs = 4;
  static const double sm = 6;
  static const double field = 10;
  static const double photo = 16;
  static const double card = 20;
  static const double pill = 100;
}

const double kMinTouchTarget = 48;

abstract final class PicPacShadows {
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x80BCBFB7), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> hover = <BoxShadow>[
    BoxShadow(color: Color(0x26000000), blurRadius: 15, offset: Offset(0, 5)),
  ];

  static const List<BoxShadow> focus = <BoxShadow>[
    BoxShadow(color: Color(0x59DD5757), blurRadius: 5),
  ];
}
