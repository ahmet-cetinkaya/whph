// S2 spike (plan T4) on a real device/desktop build:
//   cd src && fvm flutter test integration_test/sync_trigger_spike_test.dart -d linux
//   cd src && fvm flutter test integration_test/sync_trigger_spike_test.dart -d <android-device-id>
// Uses the platform temporary directory (path_provider) for file databases and prints measurements prefixed
// with `[S2]`. The scenarios are shared with test/infrastructure/persistence/sync/trigger_spike_test.dart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

import '../test/infrastructure/persistence/sync/trigger_spike_scenarios.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Directory? root;
  Future<Directory> tempRoot() async {
    if (root != null) return root!;
    final base = await getTemporaryDirectory();
    root = await Directory('${base.path}/whph_s2_it').create(recursive: true);
    AppDatabase.testDirectory = root;
    AppDatabase.isTestMode = true;
    spikeLog('platform=${Platform.operatingSystem} ${Platform.operatingSystemVersion}; temp=${root!.path}');
    return root!;
  }

  tearDownAll(() async {
    if (root != null && await root!.exists()) await root!.delete(recursive: true);
  });

  group('S2 trigger spike (device)', () {
    defineTriggerSpikeTests(
      (description, body) => testWidgets(description, (tester) async {
        await tempRoot();
        await tester.runAsync(body);
      }, timeout: const Timeout(Duration(minutes: 15))),
      tempRoot: tempRoot,
    );
  });
}
