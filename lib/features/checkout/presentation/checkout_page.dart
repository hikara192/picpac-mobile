import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/orders/preflight_ack.dart';
import '../../../core/session/guest_work.dart';
import '../../../core/session/session_service.dart';
import '../../../core/validation/phone.dart';
import '../../../l10n/app_localizations.dart';
import '../../_shared/application/async_retry.dart';
import '../../../core/presentation/a11y.dart';
import '../../../core/presentation/failure_text.dart';
import '../../../core/presentation/format.dart';
import '../../_shared/presentation/preflight_messages.dart';
import '../../../core/presentation/text_tones.dart';
import '../../../core/presentation/state_views.dart';
import '../application/checkout_controller.dart';
import '../../../payments/presentation/payment_sheet.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _promo = TextEditingController();
  final FocusNode _addressFocus = FocusNode();

  DeliveryChoice? _choice;
  bool _submitting = false;

  bool _orderStarted = false;
  bool _promoBusy = false;
  Failure? _submitFailure;
  Failure? _promoFailure;

  @override
  void initState() {
    super.initState();
    _addressFocus.addListener(() {
      if (!_addressFocus.hasFocus) _syncAddress();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _promo.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  void _syncAddress() {
    final choice = _choice;
    if (choice == null || choice.kind == DeliveryKind.pickup) return;
    final next = choice.copyWith(address: _address.text);
    if (next != choice) setState(() => _choice = next);
  }

  Future<void> _loginFromCheckout() async {
    final l10n = AppLocalizations.of(context);
    final work = ref.read(guestWorkProvider);
    if (!work.hasDesign) {
      context.push(AppRoutes.loginFor(AppRoutes.checkout));
      return;
    }
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.checkoutGuestWorkTitle),
        content: Text(l10n.checkoutGuestWorkBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.checkoutGuestWorkConfirm),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    context.push(AppRoutes.loginFor(AppRoutes.checkout));
  }

  Future<void> _applyPromo(DeliveryChoice choice) async {
    setState(() {
      _promoBusy = true;
      _promoFailure = null;
    });
    final failure = await ref
        .read(checkoutProvider.notifier)
        .applyPromo(_promo.text.trim());
    if (!mounted) return;
    setState(() {
      _promoBusy = false;
      _promoFailure = failure;
    });
  }

  Future<void> _submit(DeliveryChoice choice) async {
    if (_submitting || _orderStarted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _submitFailure = null;
    });
    final notifier = ref.read(checkoutProvider.notifier);

    final verdict = await notifier.checkPreflight();
    if (!mounted) return;
    if (verdict.needsConfirmation) {
      final override = await _askPreflightOverride(verdict);
      if (!mounted) return;
      if (override != true) {
        setState(() => _submitting = false);
        return;
      }
      notifier.acknowledge(verdict);
    }

    final result = await notifier.submit(
      choice: choice.copyWith(address: _address.text),
      name: _name.text,
      phone: PhoneNumber.tryParse(_phone.text)?.e164 ?? _phone.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Ok<Order>(:final value):
        _orderStarted = true;
        context.go(AppRoutes.orderFor(value.id), extra: value);
        await showPaymentAfterCheckout(context, value);
      case Err<Order>(:final error):
        setState(() => _submitFailure = error);
        announceToScreenReader(
          context,
          '${AppLocalizations.of(context).checkoutFailed}: '
          '${failureText(AppLocalizations.of(context), error)}',
        );
    }
  }

  Future<bool?> _askPreflightOverride(CheckoutPreflightVerdict verdict) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.checkoutPreflightBlockedTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.checkoutPreflightBlockedBody),
              const SizedBox(height: PicPacSpacing.md),
              for (final finding in verdict.issues)
                Padding(
                  padding: const EdgeInsets.only(bottom: PicPacSpacing.xs),
                  child: Text('• ${preflightIssueText(l10n, finding.issue)}'),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.preflightFix),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.preflightOverride),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final checkout = ref.watch(checkoutProvider);
    final data = checkout.value;
    final choice = data == null ? null : (_choice ??= _initialChoice(data));
    final summary = choice == null
        ? null
        : ref.watch(checkoutSummaryProvider(choice));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkoutTitle)),
      body: switch (checkout) {
        AsyncData<CheckoutData>(:final value) =>
          value.isEmpty
              ? EmptyView(
                  title: l10n.cartEmptyTitle,
                  body: l10n.checkoutEmptyCart,
                  icon: Icons.shopping_bag_outlined,
                  action: FilledButton(
                    onPressed: () => context.go(AppRoutes.catalog),
                    child: Text(l10n.actionGoCatalog),
                  ),
                )
              : _buildForm(value, choice!),
        AsyncError<CheckoutData>(:final error) => FailureView(
          failure: failureOr(error),
          onRetry: () => ref.invalidate(checkoutProvider),
          onLogin: () => context.push(AppRoutes.login),
        ),
        _ => const CardListSkeleton(),
      },
      bottomNavigationBar: data == null || data.isEmpty || choice == null
          ? null
          : _buildAction(choice, summary),
    );
  }

  DeliveryChoice _initialChoice(CheckoutData data) {
    final base = data.defaultChoice;
    if (base.kind != DeliveryKind.pickup) return base;
    final point = data.pointById(base.pointId);
    return base.copyWith(slot: _firstAvailableSlot(point));
  }

  DateTime? _firstAvailableSlot(PickupPoint? point) {
    if (point == null) return null;
    for (final slot in point.slots) {
      if (slot.available) return slot.start;
    }
    return null;
  }

  Widget _buildForm(CheckoutData data, DeliveryChoice choice) {
    final l10n = AppLocalizations.of(context);
    final canPlaceOrders = ref.watch(sessionServiceProvider).canPlaceOrders;
    final guestWork = ref.watch(guestWorkProvider);
    final option = data.optionById(choice.optionId);
    final point = data.pointById(choice.pointId);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(PicPacSpacing.lg),
        children: <Widget>[
          if (!canPlaceOrders) ...<Widget>[
            _SignInBanner(guestWork: guestWork, onLogin: _loginFromCheckout),
            const SizedBox(height: PicPacSpacing.md),
          ],
          SectionCard(
            title: l10n.checkoutDelivery,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final item in data.options) ...<Widget>[
                  _DeliveryOptionTile(
                    option: item,
                    selected: item.id == choice.optionId,
                    onTap: () => setState(() {
                      _choice = DeliveryChoice(
                        optionId: item.id,
                        kind: item.kind,
                        pointId: item.requiresPoint && data.points.isNotEmpty
                            ? data.points.first.id
                            : null,
                        slot: item.requiresPoint
                            ? _firstAvailableSlot(
                                item.requiresPoint && data.points.isNotEmpty
                                    ? data.points.first
                                    : null,
                              )
                            : null,
                        address: _address.text,
                      );
                    }),
                  ),
                  const SizedBox(height: PicPacSpacing.sm),
                ],
                if (option != null && option.requiresPoint) ...<Widget>[
                  const SizedBox(height: PicPacSpacing.sm),
                  Text(
                    l10n.checkoutPickupPoint,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: PicPacSpacing.xs),
                  for (final candidate in data.points) ...<Widget>[
                    _PointTile(
                      point: candidate,
                      selected: candidate.id == choice.pointId,
                      onTap: () => setState(() {
                        _choice = choice.copyWith(
                          pointId: candidate.id,
                          slot: _firstAvailableSlot(candidate),
                        );
                      }),
                    ),
                    const SizedBox(height: PicPacSpacing.sm),
                  ],
                  const SizedBox(height: PicPacSpacing.sm),
                  Text(
                    l10n.checkoutPickupSlot,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: PicPacSpacing.sm),
                  _SlotGrid(
                    point: point,
                    selected: choice.slot,
                    onSelected: (slot) =>
                        setState(() => _choice = choice.copyWith(slot: slot)),
                  ),
                  if (choice.slot == null) ...<Widget>[
                    const SizedBox(height: PicPacSpacing.sm),
                    Text(
                      l10n.checkoutSlotRequired,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: PicPacColors.accentText),
                    ),
                  ],
                ],
                if (option != null && !option.requiresPoint) ...<Widget>[
                  const SizedBox(height: PicPacSpacing.sm),
                  TextFormField(
                    key: const Key('checkout-address'),
                    controller: _address,
                    focusNode: _addressFocus,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[
                      AutofillHints.fullStreetAddress,
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.checkoutAddress,
                      hintText: l10n.checkoutAddressHint,
                    ),
                    onFieldSubmitted: (value) {
                      _syncAddress();
                    },
                    validator: (value) => (value ?? '').trim().length >= 5
                        ? null
                        : l10n.checkoutAddressRequired,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: PicPacSpacing.md),
          SectionCard(
            title: l10n.checkoutPromo,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                () {
                  final field = TextField(
                    key: const Key('checkout-promo'),
                    controller: _promo,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: l10n.checkoutPromoHint,
                    ),
                    onSubmitted: (_) => _applyPromo(choice),
                  );
                  final button = MinTapTarget(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(112, kMinTouchTarget),
                        padding: const EdgeInsets.symmetric(
                          horizontal: PicPacSpacing.lg,
                        ),
                      ),
                      onPressed: _promoBusy ? null : () => _applyPromo(choice),
                      child: Text(_promoBusy ? l10n.loading : l10n.actionApply),
                    ),
                  );
                  if (MediaQuery.textScalerOf(context).scale(14) > 20) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        field,
                        const SizedBox(height: PicPacSpacing.sm),
                        button,
                      ],
                    );
                  }
                  return Row(
                    children: <Widget>[
                      Expanded(child: field),
                      const SizedBox(width: PicPacSpacing.sm),
                      button,
                    ],
                  );
                }(),
                if (data.cart.cart.promoCode != null) ...<Widget>[
                  const SizedBox(height: PicPacSpacing.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          l10n.checkoutPromoApplied(data.cart.cart.promoCode!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: _promoBusy
                            ? null
                            : () async {
                                _promo.clear();
                                await _applyPromo(choice);
                              },
                        child: Text(l10n.checkoutPromoClear),
                      ),
                    ],
                  ),
                ],
                if (_promoFailure != null) ...<Widget>[
                  const SizedBox(height: PicPacSpacing.sm),
                  Text(
                    _promoDescription(_promoFailure!),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: PicPacColors.accentText),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: PicPacSpacing.md),
          SectionCard(
            title: l10n.checkoutContacts,
            child: Column(
              children: <Widget>[
                TextFormField(
                  key: const Key('checkout-name'),
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const <String>[AutofillHints.name],
                  decoration: InputDecoration(labelText: l10n.checkoutName),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? l10n.checkoutNameRequired
                      : null,
                ),
                const SizedBox(height: PicPacSpacing.md),
                TextFormField(
                  key: const Key('checkout-phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.telephoneNumber],
                  inputFormatters: <TextInputFormatter>[
                    const PhoneInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.checkoutPhone,
                    hintText: l10n.checkoutPhoneHint,
                  ),
                  validator: (value) {
                    final raw = value ?? '';
                    if (raw.replaceAll(RegExp(r'[^0-9]'), '').isEmpty) {
                      return l10n.checkoutPhoneRequired;
                    }
                    if (PhoneNumber.tryParse(raw) == null) {
                      return l10n.checkoutPhoneInvalid;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: PicPacSpacing.md),
          _SummaryCard(
            choice: choice,
            summary: ref.watch(checkoutSummaryProvider(choice)),
          ),
          const SizedBox(height: PicPacSpacing.lg),
        ],
      ),
    );
  }

  String _promoDescription(Failure failure) {
    final l10n = AppLocalizations.of(context);
    if (failure.code == 'promo_unknown') return l10n.checkoutPromoUnknown;
    return failureText(l10n, failure);
  }

  Widget _buildAction(
    DeliveryChoice choice,
    AsyncValue<CheckoutSummary>? summary,
  ) {
    final l10n = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final canPlaceOrders = ref.watch(sessionServiceProvider).canPlaceOrders;
    final value = summary?.value;
    final failure = summary?.error;
    final ready =
        canPlaceOrders &&
        !_submitting &&
        choice.isComplete &&
        (value?.canOrder ?? false);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PicPacColors.background,
        border: Border(top: BorderSide(color: PicPacColors.border)),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          PicPacSpacing.lg,
          PicPacSpacing.md,
          PicPacSpacing.lg,
          PicPacSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_submitFailure != null) ...<Widget>[
              if (isPreflightBlocked(_submitFailure!)) ...<Widget>[
                Text(
                  l10n.checkoutPreflightBlocked,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: PicPacColors.accentText),
                ),
                const SizedBox(height: PicPacSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('checkout-fix-preflight'),
                    onPressed: () {
                      final designId = preflightBlockedDesignId(
                        _submitFailure!,
                      );
                      if (designId == null) return;
                      context.push(AppRoutes.preflightFor(designId));
                    },
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: Text(l10n.preflightFix),
                  ),
                ),
              ] else
                Text(
                  '${l10n.checkoutFailed}: '
                  '${failureText(l10n, _submitFailure!)}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: PicPacColors.accentText),
                ),
              const SizedBox(height: PicPacSpacing.sm),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.checkoutSummary,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: PicPacSpacing.sm),
                Flexible(
                  child: Text(
                    value == null ? '—' : fmt.money(value.total),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: PicPacColors.accentText),
                  ),
                ),
              ],
            ),
            if (failure != null) ...<Widget>[
              const SizedBox(height: PicPacSpacing.xxs),
              Text(
                failureText(l10n, failureOr(failure)),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: PicPacColors.accentText),
              ),
            ],
            if (!choice.isComplete) ...<Widget>[
              const SizedBox(height: PicPacSpacing.xxs),
              Text(
                choice.kind == DeliveryKind.pickup
                    ? l10n.checkoutSlotRequired
                    : l10n.checkoutDeliveryRequired,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: PicPacColors.accentText),
              ),
            ],
            const SizedBox(height: PicPacSpacing.md),
            if (!canPlaceOrders)
              FilledButton(
                onPressed: _loginFromCheckout,
                child: Text(l10n.checkoutLoginRequired),
              )
            else
              FilledButton(
                onPressed: ready ? () => _submit(choice) : null,
                child: Text(
                  _submitting ? l10n.checkoutSubmitting : l10n.checkoutSubmit,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SignInBanner extends StatelessWidget {
  const _SignInBanner({required this.guestWork, required this.onLogin});

  final GuestWorkState guestWork;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasGuestProject = guestWork.hasDesign;
    return Container(
      padding: const EdgeInsets.all(PicPacSpacing.md),
      decoration: BoxDecoration(
        color: PicPacColors.fillBeige,
        borderRadius: BorderRadius.circular(PicPacRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.checkoutLoginRequired,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (hasGuestProject) ...<Widget>[
            const SizedBox(height: PicPacSpacing.xs),
            Text(
              l10n.checkoutGuestWorkBody,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: FunnelText.secondary),
            ),
          ],
          const SizedBox(height: PicPacSpacing.sm),
          OutlinedButton(onPressed: onLogin, child: Text(l10n.actionLogin)),
        ],
      ),
    );
  }
}

