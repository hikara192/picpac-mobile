import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../app/di.dart';
import 'hosted_page_launcher.dart';
import 'payment_analytics.dart';
import 'payment_flow.dart';
import 'payment_method.dart';
import 'payment_poller.dart';
import 'payment_port.dart';

abstract final class PaymentErrorCode {
  static const String hostedPageFailed = 'payment_hosted_page_failed';

  static const String methodUnavailable = 'payment_method_unavailable';

  static const String intentMissing = 'payment_intent_missing';

  static const String checkFailed = 'payment_check_failed';

  static const String notPayable = 'payment_not_payable';

  static const String receiptUnavailable = 'payment_receipt_unavailable';
}

final class PaymentFailure implements Failure {
  const PaymentFailure(
    this.code,
    this.message, [
    this.args = const <String, Object?>{},
  ]);

  factory PaymentFailure.hostedPageFailed() => const PaymentFailure(
    PaymentErrorCode.hostedPageFailed,
    'the hosted payment page could not be opened',
  );

  factory PaymentFailure.methodUnavailable([String? region]) => PaymentFailure(
    PaymentErrorCode.methodUnavailable,
    'no enabled payment method for the region',
    <String, Object?>{'region': ?region},
  );

  factory PaymentFailure.checkFailed({Failure? cause}) => PaymentFailure(
    PaymentErrorCode.checkFailed,
    'the payment status could not be confirmed',
    <String, Object?>{'cause': ?cause?.code},
  );

  factory PaymentFailure.intentMissing() => const PaymentFailure(
    PaymentErrorCode.intentMissing,
    'the attempt has no payment intent',
  );

  factory PaymentFailure.notPayable([String? reason]) => PaymentFailure(
    PaymentErrorCode.notPayable,
    'the order cannot be paid',
    <String, Object?>{'reason': ?reason},
  );

  factory PaymentFailure.receiptUnavailable() => const PaymentFailure(
    PaymentErrorCode.receiptUnavailable,
    'the order has no receipt yet',
  );

  @override
  final String code;

  @override
  final String message;

  @override
  final Map<String, Object?> args;

  @override
  String toString() => 'PaymentFailure($code): $message';
}

final class PaymentOrderRef {
  const PaymentOrderRef({required this.orderId, required this.currency});

  final String orderId;

  final String currency;

  String get defaultRegion => switch (currency.toUpperCase()) {
    'RUB' => 'RU',
    _ => 'BY',
  };

  @override
  bool operator ==(Object other) =>
      other is PaymentOrderRef &&
      other.orderId == orderId &&
      other.currency == currency.toUpperCase();

  @override
  int get hashCode => Object.hash(orderId, currency.toUpperCase());
}

final class PaymentState {
  const PaymentState({
    this.flow = const PaymentFlow(),
    this.region = 'BY',
    this.methods = const <PaymentMethod>[],
    this.selected,
    this.creating = false,
    this.loadingMethods = false,
    this.methodsFailure,
    this.pollTimedOut = false,
    this.receipt,
    this.receiptFailure,
    this.loadingReceipt = false,
  });

  final PaymentFlow flow;

  final String region;

  final List<PaymentMethod> methods;

  final PaymentMethod? selected;

  final bool creating;

  final bool loadingMethods;

  final Failure? methodsFailure;

  final bool pollTimedOut;

  final Receipt? receipt;

  final Failure? receiptFailure;

  final bool loadingReceipt;

  bool get preparing => creating;

  bool get canPay =>
      !creating &&
      !flow.isTerminal &&
      flow.intent == null &&
      selected != null &&
      !loadingMethods;

  PaymentState copyWith({
    PaymentFlow? flow,
    String? region,
    List<PaymentMethod>? methods,
    PaymentMethod? selected,
    bool clearSelected = false,
    bool? creating,
    bool? loadingMethods,
    Failure? methodsFailure,
    bool clearMethodsFailure = false,
    bool? pollTimedOut,
    Receipt? receipt,
    Failure? receiptFailure,
    bool? loadingReceipt,
  }) => PaymentState(
    flow: flow ?? this.flow,
    region: region ?? this.region,
    methods: methods ?? this.methods,
    selected: clearSelected ? null : (selected ?? this.selected),
    creating: creating ?? this.creating,
    loadingMethods: loadingMethods ?? this.loadingMethods,
    methodsFailure: clearMethodsFailure
        ? null
        : (methodsFailure ?? this.methodsFailure),
    pollTimedOut: pollTimedOut ?? this.pollTimedOut,
    receipt: receipt ?? this.receipt,
    receiptFailure: receiptFailure ?? this.receiptFailure,
    loadingReceipt: loadingReceipt ?? this.loadingReceipt,
  );
}

final class PaymentController extends Notifier<PaymentState> {
  PaymentController(this.target);

