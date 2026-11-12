import '../../../l10n/app_localizations.dart';

String ideaTitle(AppLocalizations l10n, String titleKey) => switch (titleKey) {
  'inspirationTemplateDuoSplit' => l10n.inspirationTemplateDuoSplit,
  'inspirationTemplateTrioHero' => l10n.inspirationTemplateTrioHero,
  'inspirationTemplateQuadGrid' => l10n.inspirationTemplateQuadGrid,
  'inspirationTemplatePolaroid' => l10n.inspirationTemplatePolaroid,
  'inspirationTemplatePanorama' => l10n.inspirationTemplatePanorama,
  'inspirationTemplateStrip3' => l10n.inspirationTemplateStrip3,
  'inspirationTemplatePolaroidLarge' => l10n.inspirationTemplatePolaroidLarge,
  'inspirationTemplatePanoramaWide' => l10n.inspirationTemplatePanoramaWide,
  'inspirationTemplateBookSingle' => l10n.inspirationTemplateBookSingle,
  'inspirationTemplateBookDuo' => l10n.inspirationTemplateBookDuo,
  'inspirationTemplateBookTrio' => l10n.inspirationTemplateBookTrio,
  'inspirationTemplateBookQuad' => l10n.inspirationTemplateBookQuad,
  'inspirationTemplateBookSix' => l10n.inspirationTemplateBookSix,
  'inspirationTemplateBookPanorama' => l10n.inspirationTemplateBookPanorama,
  _ => l10n.inspirationTemplateFallback,
};

String ideaTag(AppLocalizations l10n, String tag) => switch (tag) {
  'семья' => l10n.inspirationTagFamily,
  'свадьба' => l10n.inspirationTagWedding,
  'выпускной' => l10n.inspirationTagGraduation,
  'путешествие' => l10n.inspirationTagTravel,
  'минимализм' => l10n.inspirationTagMinimal,
  'детское' => l10n.inspirationTagKids,
  _ => tag,
};

String ideaCardLabel(AppLocalizations l10n, String title, int count) =>
    l10n.inspirationCardLabel(title, count);

String ideaPreviewLabel(AppLocalizations l10n, String title, int count) =>
    l10n.inspirationPreviewLabel(title, count);
