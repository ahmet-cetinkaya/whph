// A complete application container (persistence, infrastructure, application,
// presentation)
// over a temporary data directory, for the tests that need every registration.
import 'dart:io';

import 'package:acore/acore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/application_container.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:whph/infrastructure/infrastructure_container.dart';
import 'package:whph/infrastructure/persistence/persistence_container.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;
import 'package:whph/presentation/ui/ui_presentation_container.dart';

class _FixedApplicationDirectory implements IApplicationDirectoryService {
  final Directory _directory;

  _FixedApplicationDirectory(this._directory);

  @override
  Future<Directory> getApplicationDirectory() async => _directory;
}

/// Builds the container the app builds at launch, with the database, the key
/// file and the ledger under [root]. Closes the database when the test ends.
Future<IContainer> buildSyncTestContainer(Directory root) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  _silenceAudioPlugin();
  initializeJsonMapper();
  AppDatabase.resetInstance();
  AppDatabase.isTestMode = true;
  AppDatabase.testDirectory = root;
  final container = Container()..clear();
  registerPersistence(container);
  registerInfrastructure(
    container,
    applicationDirectoryService: _FixedApplicationDirectory(root),
    syncDataDirectory: Directory('${root.path}/data'),
    syncLedgerDirectory: Directory('${root.path}/state'),
  );
  registerApplication(container);
  registerUIPresentation(container);
  addTearDown(() async {
    container.clear();
    await AppDatabase.instance().close();
    AppDatabase.resetInstance();
  });
  return container;
}

/// The presentation container creates the audio player, and a settings write
/// refreshes the theme through the window plugin; the tests have no platform
/// side.
void _silenceAudioPlugin() {
  const channels = [
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers',
    'me.ahmetcetinkaya.whph/window_management',
  ];
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in channels) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async => null);
  }
}