  final PaymentOrderRef target;

  static const List<String> regions = <String>['BY', 'RU'];

  PaymentPoller? _poller;

  String? _loadedRegion;

  String get orderId => target.orderId;

  @override
  PaymentState build() {
    ref.onDispose(_stopPolling);
    final region = target.defaultRegion;
    _loadedRegion = null;
    return PaymentState(region: region);
  }

  Future<void> loadMethods({bool force = false}) async {
    if (!force && _loadedRegion == state.region) return;
    final region = state.region;
    _loadedRegion = region;
    state = state.copyWith(
      loadingMethods: true,
      clearMethodsFailure: true,
      methods: const <PaymentMethod>[],
      clearSelected: true,
    );
    final result = await ref.read(paymentPortProvider).methods(region);
    if (!ref.mounted) return;
    switch (result) {
      case Ok<List<PaymentMethodInfo>>(:final value):
        final methods = <PaymentMethod>[
          for (final info in value)
            if (info.enabled)
              PaymentMethod.fromDto(info, region: region),
        ];
        state = state.copyWith(
          loadingMethods: false,
          methods: methods,
          selected: _defaultSelection(methods),
          methodsFailure: null,
        );
        ref
            .read(paymentAnalyticsProvider)
            .methodsLoaded(region: region, count: methods.length);
      case Err<List<PaymentMethodInfo>>(:final error):
        _loadedRegion = null; // a retry must reach the server again
        state = state.copyWith(loadingMethods: false, methodsFailure: error);
    }
  }

  Future<void> selectRegion(String region) async {
    if (region == state.region && _loadedRegion == region) return;
    state = state.copyWith(
      region: region,
      methods: const <PaymentMethod>[],
      clearSelected: true,
      clearMethodsFailure: true,
    );
    await loadMethods(force: true);
  }

  void select(PaymentMethod method) {
    if (preparingOrWaiting) return;
    state = state.copyWith(selected: method);
  }

  bool get preparingOrWaiting => state.creating || state.flow.intent != null;

  Future<void> pay() async {
    final method = state.selected;
    if (method == null) {
      _fail(PaymentFailure.methodUnavailable(state.region));
      return;
    }
    if (state.flow.isTerminal || preparingOrWaiting) return;

    final preparing = state.flow.moveTo(PaymentPhase.preparing) ?? state.flow;
    state = state.copyWith(
      flow: preparing,
      creating: true,
      pollTimedOut: false,
    );

    final key = ref.read(paymentAttemptKeysProvider.notifier).keyFor(orderId);
    final result = await ref
        .read(paymentPortProvider)
        .createIntent(
          orderId: orderId,
          methodId: method.id,
          region: state.region,
          idempotencyKey: key,
        );
    if (!ref.mounted) return;
    state = state.copyWith(creating: false);

    switch (result) {
      case Ok<PaymentIntent>(:final value):
        ref
            .read(paymentAnalyticsProvider)
            .attemptCreated(
              provider: value.provider,
              methodKind: method.kind,
              status: value.status,
              amount: value.amount,
            );
        await _begin(value, method);
      case Err<PaymentIntent>(:final error):
        final ended = _terminalKey(error);
        final flow = ended == null
            ? state.flow.moveTo(
                PaymentPhase.awaitingUser,
                failure: error,
                uncertain: false,
              )
            : state.flow.applyStatus(ended).copyWith(failure: error);
        state = state.copyWith(
          flow: flow ?? state.flow.copyWith(failure: error),
        );
        ref.read(paymentAnalyticsProvider).attemptFailed(error);
    }
  }

  Future<void> retry() async {
    ref.read(paymentAttemptKeysProvider.notifier).renew(orderId);
    _stopPolling();
    if (!ref.mounted) return;
    state = state.copyWith(
      flow: const PaymentFlow.initial(),
      creating: false,
      pollTimedOut: false,
    );
    await pay();
  }

  Future<void> pollNow() async {
    final intent = state.flow.intent;
    if (intent == null || state.flow.isTerminal) return;
    if (state.flow.phase == PaymentPhase.onDelivery) return;
    final result = await ref.read(paymentPortProvider).status(intent.id);
    if (!ref.mounted) return;
    switch (result) {
      case Ok<PaymentIntent>(:final value):
        state = state.copyWith(
          flow: state.flow.applyStatus(value.status, intent: value),
          pollTimedOut: false,
        );
        if (value.status.isTerminal) _stopPolling();
      case Err<PaymentIntent>(:final error):
        state = state.copyWith(flow: state.flow.copyWith(failure: error));
    }
  }

