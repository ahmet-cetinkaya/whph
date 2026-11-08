// S2 spike (plan T4): D3 trigger capture on task_table (field-level) and task_time_record_table (row-level).
// Scenarios live in trigger_spike_scenarios.dart and also run on devices via
// integration_test/sync_trigger_spike_test.dart.
//
// Under `flutter test` the Dart profiler cuts SQLite's busy-handler sleep short, so writes across connections are
// interleaved sequentially here; overlapping writers are covered by trigger_spike_vm_test.dart (`fvm dart test`).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

import 'trigger_spike_scenarios.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUpAll(() async {
    tempRoot = await Directory.systemTemp.createTemp('whph_s2_unit_');
    AppDatabase.testDirectory = tempRoot;
    AppDatabase.isTestMode = true;
  });

  tearDownAll(() async {
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  group('S2 trigger spike', () {
    defineTriggerSpikeTests(
      (description, body) => test(description, body, timeout: const Timeout(Duration(minutes: 5))),
      tempRoot: () async => tempRoot,
    );
  });
}
