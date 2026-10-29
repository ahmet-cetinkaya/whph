import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:whph/core/application/features/sync/models/sync_member_summary.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_device_list_item/sync_device_list_item.dart';
import 'package:whph/presentation/ui/features/sync/utils/sync_result_texts.dart';

import 'support/sync_test_support.dart';

void main() {
  late SyncTestHarness harness;

  setUpAll(() async => initializeDateFormatting());
  setUp(() => harness = SyncTestHarness());

  Future<void> pumpItem(
    WidgetTester tester,
    SyncMemberSummary member, {
    void Function(String)? onRemove,
    void Function(String)? onRepair,
  }) =>
      pumpPage(
        tester,
        SyncDeviceListItemWidget(member: member, onRemove: onRemove ?? (_) {}, onRepair: onRepair),
      );

  const categoryTexts = {
    SyncResultCategory.notReachable: 'Device not reachable',
    SyncResultCategory.someItemsFailed: 'Some items could not be synced',
    SyncResultCategory.rejectedItems: 'Some items were rejected as invalid',
    SyncResultCategory.preparing: 'The other device is preparing its sync data',
    SyncResultCategory.duplicatedIdentity: 'Another device uses the same sync identity',
    SyncResultCategory.storageError: 'A storage error interrupted the sync',
  };

  group('last sync and category', () {
    testWidgets('a device that never synced says so and shows no category', (tester) async {
      await pumpItem(tester, const SyncMemberSummary(memberId: 'm1', name: 'Pixel'));

      expect(find.text('Pixel'), findsOneWidget);
      expect(find.text('Never synced'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsNothing);
    });

    testWidgets('shows the time of the last successful sync', (tester) async {
      await pumpItem(
        tester,
        SyncMemberSummary(memberId: 'm1', name: 'Pixel', lastSuccessfulSync: DateTime(2026, 3, 14, 9, 30)),
      );

      expect(find.text('Never synced'), findsNothing);
      expect(find.textContaining('2026'), findsOneWidget);
    });

    for (final entry in categoryTexts.entries) {
      testWidgets('shows the text of ${entry.key.code}', (tester) async {
        await pumpItem(tester, SyncMemberSummary(memberId: 'm1', name: 'Pixel', lastResult: entry.key));

        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('needs-update text names the device', (tester) async {
      await pumpItem(
        tester,
        const SyncMemberSummary(memberId: 'm1', name: 'Pixel 9', lastResult: SyncResultCategory.needsUpdate),
      );

      expect(find.text('Pixel 9 needs a newer version of WHPH to sync'), findsOneWidget);
    });

    testWidgets('older peer: names the peer device as needing the update', (tester) async {
      await pumpItem(
        tester,
        const SyncMemberSummary(memberId: 'm1', name: 'Old phone', lastResult: SyncResultCategory.needsUpdate),
      );

      expect(find.text('Old phone needs a newer version of WHPH to sync'), findsOneWidget);
    });

    testWidgets('older this device: tells the user to update this device and names the newer peer', (tester) async {
      await pumpItem(
        tester,
        const SyncMemberSummary(
          memberId: 'm1',
          name: 'New laptop',
          lastResult: SyncResultCategory.thisDeviceNeedsUpdate,
        ),
      );

      expect(
          find.text('Update WHPH on this device to sync with New laptop, which runs a newer version'), findsOneWidget);
    });

    testWidgets('warns about items that repeatedly cannot be applied', (tester) async {
      await pumpItem(tester, const SyncMemberSummary(memberId: 'm1', name: 'Pixel', itemsCannotBeApplied: true));

      expect(find.text('Some items failed repeatedly and are skipped for now'), findsOneWidget);
    });

    testWidgets('every category and pairing error code has a text', (tester) async {
      for (final category in SyncResultCategory.values) {
        expect(harness.translations.hasText(SyncResultTexts.categoryKey(category)), isTrue, reason: category.code);
      }
      for (final code in [
        SyncPairingErrorCode.codeExpiredOrUsed,
        SyncPairingErrorCode.codesDiffer,
        SyncPairingErrorCode.cancelled,
        SyncPairingErrorCode.unreachable,
        SyncPairingErrorCode.invalidInvitation,
        SyncPairingErrorCode.groupSwitchDeclined,
        SyncPairingErrorCode.preparing,
        SyncPairingErrorCode.refused,
        SyncPairingErrorCode.noActivePairing,
      ]) {
        expect(harness.translations.hasText(SyncResultTexts.pairingErrorKey(code)), isTrue, reason: code);
      }
      expect(SyncResultTexts.pairingErrorKey('unknown'), SyncResultTexts.pairingErrorKey(SyncPairingErrorCode.refused));
    });
  });

  group('needs re-pairing', () {
    testWidgets('shows the badge and starts pairing again from its action', (tester) async {
      String? repaired;
      await pumpItem(
        tester,
        const SyncMemberSummary(memberId: 'm1', name: 'Pixel', lastResult: SyncResultCategory.needsRepairing),
        onRepair: (id) => repaired = id,
      );

      expect(find.byKey(const ValueKey('needs-repair-badge')), findsOneWidget);
      expect(find.text('Re-pair needed'), findsOneWidget);

      await tester.tap(find.text('Re-pair'));

      expect(repaired, 'm1');
    });

    testWidgets('a device paired with the old sync shows the badge', (tester) async {
      await pumpItem(tester, const SyncMemberSummary(memberId: 'old-1', name: 'Old tablet', isLegacy: true));

      expect(find.byKey(const ValueKey('needs-repair-badge')), findsOneWidget);
    });

    testWidgets('a healthy device shows no badge', (tester) async {
      await pumpItem(tester, const SyncMemberSummary(memberId: 'm1', name: 'Pixel'));

      expect(find.byKey(const ValueKey('needs-repair-badge')), findsNothing);
    });
  });

  testWidgets('the remove button reports the member id', (tester) async {
    String? removed;
    await pumpItem(tester, const SyncMemberSummary(memberId: 'm1', name: 'Pixel'), onRemove: (id) => removed = id);

    await tester.tap(find.byIcon(Icons.delete_outline));

    expect(removed, 'm1');
  });
}