  Future<bool> openHostedPage() async {
    final intent = state.flow.intent;
    final url = intent?.hostedPageUrl;
    if (intent == null || url == null) {
      _fail(PaymentFailure.intentMissing());
      return false;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _fail(PaymentFailure.hostedPageFailed());
      return false;
    }
    final outcome = await ref.read(hostedPageLauncherProvider).open(uri);
    if (!ref.mounted) return outcome == HostedPageLaunch.launched;
    if (outcome == HostedPageLaunch.failed) {
      _fail(PaymentFailure.hostedPageFailed());
      return false;
    }
    ref
        .read(paymentAnalyticsProvider)
        .hostedPageOpened(provider: intent.provider);
    state = state.copyWith(
      flow:
          state.flow.moveTo(PaymentPhase.awaitingUser, failure: null) ??
          state.flow.copyWith(failure: null),
    );
    return true;
  }

  Future<void> startPolling() async {
    final intent = state.flow.intent;
    if (intent == null || state.flow.isTerminal) return;
    final polling = state.flow.moveTo(PaymentPhase.polling) ?? state.flow;
    state = state.copyWith(flow: polling, pollTimedOut: false);

    final poller = _poller ??= PaymentPoller(
      fetch: (intentId) => ref.read(paymentPortProvider).status(intentId),
      delay: ref.read(paymentDelayProvider),
      clock: ref.read(clockProvider),
    );
    final outcome = await poller.start(
      intent.id,
      onUpdate: (value) {
        if (!ref.mounted) return;
        state = state.copyWith(
          flow: state.flow.applyStatus(value.status, intent: value),
        );
      },
    );
    if (!ref.mounted) return;
    switch (outcome.stop) {
      case PaymentPollStop.timeout:
        state = state.copyWith(
          pollTimedOut: true,
          flow: state.flow.copyWith(
            failure: PaymentFailure.checkFailed(cause: outcome.lastFailure),
          ),
        );
      case PaymentPollStop.canceled:
      case PaymentPollStop.duplicate:
      case PaymentPollStop.status:
        break;
    }
  }

  Future<void> loadReceipt() async {
    if (state.loadingReceipt || state.receipt != null) return;
    state = state.copyWith(loadingReceipt: true, receiptFailure: null);
    final result = await ref.read(paymentPortProvider).receipt(orderId);
    if (!ref.mounted) return;
    switch (result) {
      case Ok<Receipt>(:final value):
        state = state.copyWith(loadingReceipt: false, receipt: value);
      case Err<Receipt>(:final error):
        state = state.copyWith(loadingReceipt: false, receiptFailure: error);
    }
  }

  void _stopPolling() {
    _poller?.cancel();
    _poller = null;
  }

  Future<void> _begin(PaymentIntent intent, PaymentMethod method) async {
    var flow = state.flow.moveTo(
      PaymentPhase.awaitingUser,
      intent: intent,
      attempt: state.flow.attempt + 1,
    );
    flow ??= state.flow.copyWith(
      intent: intent,
      attempt: state.flow.attempt + 1,
    );
    flow = flow.applyStatus(intent.status, intent: intent);
    state = state.copyWith(flow: flow, pollTimedOut: false);

    if (state.flow.phase == PaymentPhase.onDelivery ||
        state.flow.phase == PaymentPhase.succeeded) {
      return; // nothing to open, nothing to poll
    }
    if (method.requiresHostedPage) {
      final opened = await openHostedPage();
      if (!opened) return; // the failure is already on the state
    }
    await startPolling();
  }

  PaymentStatus? _terminalKey(Failure failure) => switch (failure.code) {
    'payment_already_paid' => PaymentStatus.succeeded,
    'payment_not_required' => PaymentStatus.succeeded,
    _ => null,
  };

  void _fail(Failure failure) {
    if (!ref.mounted) return;
    state = state.copyWith(flow: state.flow.copyWith(failure: failure));
  }

  PaymentMethod? _defaultSelection(List<PaymentMethod> methods) {
    for (final method in methods) {
      if (method.kind == PaymentMethodKind.card) return method;
    }
    return methods.isEmpty ? null : methods.first;
  }
}

final paymentControllerProvider =
    NotifierProvider.family<PaymentController, PaymentState, PaymentOrderRef>(
      PaymentController.new,
      isAutoDispose: true,
    );

final class PaymentAttemptKeys extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const <String, String>{};

  String keyFor(String orderId) {
    final existing = state[orderId];
    if (existing != null) return existing;
    final minted = const Uuid().v4();
    state = <String, String>{...state, orderId: minted};
    return minted;
  }

  void renew(String orderId) {
    if (!state.containsKey(orderId)) return;
    final next = <String, String>{...state}..remove(orderId);
    state = next;
  }
}

final paymentAttemptKeysProvider =
    NotifierProvider<PaymentAttemptKeys, Map<String, String>>(
      PaymentAttemptKeys.new,
    );

final Provider<PaymentDelay> paymentDelayProvider = Provider<PaymentDelay>(
  (ref) => defaultPaymentDelay,
);
