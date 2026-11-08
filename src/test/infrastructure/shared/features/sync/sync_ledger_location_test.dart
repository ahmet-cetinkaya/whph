// T20 acceptance 1 (U11): per-target ledger path, separate from the data dir.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/infrastructure/shared/features/sync/sync_ledger_location.dart';

void main() {
  final posix = p.Context(style: p.Style.posix);
  final dataDirectory = Directory('/home/user/.local/share/whph');

  SyncLedgerLocation resolve(
          SyncPackagingTarget target, Map<String, String> environment,
          {p.Context? pathContext, Directory? data}) =>
      resolveSyncLedgerLocation(
        target: target,
        dataDirectory: data ?? dataDirectory,
        environment: environment,
        pathContext: pathContext ?? posix,
      );

  group('native Linux', () {
    test('uses XDG_STATE_HOME/whph', () {
      final location = resolve(SyncPackagingTarget.linux,
          {'XDG_STATE_HOME': '/home/user/.state', 'HOME': '/home/user'});

      expect(location.directory.path, '/home/user/.state/whph');
      expect(location.placement, SyncLedgerPlacement.separateStateDirectory);
      expect(location.isAcceptedFullRollbackRisk, isFalse);
    });

    test('falls back to ~/.local/state/whph, outside the data directory', () {
      final location =
          resolve(SyncPackagingTarget.linux, {'HOME': '/home/user'});

      expect(location.directory.path, '/home/user/.local/state/whph');
      expect(
          posix.isWithin(dataDirectory.path, location.directory.path), isFalse);
      expect(location.placement, SyncLedgerPlacement.separateStateDirectory);
    });

    test('a relative XDG_STATE_HOME is ignored', () {
      final location = resolve(SyncPackagingTarget.linux,
          {'XDG_STATE_HOME': 'relative', 'HOME': '/home/user'});

      expect(location.directory.path, '/home/user/.local/state/whph');
    });
  });

  group('Flatpak', () {
    test(
        'uses the sandbox XDG_STATE_HOME when it is separate from the data directory',
        () {
      final location = resolve(
        SyncPackagingTarget.flatpak,
        {'XDG_STATE_HOME': '/home/user/.var/app/id/.local/state'},
        data: Directory('/home/user/.var/app/id/data'),
      );

      expect(
          location.directory.path, '/home/user/.var/app/id/.local/state/whph');
      expect(location.placement, SyncLedgerPlacement.separateStateDirectory);
    });

    test(
        'without a separate state directory the ledger stays in the data dir and is recorded as accepted risk',
        () {
      final location =
          resolve(SyncPackagingTarget.flatpak, {'HOME': '/home/user'});

      expect(location.directory.path, dataDirectory.path);
      expect(location.placement, SyncLedgerPlacement.insideDataDirectory);
      expect(location.isAcceptedFullRollbackRisk, isTrue);
    });
  });

  group('Windows', () {
    final windows = p.Context(style: p.Style.windows);

    test('uses %LOCALAPPDATA%\\WHPH\\state, separate from %APPDATA%', () {
      final location = resolve(
        SyncPackagingTarget.windows,
        {'LOCALAPPDATA': r'C:\Users\u\AppData\Local'},
        pathContext: windows,
        data: Directory(r'C:\Users\u\AppData\Roaming\whph'),
      );

      expect(location.directory.path, r'C:\Users\u\AppData\Local\WHPH\state');
      expect(location.placement, SyncLedgerPlacement.separateStateDirectory);
    });
  });

  group('Android', () {
    test(
        'uses app-private storage (the data directory) and is not accepted risk',
        () {
      final location =
          resolve(SyncPackagingTarget.android, {'HOME': '/data/user/0/app'});

      expect(location.directory.path, dataDirectory.path);
      expect(location.placement, SyncLedgerPlacement.appPrivate);
      expect(location.isAcceptedFullRollbackRisk, isFalse);
    });
  });

  test('the running process resolves to a known target', () {
    expect(
        detectSyncPackagingTarget({'FLATPAK_ID': 'io.example'}),
        Platform.isLinux
            ? SyncPackagingTarget.flatpak
            : isA<SyncPackagingTarget>());
    expect(detectSyncPackagingTarget({}), isA<SyncPackagingTarget>());
  });
}
