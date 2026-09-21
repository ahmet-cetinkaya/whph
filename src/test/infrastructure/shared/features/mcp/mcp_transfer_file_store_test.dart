import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_data_transfer_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_access_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_access_store.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_transfer_file_store.dart';

void main() {
  late Directory applicationDirectory;
  late Directory transferDirectory;
  late McpAccessService accessService;
  late McpIssuedGrant grant;

  setUp(() async {
    applicationDirectory =
        await Directory.systemTemp.createTemp('whph_mcp_transfer_');
    transferDirectory =
        Directory(p.join(applicationDirectory.path, 'transfers'));
    await transferDirectory.create();
    final directoryService =
        _TestApplicationDirectoryService(applicationDirectory);
    accessService = McpAccessService(
      store: McpAccessStore(applicationDirectoryService: directoryService),
    );
    await accessService.setPreferences(McpServerPreferences(
      isEnabled: true,
      port: 44041,
      transferDirectory: transferDirectory.path,
    ));
    grant = await accessService.createGrant(
      clientName: 'Transfer test client',
      scopes: const {McpScopes.dataExport, McpScopes.dataImport},
    );
  });

  tearDown(() async {
    await accessService.dispose();
    if (await applicationDirectory.exists()) {
      await applicationDirectory.delete(recursive: true);
    }
  });

  McpTransferFileStore createStore({
    DateTime Function()? now,
    Future<void> Function()? beforeSaveIndex,
  }) =>
      McpTransferFileStore(
        applicationDirectoryService:
            _TestApplicationDirectoryService(applicationDirectory),
        accessService: accessService,
        now: now,
        beforeSaveIndex: beforeSaveIndex,
      );

  test('serializes concurrent exports and preserves reloaded metadata',
      () async {
    final store = createStore();
    final artifacts = await Future.wait(List.generate(
      12,
      (index) => store.storeExport(
        clientGrantId: grant.grant.id,
        fileName: 'export-$index.json',
        fileExtension: 'json',
        content: 'content-$index',
      ),
    ));

    final restartedStore = createStore();
    for (final artifact in artifacts) {
      final chunk = await restartedStore.readArtifactChunk(
        clientGrantId: grant.grant.id,
        artifactId: artifact.id,
        offset: 0,
      );
      expect(chunk?.bytes, isNotNull);
    }
    final mcpDirectory = Directory(p.join(applicationDirectory.path, 'mcp'));
    expect(
      await mcpDirectory
          .list()
          .where((entity) =>
              p.basename(entity.path).startsWith('transfers.json.') &&
              p.basename(entity.path).endsWith('.tmp'))
          .isEmpty,
      isTrue,
    );
  });

  test('restores expired artifact when cleanup index save fails', () async {
    final createdAt = DateTime.utc(2026, 1, 1);
    final artifact = await createStore(now: () => createdAt).storeExport(
      clientGrantId: grant.grant.id,
      fileName: 'expired.json',
      fileExtension: 'json',
      content: 'preserved content',
    );

    await expectLater(
      createStore(
        now: () => createdAt.add(const Duration(hours: 2)),
        beforeSaveIndex: () =>
            Future<void>.error(const FileSystemException('index unavailable')),
      ).cleanupExpired(),
      throwsA(isA<FileSystemException>()),
    );

    final restartedStore = createStore(now: () => createdAt);
    final chunk = await restartedStore.readArtifactChunk(
      clientGrantId: grant.grant.id,
      artifactId: artifact.id,
      offset: 0,
    );
    expect(chunk?.bytes, utf8.encode('preserved content'));

    await createStore(now: () => createdAt.add(const Duration(hours: 2)))
        .cleanupExpired();
    expect(
      await createStore(now: () => createdAt).readArtifactChunk(
        clientGrantId: grant.grant.id,
        artifactId: artifact.id,
        offset: 0,
      ),
      isNull,
    );
  });

  test('rejects an oversized index before decoding', () async {
    final mcpDirectory = Directory(p.join(applicationDirectory.path, 'mcp'));
    await mcpDirectory.create();
    final index = File(p.join(mcpDirectory.path, 'transfers.json'));
    await index.writeAsString('x' * (mcpMaximumTransferMetadataBytes + 1));
    if (!Platform.isWindows) {
      await Process.run('chmod', ['700', mcpDirectory.path]);
      await Process.run('chmod', ['600', index.path]);
    }

    await expectLater(createStore().cleanupExpired(), throwsFormatException);
  });

  test('enforces metadata entry capacity without orphaning an export',
      () async {
    final store = createStore();
    McpTransferArtifact? lastArtifact;
    for (var index = 0;
        index < mcpMaximumRetainedTransferMetadataEntries;
        index++) {
      lastArtifact = await store.storeExport(
        clientGrantId: grant.grant.id,
        fileName: 'export-$index.json',
        fileExtension: 'json',
        content: 'content',
      );
    }
    final index =
        File(p.join(applicationDirectory.path, 'mcp', 'transfers.json'));
    final persistedIndex = await index.readAsBytes();

    await expectLater(
      store.storeExport(
        clientGrantId: grant.grant.id,
        fileName: 'rejected.json',
        fileExtension: 'json',
        content: 'content',
      ),
      throwsA(isA<FileSystemException>()),
    );

    final artifactDirectory =
        Directory(p.join(applicationDirectory.path, 'mcp', 'artifacts'));
    expect(await artifactDirectory.list().length,
        equals(mcpMaximumRetainedTransferMetadataEntries));
    expect(await index.readAsBytes(), equals(persistedIndex));

    final reloaded = createStore();
    expect(
      await reloaded.readArtifactChunk(
        clientGrantId: grant.grant.id,
        artifactId: lastArtifact!.id,
        offset: 0,
      ),
      isNotNull,
    );
  });

  test('serializes concurrent staging and enforces the per-grant cap',
      () async {
    for (var index = 0; index < 6; index++) {
      await File(p.join(transferDirectory.path, 'import-$index.whph'))
          .writeAsString('content-$index');
    }
    final store = createStore();
    final results = await Future.wait(List.generate(
      6,
      (index) async {
        try {
          return await store.stageImport(
            clientGrantId: grant.grant.id,
            sourceName: 'import-$index.whph',
          );
        } on FileSystemException {
          return null;
        }
      },
    ));

    final staged = results.whereType<McpStagedImport>().toList();
    expect(staged, hasLength(5));
    final restartedStore = createStore();
    for (final item in staged) {
      expect(await restartedStore.verifyStaged(item), isTrue);
    }
  });
}

final class _TestApplicationDirectoryService
    implements IApplicationDirectoryService {
  const _TestApplicationDirectoryService(this.directory);

  final Directory directory;

  @override
  Future<Directory> getApplicationDirectory() async => directory;
}
