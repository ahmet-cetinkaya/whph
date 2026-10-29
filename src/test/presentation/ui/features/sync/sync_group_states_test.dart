import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_upgrade_progress_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/features/sync/components/needs_repairing_card.dart';
import 'package:whph/presentation/ui/features/sync/components/remove_member_dialog.dart';
import 'package:whph/presentation/ui/features/sync/components/removed_from_group_card.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_repair_banner.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_upgrade_progress_banner.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/components/sync_devices_empty_state.dart';

import 'support/sync_test_support.dart';

class _FakeSettingRepository extends Fake implements ISettingRepository {
  Setting? stored;

  @override
  Future<Setting?> getByKey(String key) async => stored;
}

void main() {
  late SyncTestHarness harness;

  setUp(() => harness = SyncTestHarness());

  group('upgrade progress', () {
    Future<void> pumpProgress(WidgetTester tester, SyncUpgradePhase phase) async {
      harness.on<GetSyncUpgradeProgressQuery, SyncUpgradeProgress>((_) => SyncUpgradeProgress(phase: phase));
      await pumpPage(tester, const SyncUpgradeProgressBanner());
      await tester.pump();
    }

    testWidgets('shows Preparing sync data with a percentage while the upgrade runs', (tester) async {
      await pumpProgress(tester, SyncUpgradePhase.bootstrap);

      expect(find.text('Preparing sync data… 33%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('starts at 0% in the first phase', (tester) async {
      await pumpProgress(tester, SyncUpgradePhase.dedupe);

      expect(find.text('Preparing sync data… 0%'), findsOneWidget);
    });

    testWidgets('shows nothing once the upgrade is done', (tester) async {
      await pumpProgress(tester, SyncUpgradePhase.done);

      expect(find.textContaining('Preparing sync data'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('remove device', () {
    testWidgets('explains that the removal covers the whole group', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => RemoveMemberDialog.confirm(context, deviceName: 'Pixel'),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Remove Pixel?'), findsOneWidget);
      expect(find.textContaining('removes Pixel from the whole sync group, not just from this device'), findsOneWidget);
    });

    testWidgets('confirming returns true and cancelling returns false', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await RemoveMemberDialog.confirm(context, deviceName: 'Pixel'),
            child: const Text('open'),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from group'));
      await tester.pumpAndSettle();
      expect(result, isTrue);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  testWidgets('removed-from-group state explains it and offers pairing again', (tester) async {
    var paired = false;
    await pumpPage(tester, RemovedFromGroupCard(onPair: () => paired = true));

    expect(find.textContaining('Removed from the sync group'), findsOneWidget);
    expect(find.textContaining('no longer syncs'), findsOneWidget);

    await tester.tap(find.text('Add new device'));

    expect(paired, isTrue);
  });

  testWidgets('needs-repairing state explains the stale restore and offers pairing again', (tester) async {
    var paired = false;
    await pumpPage(tester, NeedsRepairingCard(onPair: () => paired = true));

    expect(find.textContaining('Pair this device again'), findsOneWidget);
    expect(find.textContaining('older backup'), findsOneWidget);

    await tester.tap(find.text('Add new device'));

    expect(paired, isTrue);
  });

  testWidgets('empty state says there are no synced devices and offers adding one', (tester) async {
    var added = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SyncDevicesEmptyState(
          message: harness.translations.translate('sync.devices.no_devices_found'),
          addDeviceLabel: harness.translations.translate('sync.add.device_tooltip'),
          onAddDevice: () => added = true,
        ),
      ),
    ));

    expect(find.text('No synced devices'), findsOneWidget);

    await tester.tap(find.text('Add new device'));

    expect(added, isTrue);
  });

  group('re-pair banner (FR-061)', () {
    testWidgets('explains the upgrade and reports dismiss and pair', (tester) async {
      var dismissed = false;
      var paired = false;
      await pumpPage(tester, SyncRepairBanner(onPair: () => paired = true, onDismiss: () => dismissed = true));

      expect(find.textContaining('Sync was upgraded'), findsOneWidget);
      expect(find.textContaining('must be paired again'), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      await tester.tap(find.text('Re-pair'));

      expect(dismissed, isTrue);
      expect(paired, isTrue);
    });

    test('is shown once: dismissing is stored and read back', () async {
      final repository = _FakeSettingRepository();
      harness.on<SaveSettingCommand, SaveSettingCommandResponse>((command) {
        repository.stored = Setting(
          id: 's1',
          createdDate: DateTime(2026),
          key: command.key,
          value: command.value,
          valueType: command.valueType,
        );
        return SaveSettingCommandResponse(id: 's1', createdDate: DateTime(2026));
      });
      final preference = SyncRepairBannerPreference(settingRepository: repository, mediator: harness.mediator);

      expect(await preference.isDismissed(), isFalse);

      await preference.dismiss();

      expect(await preference.isDismissed(), isTrue);
      final saved = harness.sentRequests.whereType<SaveSettingCommand>().single;
      expect(saved.key, SyncRepairBannerPreference.settingKey);
      expect(saved.value, 'true');
    });
  });
}