class _DeliveryOptionTile extends StatelessWidget {
  const _DeliveryOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final DeliveryOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final freeFrom = option.freeFrom;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? PicPacColors.accentSoft : PicPacColors.surfaceMuted,
        borderRadius: BorderRadius.circular(PicPacRadii.field),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PicPacRadii.field),
          child: Ink(
            padding: const EdgeInsets.all(PicPacSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PicPacRadii.field),
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
                      Text(
                        deliveryOptionLabel(l10n, option.titleKey),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: PicPacSpacing.xxs),
                      Text(
                        <String>[
                          if (option.etaDays > 0)
                            l10n.deliveryDays(option.etaDays),
                          if (freeFrom != null)
                            l10n.deliveryFreeFrom(fmt.money(freeFrom)),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: FunnelText.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: PicPacSpacing.md),
                Flexible(
                  child: Text(
                    fmt.money(option.price),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: PicPacColors.accentText,
                    ),
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

class _PointTile extends StatelessWidget {
  const _PointTile({
    required this.point,
    required this.selected,
    required this.onTap,
  });

  final PickupPoint point;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? PicPacColors.accentSoft : PicPacColors.surfaceMuted,
        borderRadius: BorderRadius.circular(PicPacRadii.field),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PicPacRadii.field),
          child: Ink(
            padding: const EdgeInsets.all(PicPacSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PicPacRadii.field),
              border: Border.all(
                color: selected ? PicPacColors.accent : PicPacColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(point.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: PicPacSpacing.xxs),
                Text(
                  '${point.city}, ${point.address}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: FunnelText.secondary,
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

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.point,
    required this.selected,
    required this.onSelected,
  });

  final PickupPoint? point;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final slots = point?.slots ?? const <PickupSlot>[];
    if (slots.isEmpty) {
      return Text(
        l10n.checkoutNoSlots,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: FunnelText.secondary),
      );
    }
    return Wrap(
      spacing: PicPacSpacing.sm,
      runSpacing: PicPacSpacing.sm,
      children: <Widget>[
        for (final slot in slots)
          ChoiceChip(
            label: Text(fmt.slot(slot.start, slot.end)),
            selected:
                selected != null && selected!.isAtSameMomentAs(slot.start),
            onSelected: slot.available ? (_) => onSelected(slot.start) : null,
          ),
      ],
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.choice, required this.summary});

  final DeliveryChoice choice;
  final AsyncValue<CheckoutSummary> summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    return SectionCard(
      title: l10n.checkoutSummary,
      child: switch (summary) {
        AsyncData<CheckoutSummary>(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final line in value.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: PicPacSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        priceLineLabel(l10n, line.labelKey),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: PicPacSpacing.sm),
                    Flexible(
                      child: Text(
                        fmt.money(line.amount),
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: PicPacSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.orderTotal,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: PicPacSpacing.sm),
                Flexible(
                  child: Text(
                    fmt.money(value.total),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: PicPacColors.accentText,
                    ),
                  ),
                ),
              ],
            ),
            if (value.etaDays > 0) ...<Widget>[
              const SizedBox(height: PicPacSpacing.xxs),
              Text(
                l10n.cartEta(value.etaDays),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: FunnelText.secondary,
                ),
              ),
            ],
            if (!value.exact) ...<Widget>[
              const SizedBox(height: PicPacSpacing.sm),
              Text(
                l10n.checkoutPreliminary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: FunnelText.secondary,
                ),
              ),
            ],
          ],
        ),
        AsyncError<CheckoutSummary>(:final error) => FailureView(
          failure: failureOr(error),
          onRetry: () => ref.invalidate(checkoutSummaryProvider(choice)),
        ),
        _ => const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SkeletonBox(height: 16),
            SizedBox(height: PicPacSpacing.sm),
            SkeletonBox(height: 16, width: 120),
          ],
        ),
      },
    );
  }
}
