/// How long to wait before restarting Hermes after a crash (WBS 4.4): 2 s, 4 s,
/// 8 s, 16 s, 32 s (capped at one minute), then give up and say so.
class RestartBackoff {
  RestartBackoff({
    this.base = const Duration(seconds: 2),
    this.maxAttempts = 5,
    this.cap = const Duration(minutes: 1),
  });

  final Duration base;
  final int maxAttempts;
  final Duration cap;
  int _attempts = 0;

  /// How many restarts have been tried since the last [reset].
  int get attempts => _attempts;

  /// True once the restarts have been used up; the app should stop and tell the owner.
  bool get giveUp => _attempts >= maxAttempts;

  /// The wait before the next restart. Throws if [giveUp] is true.
  Duration next() {
    if (giveUp) throw StateError('No more restarts: $maxAttempts tried.');
    final wait = base * (1 << _attempts);
    _attempts++;
    return wait > cap ? cap : wait;
  }

  /// Call when Hermes has been running for a while: the count starts again.
  void reset() => _attempts = 0;
}
