library;

abstract interface class Clock {
  DateTime now();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

final class FixedClock implements Clock {
  FixedClock([DateTime? start])
    : _now = (start ?? DateTime.utc(2026, 11, 11, 9)).toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);

  void set(DateTime instant) => _now = instant.toUtc();
}
