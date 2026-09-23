import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_operation_store.dart';

void main() {
  late Directory applicationDirectory;
  late McpOperationStore store;

  setUp(() async {
    applicationDirectory =
        await Directory.systemTemp.createTemp('whph_mcp_operation_');
    store = McpOperationStore(
      applicationDirectoryService:
          _TestApplicationDirectoryService(applicationDirectory),
    );
  });

  tearDown(() async {
    if (await applicationDirectory.exists()) {
      await applicationDirectory.delete(recursive: true);
    }
  });

  test(
      'rejects oversized saves without replacing the persisted operation state',
      () async {
    final operation = _operation();
    await store.update((_) async => ([operation], null));
    final operationsFile =
        File(p.join(applicationDirectory.path, 'mcp', 'operations.json'));
    final originalBytes = await operationsFile.readAsBytes();

    final oversized = _operation(
      result: McpOperationResult({'payload': 'x' * (1024 * 1024)}),
    );
    await expectLater(
      store.update((_) async => ([oversized], null)),
      throwsA(isA<FormatException>()),
    );

    final restarted = McpOperationStore(
      applicationDirectoryService:
          _TestApplicationDirectoryService(applicationDirectory),
    );
    final persisted = await restarted.load();

    expect(persisted, hasLength(1));
    expect(persisted.single.id, operation.id);
    expect(persisted.single.result, isNull);
    expect(await operationsFile.readAsBytes(), originalBytes);
    expect(await operationsFile.length(), lessThanOrEqualTo(1024 * 1024));
  });
}

McpOperation _operation({McpOperationResult? result}) => McpOperation(
      id: 'operation-id',
      type: McpOperationType.dataImport,
      status: McpOperationStatus.succeeded,
      clientGrantId: 'grant-id',
      requiredScopes: const {'tasks:read'},
      requestHash: 'request-hash',
      summary: 'Import data',
      createdAt: DateTime.utc(2026),
      approvalExpiresAt: DateTime.utc(2026, 1, 2),
      result: result,
    );

class _TestApplicationDirectoryService implements IApplicationDirectoryService {
  const _TestApplicationDirectoryService(this.directory);

  final Directory directory;

  @override
  Future<Directory> getApplicationDirectory() async => directory;
}
