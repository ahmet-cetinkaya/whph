/// Shortest time between two `XXpsk3` pairing handshakes from one source
/// address (D7).
const Duration pairingMinInterval = Duration(seconds: 1);

/// Most source addresses the limiter remembers; the oldest are forgotten
/// first, so a flood from many addresses cannot grow memory.
const int pairingLimiterMaxSources = 1024;

/// Per-source rate limit for `XXpsk3` pairing handshakes (D7).
///
/// There is deliberately no global limit: a global cap would let one LAN host
/// deny pairing to everyone. Only the source address is limited.
class PairingRateLimiter {
  final DateTime Function() _now;
  final Duration _minInterval;
  final Map<String, DateTime> _lastAttempt = {};

  PairingRateLimiter({DateTime Function()? now, Duration minInterval = pairingMinInterval})
      : _now = now ?? DateTime.now,
        _minInterval = minInterval;

  /// Records an attempt from [source] and returns whether it may proceed.
  /// A refused attempt does not extend the wait of the source.
  bool tryAcquire(String source) {
    final now = _now();
    final last = _lastAttempt[source];
    if (last != null && now.difference(last) < _minInterval) return false;
    _lastAttempt.remove(source);
    _lastAttempt[source] = now;
    if (_lastAttempt.length > pairingLimiterMaxSources) _lastAttempt.remove(_lastAttempt.keys.first);
    return true;
  }
}
