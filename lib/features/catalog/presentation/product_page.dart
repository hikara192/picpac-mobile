import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../_shared/application/async_retry.dart';
import '../../../core/presentation/failure_text.dart';
import '../../../core/presentation/format.dart';
import '../../../core/presentation/text_tones.dart';
import '../../_shared/presentation/product_artwork.dart';
import '../../../core/presentation/state_views.dart';
import '../application/catalog_controllers.dart';

class ProductPage extends ConsumerStatefulWidget {
  const ProductPage({required this.productId, super.key});

  final String productId;

  @override
  ConsumerState<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends ConsumerState<ProductPage> {
  String? _selectedFormatId;
  Map<String, String> _options = const <String, String>{};
  bool _starting = false;
  Failure? _startFailure;

  Future<void> _start(ProductOfferView view, FormatOfferView offer) async {
    setState(() {
      _starting = true;
      _startFailure = null;
    });
    final result = await ref
        .read(draftStarterProvider)
        .start(
          product: view.product,
          format: offer.format,
          options: _optionsFor(offer.format),
        );
    if (!mounted) return;
    setState(() => _starting = false);
    switch (result) {
      case Ok<DesignDto>(:final value):
        context.push(AppRoutes.createFor(value.id));
      case Err<DesignDto>(:final error):
        setState(() => _startFailure = error);
    }
  }

  Map<String, String> _optionsFor(ProductFormat format) {
    final defaults = defaultOptionsOf(format);
    if (_options.isEmpty) return defaults;
    return <String, String>{
      for (final entry in defaults.entries)
        entry.key: _options[entry.key] ?? entry.value,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = productProvider(widget.productId);
    final product = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.catalogTitle)),
      body: switch (product) {
        AsyncData<ProductOfferView>(:final value) => _buildBody(value),
        AsyncError<ProductOfferView>(:final error) => FailureView(
          failure: failureOr(error),
          onRetry: () => ref.invalidate(provider),
          onLogin: () => context.push(AppRoutes.login),
        ),
        _ => const CardListSkeleton(items: 3),
      },
      bottomNavigationBar: switch (product) {
        AsyncData<ProductOfferView>(:final value) => _buildAction(value),
        _ => null,
      },
    );
  }

  FormatOfferView? _selectedOffer(ProductOfferView view) {
    final selectedId =
        _selectedFormatId ??
        (view.formats.isEmpty ? null : view.formats.first.format.id);
    if (selectedId == null) return null;
    return view.offerOf(selectedId);
  }

  Widget _buildBody(ProductOfferView view) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final selected = _selectedOffer(view);
    final minPrice = view.product.minPrice;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PicPacSpacing.lg,
        PicPacSpacing.md,
        PicPacSpacing.lg,
        PicPacSpacing.xxl,
      ),
      children: <Widget>[
        SizedBox(
          height: 220,
          child: ProductArtwork(
            seedId: view.product.id,
            category: view.product.category,
            iconSize: 72,
            semanticLabel: l10n.productHeroHint(view.product.title),
          ),
        ),
        const SizedBox(height: PicPacSpacing.lg),
        Text(view.product.title, style: theme.textTheme.headlineSmall),
        if (minPrice != null) ...<Widget>[
          const SizedBox(height: PicPacSpacing.xs),
          Text(
            l10n.priceFrom(fmt.money(minPrice)),
            style: theme.textTheme.titleMedium?.copyWith(
              color: PicPacColors.accent,
            ),
          ),
        ],
        const SizedBox(height: PicPacSpacing.xl),
        Text(l10n.productFormatsTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: PicPacSpacing.md),
        for (final offer in view.formats) ...<Widget>[
          _FormatTile(
            offer: offer,
            selected: offer.format.id == selected?.format.id,
            onTap: () => setState(() {
              _selectedFormatId = offer.format.id;
              _options = defaultOptionsOf(offer.format);
            }),
          ),
          const SizedBox(height: PicPacSpacing.sm),
        ],
        if (selected != null && selected.format.options.isNotEmpty) ...<Widget>[
          const SizedBox(height: PicPacSpacing.lg),
          _OptionsSection(
            productId: view.product.id,
            format: selected.format,
            selection: _optionsFor(selected.format),
            baseQuote: selected.quote,
            onChanged: (optionId, valueId) => setState(() {
              _options = <String, String>{
                ..._optionsFor(selected.format),
                optionId: valueId,
              };
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildAction(ProductOfferView view) {
    final l10n = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final selected = _selectedOffer(view);
    final failure = _startFailure;
    final options = selected == null
        ? const <String, String>{}
        : _optionsFor(selected.format);
    final quote = selected == null
        ? null
        : ref
              .watch(
                productQuoteProvider(
                  ProductQuoteKey(
                    productId: view.product.id,
                    formatId: selected.format.id,
                    spreadsCount: ProductController.previewUnits(
                      selected.format,
                    ),
                    options: options,
                  ),
                ),
              )
              .value;
    final effective = quote ?? selected?.quote;
    final label = selected == null
        ? l10n.productChooseFormat
        : _starting
        ? l10n.loading
        : effective == null
        ? l10n.actionBuild
        : '${l10n.actionBuild} · ${fmt.money(effective.total)}';
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        PicPacSpacing.lg,
        PicPacSpacing.sm,
        PicPacSpacing.lg,
        PicPacSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (failure != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(PicPacSpacing.md),
              decoration: BoxDecoration(
                color: PicPacColors.accentSoft,
                borderRadius: BorderRadius.circular(PicPacRadii.field),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.productBuildFailed,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: PicPacColors.ink),
                  ),
                  const SizedBox(height: PicPacSpacing.xxs),
                  Text(
                    failureText(l10n, failure),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: PicPacColors.ink),
                  ),
                  if (isAuthFailure(failure)) ...<Widget>[
                    const SizedBox(height: PicPacSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: () => context.push(AppRoutes.login),
                        child: Text(l10n.actionLogin),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: PicPacSpacing.sm),
          ],
          FilledButton(
            onPressed: selected == null || _starting
                ? null
                : () => _start(view, selected),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

class _OptionsSection extends ConsumerWidget {
  const _OptionsSection({
    required this.productId,
    required this.format,
    required this.selection,
    required this.baseQuote,
    required this.onChanged,
  });

  final String productId;
  final ProductFormat format;
  final Map<String, String> selection;
  final PriceQuote? baseQuote;
  final void Function(String optionId, String valueId) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final quote = ref
        .watch(
          productQuoteProvider(
            ProductQuoteKey(
              productId: productId,
              formatId: format.id,
              spreadsCount: ProductController.previewUnits(format),
              options: selection,
            ),
          ),
        )
        .value;
    final base = baseQuote;
    final delta = quote == null || base == null
        ? null
        : quote.total.amountMinor - base.total.amountMinor;
    return SectionCard(
      title: l10n.productOptionsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final option in format.options) ...<Widget>[
            Text(option.title, style: theme.textTheme.titleSmall),
            const SizedBox(height: PicPacSpacing.xs),
            Wrap(
              spacing: PicPacSpacing.sm,
              runSpacing: PicPacSpacing.sm,
              children: <Widget>[
                for (final value in _orderedValues(option))
                  ChoiceChip(
                    key: Key('product-option-${option.id}-${value.id}'),
                    label: Text(_chipLabel(l10n, fmt, option, value)),
                    selected: selection[option.id] == value.id,
                    onSelected: (_) => onChanged(option.id, value.id),
                  ),
              ],
            ),
            const SizedBox(height: PicPacSpacing.md),
          ],
          const Divider(height: PicPacSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.productOptionsTotal,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                quote == null ? '—' : fmt.money(quote.total),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: PicPacColors.accent,
                ),
              ),
            ],
          ),
          if (delta != null && delta != 0) ...<Widget>[
            const SizedBox(height: PicPacSpacing.xxs),
            Text(
              delta > 0
                  ? l10n.productOptionsMore(
                      fmt.money(
                        Money(
                          amountMinor: delta,
                          currency: quote!.total.currency,
                        ),
                      ),
                    )
                  : l10n.productOptionsLess(
                      fmt.money(
                        Money(
                          amountMinor: -delta,
                          currency: quote!.total.currency,
                        ),
                      ),
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: FunnelText.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<OptionValue> _orderedValues(ProductOption option) {
    final values = option.values;
    final baseIndex = values.indexWhere((value) => value.isDefault);
    if (baseIndex <= 0) return values;
    return <OptionValue>[
      values[baseIndex],
      for (var i = 0; i < values.length; i++)
        if (i != baseIndex) values[i],
    ];
  }

  String _chipLabel(
    AppLocalizations l10n,
    Fmt fmt,
    ProductOption option,
    OptionValue value,
  ) {
    final selectedId = selection[option.id];
    if (selectedId == value.id) return value.title;
    var selectedDelta = 0;
    for (final candidate in option.values) {
      if (candidate.id == selectedId) selectedDelta = candidate.priceDeltaMinor;
    }
    final delta = value.priceDeltaMinor - selectedDelta;
    if (delta == 0) return value.title;
    final amount = fmt.money(
      Money(amountMinor: delta.abs(), currency: value.currency ?? 'BYN'),
    );
    final modifier = delta < 0
        ? l10n.productOptionCheaper(amount)
        : l10n.productOptionDearer(amount);
    return '${value.title} · $modifier';
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  final FormatOfferView offer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final format = offer.format;
    final quote = offer.quote;
    final price = quote == null
        ? l10n.productPriceUnavailable
        : fmt.money(quote.total);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? PicPacColors.accentSoft : PicPacColors.surface,
        borderRadius: BorderRadius.circular(PicPacRadii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PicPacRadii.card),
          child: Ink(
            padding: const EdgeInsets.all(PicPacSpacing.mdPlus),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PicPacRadii.card),
              border: Border.all(
                color: selected ? PicPacColors.accent : PicPacColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(format.title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: PicPacSpacing.xxs),
                      Text(
                        l10n.productSize(
                          Fmt.millimetres(format.widthMm),
                          Fmt.millimetres(format.heightMm),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: FunnelText.secondary,
                        ),
                      ),
                      if (quote != null) ...<Widget>[
                        const SizedBox(height: PicPacSpacing.xxs),
                        Text(
                          l10n.productEta(quote.etaDays),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: FunnelText.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: PicPacSpacing.md),
                Text(
                  price,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: PicPacColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
