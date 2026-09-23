import 'dart:convert';
import 'dart:math';

import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_operation_store.dart';

const _approvalLifetime = Duration(minutes: 5);
const _completedOperationLifetime = Duration(hours: 1);

final class McpOperationService implements IMcpOperationService {
  McpOperationService({
    required McpOperationStore store,
    required IMcpAccessService accessService,
    DateTime Function()? now,
    Random? random,
  })  : _store = store,
        _accessService = accessService,
        _now = now ?? DateTime.now,
        _random = random ?? Random.secure();

  final McpOperationStore _store;
  final IMcpAccessService _accessService;
  final DateTime Function() _now;
  final Random _random;
  Map<String, McpOperationExecutor> _executors = const {};

  @override
  Future<McpOperation> prepare({
    required String clientGrantId,
    required McpOperationType type,
    required Set<String> requiredScopes,
    required String requestHash,
    required String summary,
    required McpOperationExecutor execute,
  }) async {
    if (clientGrantId.isEmpty ||
        requiredScopes.isEmpty ||
        !McpScopes.all.containsAll(requiredScopes) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(requestHash) ||
        summary.trim().isEmpty ||
        summary.length > 500) {
      throw ArgumentError('Invalid MCP operation metadata');
    }
    final now = _now().toUtc();
    final operation = McpOperation(
      id: _newId(),
      type: type,
      status: McpOperationStatus.pendingApproval,
      clientGrantId: clientGrantId,
      requiredScopes: requiredScopes,
      requestHash: requestHash,
      summary: summary,
      createdAt: now,
      approvalExpiresAt: now.add(_approvalLifetime),
    );
    await _store.update<Object?>((current) async => (
          [..._expire(current), operation],
          null,
        ));
    _executors = Map.unmodifiable({..._executors, operation.id: execute});
    return operation;
  }

  @override
  Future<McpOperation?> getForClient({
    required String operationId,
    required String clientGrantId,
    required Set<String> currentScopes,
  }) =>
      _store.update((current) async {
        final updated = _expire(current);
        final operation = updated
            .where((item) =>
                item.id == operationId &&
                item.clientGrantId == clientGrantId &&
                currentScopes.containsAll(item.requiredScopes))
            .firstOrNull;
        return (updated, operation);
      });

  @override
  Future<List<McpOperation>> listPending() => _store.update((current) async {
        final updated = _expire(current);
        return (
          updated,
          List<McpOperation>.unmodifiable(updated.where(
              (item) => item.status == McpOperationStatus.pendingApproval)),
        );
      });

  @override
  Future<McpOperation> approve(String operationId) async {
    final running = await _store.update((current) async {
      final updated = _expire(current);
      final index = updated.indexWhere((item) => item.id == operationId);
      if (index < 0) throw StateError('Operation not found');
      final operation = updated[index];
      if (operation.status != McpOperationStatus.pendingApproval) {
        throw StateError('Operation is not pending approval');
      }
      final executor = _executors[operationId];
      if (executor == null) {
        final expired = _copy(operation, status: McpOperationStatus.expired);
        return (_replace(updated, index, expired), expired);
      }
      if (!await _isGrantStillAuthorized(operation)) {
        final cancelled = _copy(
          operation,
          status: McpOperationStatus.cancelled,
          failure: const McpOperationFailure(
            code: 'permission_denied',
            message: 'The connection no longer has the required permission.',
          ),
        );
        return (_replace(updated, index, cancelled), cancelled);
      }
      final next = _copy(operation, status: McpOperationStatus.running);
      return (_replace(updated, index, next), next);
    });
    if (running.status != McpOperationStatus.running) return running;

    final executor = _executors[operationId]!;
    McpOperation terminal;
    try {
      terminal = _copy(
        running,
        status: McpOperationStatus.succeeded,
        result: await executor(),
      );
    } catch (_) {
      terminal = _copy(
        running,
        status: McpOperationStatus.failed,
        failure: const McpOperationFailure(
          code: 'operation_failed',
          message: 'The approved operation failed.',
        ),
      );
    }
    _executors = Map.unmodifiable(Map.of(_executors)..remove(operationId));
    return _store.update((current) async {
      final index = current.indexWhere((item) => item.id == operationId);
      if (index < 0 || current[index].status != McpOperationStatus.running) {
        throw StateError('Operation state changed while running');
      }
      return (_replace(current, index, terminal), terminal);
    });
  }

  @override
  Future<McpOperation> reject(String operationId) =>
      _store.update((current) async {
        final updated = _expire(current);
        final index = updated.indexWhere((item) => item.id == operationId);
        if (index < 0) throw StateError('Operation not found');
        final operation = updated[index];
        if (operation.status != McpOperationStatus.pendingApproval) {
          throw StateError('Operation is not pending approval');
        }
        final rejected =
            _copy(operation, status: McpOperationStatus.rejected);
        _executors =
            Map.unmodifiable(Map.of(_executors)..remove(operationId));
        return (_replace(updated, index, rejected), rejected);
      });

  Future<bool> _isGrantStillAuthorized(McpOperation operation) async {
    final state = await _accessService.readState();
    return state.grants.any((grant) =>
        grant.id == operation.clientGrantId &&
        !grant.isRevoked &&
        grant.scopes.containsAll(operation.requiredScopes));
  }

  List<McpOperation> _expire(List<McpOperation> operations) {
    final now = _now().toUtc();
    final retained = operations.where((operation) =>
        operation.status == McpOperationStatus.pendingApproval ||
        operation.status == McpOperationStatus.running ||
        operation.approvalExpiresAt
            .add(_completedOperationLifetime)
            .isAfter(now));
    final expiredExecutorIds = <String>{};
    final updated = retained.map((operation) {
      if (operation.status == McpOperationStatus.pendingApproval &&
          (!operation.approvalExpiresAt.isAfter(now) ||
              !_executors.containsKey(operation.id))) {
        expiredExecutorIds.add(operation.id);
        return _copy(operation, status: McpOperationStatus.expired);
      }
      if (operation.status == McpOperationStatus.running &&
          !_executors.containsKey(operation.id)) {
        return _copy(
          operation,
          status: McpOperationStatus.failed,
          failure: const McpOperationFailure(
            code: 'operation_failed',
            message: 'The local operation was interrupted before completion.',
          ),
        );
      }
      return operation;
    }).toList(growable: false);
    if (expiredExecutorIds.isNotEmpty) {
      _executors = Map.unmodifiable({
        for (final entry in _executors.entries)
          if (!expiredExecutorIds.contains(entry.key)) entry.key: entry.value,
      });
    }
    return List.unmodifiable(updated);
  }

  List<McpOperation> _replace(
    List<McpOperation> operations,
    int index,
    McpOperation replacement,
  ) =>
      List.unmodifiable([
        ...operations.take(index),
        replacement,
        ...operations.skip(index + 1),
      ]);

  McpOperation _copy(
    McpOperation operation, {
    required McpOperationStatus status,
    McpOperationResult? result,
    McpOperationFailure? failure,
  }) =>
      McpOperation(
        id: operation.id,
        type: operation.type,
        status: status,
        clientGrantId: operation.clientGrantId,
        requiredScopes: operation.requiredScopes,
        requestHash: operation.requestHash,
        summary: operation.summary,
        createdAt: operation.createdAt,
        approvalExpiresAt: operation.approvalExpiresAt,
        result: result,
        failure: failure,
      );

  String _newId() => base64UrlEncode(
        List<int>.generate(24, (_) => _random.nextInt(256), growable: false),
      ).replaceAll('=', '');
}
