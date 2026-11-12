import 'package:api_contract/api_contract.dart';

enum PaymentPhase {
  idle,

  preparing,

  awaitingUser,

  polling,

  onDelivery,

  succeeded,

  failed,

  expired,

  canceled;

  bool get isTerminal =>
      this == PaymentPhase.succeeded ||
      this == PaymentPhase.failed ||
      this == PaymentPhase.expired ||
      this == PaymentPhase.canceled;

  bool get isWaiting =>
      this == PaymentPhase.awaitingUser || this == PaymentPhase.polling;
}

const Map<PaymentPhase, Set<PaymentPhase>> paymentPhaseTransitions =
    <PaymentPhase, Set<PaymentPhase>>{
      PaymentPhase.idle: <PaymentPhase>{
        PaymentPhase.preparing,
        PaymentPhase.awaitingUser,
        PaymentPhase.onDelivery,
        PaymentPhase.succeeded,
      },
      PaymentPhase.preparing: <PaymentPhase>{
        PaymentPhase.awaitingUser,
        PaymentPhase.polling,
        PaymentPhase.onDelivery,
        PaymentPhase.succeeded,
        PaymentPhase.failed,
        PaymentPhase.expired,
        PaymentPhase.canceled,
      },
      PaymentPhase.awaitingUser: <PaymentPhase>{
        PaymentPhase.polling,
        PaymentPhase.onDelivery,
        PaymentPhase.succeeded,
        PaymentPhase.failed,
        PaymentPhase.expired,
        PaymentPhase.canceled,
      },
      PaymentPhase.polling: <PaymentPhase>{
        PaymentPhase.onDelivery,
        PaymentPhase.succeeded,
        PaymentPhase.failed,
        PaymentPhase.expired,
        PaymentPhase.canceled,
      },
      PaymentPhase.onDelivery: <PaymentPhase>{
        PaymentPhase.succeeded,
        PaymentPhase.failed,
        PaymentPhase.canceled,
      },
      PaymentPhase.succeeded: <PaymentPhase>{},
      PaymentPhase.failed: <PaymentPhase>{},
      PaymentPhase.expired: <PaymentPhase>{},
      PaymentPhase.canceled: <PaymentPhase>{},
    };

final class PaymentFlow {
  const PaymentFlow({
    this.phase = PaymentPhase.idle,
    this.intent,
    this.failure,
    this.uncertain = false,
    this.attempt = 0,
  });

  const PaymentFlow.initial() : this();

  final PaymentPhase phase;

  final PaymentIntent? intent;

  final Failure? failure;

  final bool uncertain;

  final int attempt;

  bool get isTerminal => phase.isTerminal;

  bool get canCreateIntent => !isTerminal && intent == null;

  PaymentFlow? moveTo(
    PaymentPhase next, {
    PaymentIntent? intent,
    Failure? failure,
    bool? uncertain,
    int? attempt,
  }) {
    if (next == phase) {
      return copyWith(intent: intent, failure: failure, uncertain: uncertain);
    }
    final allowed = paymentPhaseTransitions[phase] ?? const <PaymentPhase>{};
    if (!allowed.contains(next)) return null;
    return PaymentFlow(
      phase: next,
      intent: intent ?? this.intent,
      failure: failure,
      uncertain: uncertain ?? this.uncertain,
      attempt: attempt ?? this.attempt,
    );
  }

  PaymentFlow applyStatus(PaymentStatus status, {PaymentIntent? intent}) {
    switch (status) {
      case PaymentStatus.succeeded:
      case PaymentStatus.refunded:
      case PaymentStatus.partiallyRefunded:
        return _to(PaymentPhase.succeeded, intent, uncertain: false);
      case PaymentStatus.failed:
        return _to(PaymentPhase.failed, intent, uncertain: false);
      case PaymentStatus.expired:
        return _to(PaymentPhase.expired, intent, uncertain: false);
      case PaymentStatus.canceled:
        return _to(PaymentPhase.canceled, intent, uncertain: false);
      case PaymentStatus.pendingOnDelivery:
        return _to(PaymentPhase.onDelivery, intent, uncertain: false);
      case PaymentStatus.processing:
        return _to(PaymentPhase.polling, intent, uncertain: false);
      case PaymentStatus.created:
      case PaymentStatus.requiresAction:
      case PaymentStatus.pendingUser:
        return _to(
          PaymentPhase.awaitingUser,
          intent,
          uncertain: false,
          keepLater: true,
        );
      case PaymentStatus.unknown:
        return _to(
          PaymentPhase.polling,
          intent,
          uncertain: true,
          keepLater: true,
        );
    }
  }

  PaymentFlow _to(
    PaymentPhase target,
    PaymentIntent? intent, {
    required bool uncertain,
    bool keepLater = false,
  }) {
    if (target == phase) {
      return copyWith(intent: intent, failure: null, uncertain: uncertain);
    }
    final moved = moveTo(
      target,
      intent: intent,
      failure: null,
      uncertain: uncertain,
    );
    if (moved != null) return moved;
    if (!keepLater) {
      return copyWith(intent: intent);
    }
    return copyWith(intent: intent, uncertain: uncertain);
  }

  PaymentFlow copyWith({
    PaymentIntent? intent,
    Failure? failure,
    bool? uncertain,
    int? attempt,
  }) => PaymentFlow(
    phase: phase,
    intent: intent ?? this.intent,
    failure: failure,
    uncertain: uncertain ?? this.uncertain,
    attempt: attempt ?? this.attempt,
  );

  @override
  String toString() =>
      'PaymentFlow(${phase.name}${uncertain ? ', uncertain' : ''}'
      '${intent == null ? '' : ', intent=${intent!.id}'})';
}

enum PaymentCallToAction {
  none,

  pay,

  paid,

  receipt,
}

PaymentCallToAction paymentCallToAction(Order order) {
  final status = order.paymentStatus;
  if (status.isPaid) return PaymentCallToAction.receipt;
  if (order.totals.total.isZero) return PaymentCallToAction.none;
  if (status == PaymentStatus.pendingOnDelivery) {
    return PaymentCallToAction.none;
  }
  if (order.fulfillmentStatus == OrderStatus.canceled ||
      order.fulfillmentStatus == OrderStatus.returned) {
    return PaymentCallToAction.none;
  }
  return PaymentCallToAction.pay;
}
