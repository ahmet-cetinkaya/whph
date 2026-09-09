abstract class RestoreBarrierLease {
  bool get isActive;

  Future<T> run<T>(Future<T> Function() operation);

  void release();
}

abstract class IRestoreBarrier {
  bool get isRestoreActive;

  bool get isRestoreOwner;

  RestoreBarrierLease acquireShared();

  Future<T> runShared<T>(Future<T> Function() operation);

  Future<T> runExclusive<T>(
    Future<T> Function() operation, {
    Duration ownerLifetime = const Duration(minutes: 5),
  });
}

class RestoreBusyException implements Exception {
  final String message;

  const RestoreBusyException([
    this.message = 'Database access is unavailable during restore',
  ]);

  @override
  String toString() => 'RestoreBusyException: $message';
}
