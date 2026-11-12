import 'package:api_contract/api_contract.dart';

import '../core/clock.dart';

typedef PaymentDelay = Future<void> Function(Duration duration);

enum PaymentPollStop {
  status,

  timeout,

  canceled,

  duplicate,
}

final class PaymentPollOutcome {
  const PaymentPollOutcome({
    required this.stop,
    this.intent,
    this.attempts = 0,
    this.lastFailure,
  });

  final PaymentPollStop stop;

  final PaymentIntent? intent;

  final int attempts;

  final Failure? lastFailure;

  bool get isTerminalStatus => stop == PaymentPollStop.status;
}

final class PaymentPoller {
  PaymentPoller({
    required this.fetch,
    this.delay = defaultPaymentDelay,
    this.clock = const SystemClock(),
    this.initialInterval = const Duration(milliseconds: 500),
    this.maxInterval = const Duration(seconds: 30),
    this.timeout = const Duration(minutes: 5),
  });

  final Future<Result<PaymentIntent>> Function(String intentId) fetch;

  final PaymentDelay delay;

  final Clock clock;

  final Duration initialInterval;

  final Duration maxInterval;

  final Duration timeout;

  String? _intentId;
  bool _active = false;

  int _generation = 0;

  bool get isActive => _active;

  String? get intentId => _intentId;

  bool isPolling(String intentId) => _active && _intentId == intentId;

  void cancel() {
    _generation++;
    _active = false;
    _intentId = null;
  }

  Future<PaymentPollOutcome> start(
    String intentId, {
    void Function(PaymentIntent intent)? onUpdate,
  }) async {
    if (isPolling(intentId)) {
      return const PaymentPollOutcome(stop: PaymentPollStop.duplicate);
    }
    final generation = ++_generation; // invalidates a loop of another intent
    _active = true;
    _intentId = intentId;

    final startedAt = clock.now();
    var interval = initialInterval;
    var attempts = 0;
    Failure? lastFailure;
    PaymentIntent? latest;

    try {
      while (_generation == generation) {
        await delay(interval);
        if (_generation != generation) break;
        if (clock.now().difference(startedAt) >= timeout) {
          return PaymentPollOutcome(
            stop: PaymentPollStop.timeout,
            intent: latest,
            attempts: attempts,
            lastFailure: lastFailure,
          );
        }
        attempts++;
        final result = await fetch(intentId);
        if (_generation != generation) break;
        switch (result) {
          case Ok<PaymentIntent>(:final value):
            latest = value;
            lastFailure = null;
            onUpdate?.call(value);
            if (value.status.isTerminal) {
              return PaymentPollOutcome(
                stop: PaymentPollStop.status,
                intent: value,
                attempts: attempts,
              );
            }
          case Err<PaymentIntent>(:final error):
            lastFailure = error;
        }
        interval = _nextInterval(interval);
      }
      return PaymentPollOutcome(
        stop: PaymentPollStop.canceled,
        intent: latest,
        attempts: attempts,
        lastFailure: lastFailure,
      );
    } finally {
      if (_generation == generation) {
        _active = false;
        _intentId = null;
      }
    }
  }

  Duration _nextInterval(Duration current) {
    final doubled = current * 2;
    return doubled > maxInterval ? maxInterval : doubled;
  }
}

Future<void> defaultPaymentDelay(Duration duration) =>
    Future<void>.delayed(duration);
