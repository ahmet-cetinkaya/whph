import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_access_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_access_store.dart';

void main() {
  late Directory applicationDirectory;
  late McpAccessStore store;
  late McpAccessService service;

  setUp(() async {
    applicationDirectory = await _createApplicationDirectory('whph_mcp_access_');
    store = McpAccessStore(
      applicationDirectoryService: _TestApplicationDirectoryService(applicationDirectory),
    );
    service = McpAccessService(store: store);
  });

  tearDown(() async {
    await service.dispose();
    if (await applicationDirectory.exists()) {
      await applicationDirectory.delete(recursive: true);
    }
  });

  test('defaults to disabled loopback configuration outside the database', () async {
    final state = await service.readState();

    expect(state.preferences.isEnabled, isFalse);
    expect(state.preferences.port, 44041);
    expect(
      state.preferences.transferDirectory,
      p.join(applicationDirectory.path, 'mcp', 'transfers'),
    );
    expect(await File(p.join(applicationDirectory.path, 'mcp', 'access.json')).exists(), isFalse);
  });

  test('creates, authenticates after restart, and persists no raw token', () async {
    final issued = await service.createGrant(
      clientName: 'Local assistant',
      scopes: const {McpScopes.tasksRead, McpScopes.tasksWrite},
    );

    final accessFile = File(p.join(applicationDirectory.path, 'mcp', 'access.json'));
    final serialized = await accessFile.readAsString();
    expect(serialized, isNot(contains(issued.token)));
    expect(serialized, contains('tokenDigest'));

    final restarted = McpAccessService(store: store);
    addTearDown(restarted.dispose);
    final authenticated = await restarted.authenticate(
      issued.token,
      requiredScopes: const {McpScopes.tasksWrite},
    );

    expect(authenticated?.id, issued.grant.id);
    expect(authenticated?.clientName, 'Local assistant');
    expect(await restarted.authenticate('incorrect-token'), isNull);
    expect(
      await restarted.authenticate(
        issued.token,
        requiredScopes: const {McpScopes.tasksDelete},
      ),
      isNull,
    );
  });

  test('persists explicit local server preferences after restart', () async {
    final preferences = McpServerPreferences(
      isEnabled: true,
      port: 45000,
      transferDirectory: p.join(applicationDirectory.path, 'agent-transfers'),
    );

    await service.setPreferences(preferences);
    final restarted = McpAccessService(store: store);
    addTearDown(restarted.dispose);
    final persisted = await restarted.readState();

    expect(persisted.preferences.isEnabled, isTrue);
    expect(persisted.preferences.port, 45000);
    expect(persisted.preferences.transferDirectory, preferences.transferDirectory);
  });

  test('revocation is immediately observed by authentication and signal', () async {
    final issued = await service.createGrant(
      clientName: 'Revoked assistant',
      scopes: const {McpScopes.notesRead},
    );
    final revocation = expectLater(
      service.revocations,
      emits(predicate<McpAccessRevocation>((event) => event.grantId == issued.grant.id)),
    );

    await service.revokeGrant(issued.grant.id);

    expect(await service.authenticate(issued.token), isNull);
    await revocation;
  });

  test('rotation invalidates old token and survives concurrent grant writes', () async {
    final issued = await service.createGrant(
      clientName: 'Rotating assistant',
      scopes: const {McpScopes.habitsRead},
    );
    final created = await Future.wait(
      List.generate(
        8,
        (index) => service.createGrant(
          clientName: 'Concurrent assistant $index',
          scopes: const {McpScopes.appRead},
        ),
      ),
    );

    final rotationSignal = expectLater(
      service.revocations,
      emits(predicate<McpAccessRevocation>((event) => event.grantId == issued.grant.id)),
    );
    final rotated = await service.rotateGrant(issued.grant.id);
    expect(await service.authenticate(issued.token), isNull);
    expect(await service.authenticate(rotated.token), isNotNull);
    await rotationSignal;

    final restarted = McpAccessService(store: store);
    addTearDown(restarted.dispose);
    final persisted = await restarted.readState();
    expect(persisted.grants.where((grant) => !grant.isRevoked), hasLength(created.length + 1));
    for (final grant in created) {
      expect(await restarted.authenticate(grant.token), isNotNull);
    }
  });

  test('two services sharing one store do not lose concurrent grants', () async {
    final secondService = McpAccessService(store: store);
    addTearDown(secondService.dispose);

    final issued = await Future.wait([
      service.createGrant(
        clientName: 'First service',
        scopes: const {McpScopes.tasksRead},
      ),
      secondService.createGrant(
        clientName: 'Second service',
        scopes: const {McpScopes.notesRead},
      ),
    ]);

    final persisted = await service.readState();
    expect(persisted.grants, hasLength(2));
    for (final grant in issued) {
      expect(await service.authenticate(grant.token), isNotNull);
    }
  });

  test('cross-service revoke create and preferences updates are all retained', () async {
    final issued = await service.createGrant(
      clientName: 'Must remain revoked',
      scopes: const {McpScopes.tasksRead},
    );
    final secondService = McpAccessService(store: store);
    addTearDown(secondService.dispose);
    final transferDirectory = p.join(applicationDirectory.path, 'transfers-2');

    await Future.wait([
      service.revokeGrant(issued.grant.id),
      secondService.createGrant(
        clientName: 'Created during revoke',
        scopes: const {McpScopes.notesRead},
      ),
      secondService.setPreferences(McpServerPreferences(
        isEnabled: true,
        port: 45001,
        transferDirectory: transferDirectory,
      )),
    ]);

    final persisted = await service.readState();
    expect(persisted.grants, hasLength(2));
    expect(persisted.grants.singleWhere((grant) => grant.id == issued.grant.id).isRevoked, isTrue);
    expect(persisted.preferences.isEnabled, isTrue);
    expect(persisted.preferences.port, 45001);
    expect(persisted.preferences.transferDirectory, transferDirectory);
    expect(await service.authenticate(issued.token), isNull);
  });

  test('unrelated cross-service write followed by revoke cannot restore token', () async {
    final issued = await service.createGrant(
      clientName: 'Reverse-order revoke',
      scopes: const {McpScopes.tasksRead},
    );
    final secondService = McpAccessService(store: store);
    addTearDown(secondService.dispose);

    await Future.wait([
      secondService.createGrant(
        clientName: 'Queued before revoke',
        scopes: const {McpScopes.notesRead},
      ),
      service.revokeGrant(issued.grant.id),
    ]);

    final persisted = await service.readState();
    expect(persisted.grants, hasLength(2));
    expect(persisted.grants.singleWhere((grant) => grant.id == issued.grant.id).isRevoked, isTrue);
    expect(await service.authenticate(issued.token), isNull);
  });

  test('rotation remains authoritative around unrelated writes in both orders', () async {
    final secondService = McpAccessService(store: store);
    addTearDown(secondService.dispose);

    for (final rotationFirst in [true, false]) {
      final issued = await service.createGrant(
        clientName: 'Rotation order $rotationFirst',
        scopes: const {McpScopes.habitsRead},
      );
      late final McpIssuedGrant rotated;
      if (rotationFirst) {
        final results = await Future.wait<Object>([
          service.rotateGrant(issued.grant.id),
          secondService.createGrant(
            clientName: 'Write after rotation',
            scopes: const {McpScopes.appRead},
          ),
        ]);
        rotated = results.first as McpIssuedGrant;
      } else {
        final results = await Future.wait<Object>([
          secondService.createGrant(
            clientName: 'Write before rotation',
            scopes: const {McpScopes.appRead},
          ),
          service.rotateGrant(issued.grant.id),
        ]);
        rotated = results.last as McpIssuedGrant;
      }

      expect(await service.authenticate(issued.token), isNull);
      expect(await service.authenticate(rotated.token), isNotNull);
    }
  });

  test('rejects unknown scopes and invalid preference boundaries without writing', () async {
    await expectLater(
      () => service.createGrant(clientName: 'Bad scope', scopes: const {'tasks:admin'}),
      throwsArgumentError,
    );
    await expectLater(
      () => service.setPreferences(
        McpServerPreferences(
          isEnabled: true,
          port: 0,
          transferDirectory: applicationDirectory.path,
        ),
      ),
      throwsArgumentError,
    );

    expect(await File(p.join(applicationDirectory.path, 'mcp', 'access.json')).exists(), isFalse);
  });

  test('malformed documents and malformed persisted scopes fail closed', () async {
    final accessFile = await _createAccessFile(applicationDirectory);
    await accessFile.writeAsString('{not-json');

    await expectLater(service.readState, throwsA(isA<McpAccessStorageException>()));
    expect(await service.authenticate('guessed-token'), isNull);

    await accessFile.writeAsString(jsonEncode({
      'version': 1,
      'preferences': {
        'isEnabled': false,
        'port': 44041,
        'transferDirectory': p.join(applicationDirectory.path, 'mcp', 'transfers'),
      },
      'grants': [
        {
          'id': 'grant-id',
          'clientName': 'Injected grant',
          'tokenDigest': base64UrlEncode(List<int>.filled(32, 0)),
          'scopes': ['tasks:admin'],
          'createdAt': '2026-09-08T00:00:00.000Z',
          'rotatedAt': null,
          'revokedAt': null,
        },
      ],
    }));

    await expectLater(service.readState, throwsA(isA<McpAccessStorageException>()));
    expect(await service.authenticate('guessed-token'), isNull);
  });

  test('failed durable save does not publish or retain a new grant', () async {
    final first = await service.createGrant(
      clientName: 'Persisted assistant',
      scopes: const {McpScopes.tagsRead},
    );
    final accessFile = File(p.join(applicationDirectory.path, 'mcp', 'access.json'));
    final backupFile = await accessFile.rename('${accessFile.path}.test-backup');
    final blockingDirectory = await Directory(accessFile.path).create();

    await expectLater(
      () => service.createGrant(
        clientName: 'Must not persist',
        scopes: const {McpScopes.tagsWrite},
      ),
      throwsA(isA<McpAccessStorageException>()),
    );

    await blockingDirectory.delete();
    await backupFile.rename(accessFile.path);
    final recovered = await service.createGrant(
      clientName: 'Queue recovered',
      scopes: const {McpScopes.tagsWrite},
    );
    final restarted = McpAccessService(store: store);
    addTearDown(restarted.dispose);
    final state = await restarted.readState();
    expect(state.grants, hasLength(2));
    expect(await restarted.authenticate(first.token), isNotNull);
    expect(await restarted.authenticate(recovered.token), isNotNull);
  });

  test('POSIX access directory and document are owner-only', () async {
    await service.createGrant(
      clientName: 'Permission check',
      scopes: const {McpScopes.settingsRead},
    );

    final directoryMode = (await FileStat.stat(p.join(applicationDirectory.path, 'mcp'))).mode & 0x1ff;
    final fileMode = (await FileStat.stat(p.join(applicationDirectory.path, 'mcp', 'access.json'))).mode & 0x1ff;
    expect(directoryMode, 0x1c0);
    expect(fileMode, 0x180);
  }, testOn: 'linux || mac-os');

  test('unsafe POSIX permissions fail closed on read and authentication', () async {
    final issued = await service.createGrant(
      clientName: 'Unsafe permission check',
      scopes: const {McpScopes.settingsRead},
    );
    final accessDirectory = p.join(applicationDirectory.path, 'mcp');
    final accessFile = p.join(accessDirectory, 'access.json');
    addTearDown(() async {
      await Process.run('chmod', ['700', accessDirectory]);
      await Process.run('chmod', ['600', accessFile]);
    });

    expect((await Process.run('chmod', ['644', accessFile])).exitCode, 0);
    await expectLater(service.readState, throwsA(isA<McpAccessStorageException>()));
    expect(await service.authenticate(issued.token), isNull);

    expect((await Process.run('chmod', ['600', accessFile])).exitCode, 0);
    expect((await Process.run('chmod', ['755', accessDirectory])).exitCode, 0);
    await expectLater(service.readState, throwsA(isA<McpAccessStorageException>()));
    expect(await service.authenticate(issued.token), isNull);
  }, testOn: 'linux || mac-os');

  test('unwritable application directory fails without creating a grant', () async {
    final chmodResult = await Process.run('chmod', ['500', applicationDirectory.path]);
    expect(chmodResult.exitCode, 0);
    addTearDown(() => Process.run('chmod', ['700', applicationDirectory.path]));

    await expectLater(
      () => service.createGrant(
        clientName: 'Cannot persist',
        scopes: const {McpScopes.tasksRead},
      ),
      throwsA(isA<McpAccessStorageException>()),
    );
    expect(await Directory(p.join(applicationDirectory.path, 'mcp')).exists(), isFalse);
  }, testOn: 'linux || mac-os');
}

Future<File> _createAccessFile(Directory applicationDirectory) async {
  final directory = Directory(p.join(applicationDirectory.path, 'mcp'));
  await directory.create(recursive: true);
  return File(p.join(directory.path, 'access.json'));
}

Future<Directory> _createApplicationDirectory(String prefix) {
  final basePath = Platform.isWindows ? Platform.environment['LOCALAPPDATA']! : Directory.systemTemp.path;
  return Directory(basePath).createTemp(prefix);
}

class _TestApplicationDirectoryService implements IApplicationDirectoryService {
  final Directory directory;

  const _TestApplicationDirectoryService(this.directory);

  @override
  Future<Directory> getApplicationDirectory() async => directory;
}
