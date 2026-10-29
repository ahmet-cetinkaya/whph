import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/presentation/ui/features/sync/components/needs_repairing_card.dart';
import 'package:whph/presentation/ui/features/sync/components/removed_from_group_card.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_group_state_card.dart';

import 'support/sync_test_support.dart';

void main() {
  late SyncTestHarness harness;

  setUp(() => harness = SyncTestHarness());

  Future<void> pumpFor(WidgetTester tester, SyncGroupState state) =>
      pumpPage(tester, SyncGroupStateCard(groupState: state, onPair: () {}));

  for (final state in SyncGroupState.values) {
    testWidgets('$state shows exactly the card meant for it', (tester) async {
      await pumpFor(tester, state);

      expect(find.byType(NeedsRepairingCard), state == SyncGroupState.needsRepairing ? findsOneWidget : findsNothing);
      expect(
          find.byType(RemovedFromGroupCard), state == SyncGroupState.removedFromGroup ? findsOneWidget : findsNothing);
    });
  }
}
