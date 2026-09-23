import 'dart:async';

import 'package:whph/core/application/shared/services/abstraction/i_restore_barrier.dart';

class McpRestoreBarrier implements IRestoreBarrier {
  final Object _zoneKey = Object();
  var _activeSharedOperations = 0;
  var _isExclusiveRequested = false;
  Completer<void>? _drained;

  @override
  bool get isRestoreActive => _isExclusiveRequested;

  @override
  bool get isRestoreOwner {
    final token = Zone.current[_zoneKey];
    return token is _OwnerToken && token.isValid;
  }

  @override
  RestoreBarrierLease acquireShared() {
    final inheritedToken = Zone.current[_zoneKey];
    if (inheritedToken is _BarrierToken && inheritedToken.isValid) {
      return _InheritedRestoreBarrierLease(_zoneKey, inheritedToken);
    }
    if (_isExclusiveRequested) throw const RestoreBusyException();

    _activeSharedOperations++;
    final lease = _CountingRestoreBarrierLease(_zoneKey, _releaseShared);
    return lease;
  }

  @override
  Future<T> runShared<T>(Future<T> Function() operation) {
    final inheritedToken = Zone.current[_zoneKey];
    if (inheritedToken is _BarrierToken && inheritedToken.isValid) {
      return operation();
    }
    final lease = acquireShared();
    return lease.run(
      () async {
        try {
          return await operation();
        } finally {
          lease.release();
        }
      },
    );
  }

  @override
  Future<T> runExclusive<T>(
    Future<T> Function() operation, {
    Duration ownerLifetime = const Duration(minutes: 5),
  }) {
    if (ownerLifetime <= Duration.zero) {
      return Future.error(ArgumentError.value(
        ownerLifetime,
        'ownerLifetime',
        'Must be positive',
      ));
    }
    if (_isExclusiveRequested) {
      return Future.error(const RestoreBusyException(
        'Another restore operation is already active',
      ));
    }
    final inheritedToken = Zone.current[_zoneKey];
    if (inheritedToken is _SharedToken && inheritedToken.isValid) {
      return Future.error(const RestoreBusyException(
        'Restore cannot begin from an admitted database operation',
      ));
    }
    _isExclusiveRequested = true;
    return _completeExclusive(operation, ownerLifetime);
  }

  Future<T> _completeExclusive<T>(
    Future<T> Function() operation,
    Duration ownerLifetime,
  ) async {
    if (_activeSharedOperations > 0) {
      _drained ??= Completer<void>();
      await _drained!.future;
    }
    final token = _OwnerToken(ownerLifetime);
    try {
      return await runZoned(
        operation,
        zoneValues: {_zoneKey: token},
      );
    } finally {
      token.invalidate();
      _isExclusiveRequested = false;
      _drained = null;
    }
  }

  void _releaseShared() {
    if (_activeSharedOperations <= 0) {
      throw StateError('Restore barrier lease released more than once');
    }
    _activeSharedOperations--;
    if (_activeSharedOperations == 0) {
      final drained = _drained;
      if (drained != null && !drained.isCompleted) drained.complete();
    }
  }
}

abstract class _BarrierToken {
  bool get isValid;
}

class _SharedToken implements _BarrierToken {
  final RestoreBarrierLease _lease;
  var _isActive = true;

  _SharedToken(this._lease);

  @override
  bool get isValid => _isActive && _lease.isActive;

  void invalidate() => _isActive = false;
}

class _OwnerToken implements _BarrierToken {
  final Duration _lifetime;
  final Stopwatch _elapsed = Stopwatch()..start();
  var _isActive = true;

  _OwnerToken(this._lifetime);

  @override
  bool get isValid => _isActive && _elapsed.elapsed < _lifetime;

  void invalidate() => _isActive = false;
}

class _CountingRestoreBarrierLease implements RestoreBarrierLease {
  final Object _zoneKey;
  final void Function() _onRelease;
  var _isActive = true;

  _CountingRestoreBarrierLease(this._zoneKey, this._onRelease);

  @override
  bool get isActive => _isActive;

  @override
  Future<T> run<T>(Future<T> Function() operation) {
    if (!_isActive) {
      return Future.error(StateError('Restore barrier lease is no longer active'));
    }
    final token = _SharedToken(this);
    return runZoned(
      () async {
        try {
          return await operation();
        } finally {
          token.invalidate();
        }
      },
      zoneValues: {_zoneKey: token},
    );
  }

  @override
  void release() {
    if (!_isActive) throw StateError('Restore barrier lease released more than once');
    _isActive = false;
    _onRelease();
  }
}

class _InheritedRestoreBarrierLease implements RestoreBarrierLease {
  const _InheritedRestoreBarrierLease(this._zoneKey, this._token);

  final Object _zoneKey;
  final _BarrierToken _token;

  @override
  bool get isActive => _token.isValid;

  @override
  Future<T> run<T>(Future<T> Function() operation) {
    if (!isActive) {
      return Future.error(StateError('Restore barrier lease is no longer active'));
    }
    return runZoned(operation, zoneValues: {_zoneKey: _token});
  }

  @override
  void release() {}
}
