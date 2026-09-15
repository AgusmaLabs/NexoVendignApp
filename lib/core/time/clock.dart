/// Injectable clock for deterministic session expiration tests.
abstract interface class Clock {
  DateTime now();
}

/// System wall clock (UTC).
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// Mutable clock for tests.
final class FakeClock implements Clock {
  FakeClock(DateTime initial) : _now = initial.toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  void set(DateTime value) {
    _now = value.toUtc();
  }
}
