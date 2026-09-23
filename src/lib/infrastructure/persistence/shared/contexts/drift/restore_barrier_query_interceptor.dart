import 'package:drift/drift.dart';
import 'package:whph/core/application/shared/services/abstraction/i_restore_barrier.dart';

class RestoreBarrierQueryInterceptor extends QueryInterceptor {
  final IRestoreBarrier _barrier;
  final Set<QueryExecutor> _lifetimeExecutors = Set.identity();
  final Map<QueryExecutor, RestoreBarrierLease> _rootLeases = Map.identity();

  RestoreBarrierQueryInterceptor(this._barrier);

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    final parentIsAdmitted = _lifetimeExecutors.contains(parent);
    final lease = parentIsAdmitted ? null : _barrier.acquireShared();
    try {
      final child = parent.beginTransaction();
      _lifetimeExecutors.add(child);
      if (lease != null) _rootLeases[child] = lease;
      return child;
    } catch (_) {
      lease?.release();
      rethrow;
    }
  }

  @override
  QueryExecutor beginExclusive(QueryExecutor parent) {
    final parentIsAdmitted = _lifetimeExecutors.contains(parent);
    final lease = parentIsAdmitted ? null : _barrier.acquireShared();
    try {
      final child = parent.beginExclusive();
      _lifetimeExecutors.add(child);
      if (lease != null) _rootLeases[child] = lease;
      return child;
    } catch (_) {
      lease?.release();
      rethrow;
    }
  }

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) {
    if (!_lifetimeExecutors.contains(executor)) {
      return _barrier.runShared(() => executor.ensureOpen(user));
    }
    return _ensureLifetimeOpen(executor, user);
  }

  Future<bool> _ensureLifetimeOpen(
    QueryExecutor executor,
    QueryExecutorUser user,
  ) async {
    try {
      return await executor.ensureOpen(user);
    } catch (_) {
      _releaseLifetime(executor);
      rethrow;
    }
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    try {
      await inner.send();
    } finally {
      _releaseLifetime(inner);
    }
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    try {
      await inner.rollback();
    } finally {
      _releaseLifetime(inner);
    }
  }

  @override
  Future<void> close(QueryExecutor inner) async {
    if (_lifetimeExecutors.contains(inner)) {
      try {
        await inner.close();
      } finally {
        _releaseLifetime(inner);
      }
      return;
    }
    await _barrier.runShared(inner.close);
  }

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) =>
      _run(executor, () => executor.runBatched(statements));

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) =>
      _run(executor, () => executor.runCustom(statement, args));

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) =>
      _run(executor, () => executor.runInsert(statement, args));

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) =>
      _run(executor, () => executor.runDelete(statement, args));

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) =>
      _run(executor, () => executor.runUpdate(statement, args));

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) =>
      _run(executor, () => executor.runSelect(statement, args));

  Future<T> _run<T>(QueryExecutor executor, Future<T> Function() operation) {
    if (_lifetimeExecutors.contains(executor)) return operation();
    return _barrier.runShared(operation);
  }

  void _releaseLifetime(QueryExecutor executor) {
    _lifetimeExecutors.remove(executor);
    _rootLeases.remove(executor)?.release();
  }
}
