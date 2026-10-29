/// Most simultaneous connections the LAN server accepts.
const int lanMaxConcurrentConnections = 10;

/// Most simultaneous connections from one source address.
const int lanMaxConnectionsPerSource = 5;

/// Connection counts of the LAN server (D7 connection limits).
class LanConnectionLimits {
  final int maxTotal;
  final int maxPerSource;
  final Map<String, int> _perSource = {};
  int _total = 0;

  LanConnectionLimits({this.maxTotal = lanMaxConcurrentConnections, this.maxPerSource = lanMaxConnectionsPerSource});

  int get activeCount => _total;

  /// Reserves a slot for [source]; `false` when a limit is reached.
  bool tryAdmit(String source) {
    if (_total >= maxTotal || (_perSource[source] ?? 0) >= maxPerSource) return false;
    _total++;
    _perSource[source] = (_perSource[source] ?? 0) + 1;
    return true;
  }

  /// Frees the slot [tryAdmit] reserved for [source].
  void release(String source) {
    final count = _perSource[source] ?? 0;
    if (count == 0) return;
    _total--;
    if (count == 1) {
      _perSource.remove(source);
    } else {
      _perSource[source] = count - 1;
    }
  }
}
