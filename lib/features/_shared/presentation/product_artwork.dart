import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';

class ProductArtwork extends StatelessWidget {
  const ProductArtwork({
    required this.seedId,
    required this.category,
    this.radius = PicPacRadii.photo,
    this.semanticLabel,
    this.iconSize = 48,
    super.key,
  });

  final String seedId;

  final String category;

  final double radius;

  final String? semanticLabel;

  final double iconSize;

  static const List<Color> _planes = <Color>[
    PicPacColors.fillBeige,
    PicPacColors.fillMint,
    PicPacColors.fillBlue,
    PicPacColors.fillLavender,
    PicPacColors.fillStone,
    PicPacColors.fillGray,
  ];

  static Color planeFor(String seedId) {
    var hash = 0;
    for (final unit in seedId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _planes[hash % _planes.length];
  }

  static IconData iconFor(String category) => switch (category) {
    'prints' => Icons.photo_outlined,
    'books' => Icons.menu_book_outlined,
    _ => Icons.local_mall_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final artwork = DecoratedBox(
      decoration: BoxDecoration(
        color: planeFor(seedId),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Icon(
          iconFor(category),
          size: iconSize,
          color: PicPacColors.ink.withValues(alpha: 0.45),
        ),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: artwork);
    return Semantics(image: true, label: semanticLabel, child: artwork);
  }
}
