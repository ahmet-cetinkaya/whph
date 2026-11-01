import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/commands/cancel_pairing_command.dart';
import 'package:whph/core/application/features/sync/commands/confirm_group_switch_command.dart';
import 'package:whph/core/application/features/sync/commands/confirm_pairing_code_command.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_pairing_status_query.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_pairing_status_listener.dart';
import 'package:whph/presentation/ui/features/sync/services/sync_pairing_flow.dart';

import 'support/sync_test_support.dart';

void main() {
  late SyncTestHarness harness;
  SyncPairingStatus? outcome;

  const comparing = SyncPairingStatus(
    phase: SyncPairingPhase.comparingCodes,
    role: SyncPairingRole.joiner,
    code: '482913',
    peerName: 'Laptop',
  );
  const switching = SyncPairingStatus(
    phase: SyncPairingPhase.awaitingGroupSwitch,
    role: SyncPairingRole.joiner,
    peerName: 'Laptop',
  );
  const completed = SyncPairingStatus(phase: SyncPairingPhase.completed, role: SyncPairingRole.joiner);

  setUp(() {
    harness = SyncTestHarness();
    outcome = null;
    harness.on<ConfirmPairingCodeCommand, SyncPairingStatus>((_) => completed);
    harness.on<ConfirmGroupSwitchCommand, SyncPairingStatus>((_) => completed);
    harness.on<CancelPairingCommand, void>((_) {});
  });

  Future<void> pumpResolvingHost(WidgetTester tester, SyncPairingStatus first) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => outcome = await SyncPairingFlow(harness.mediator).resolve(context, first),
          child: const Text('start'),
        ),
      ),
    ));
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
  }

  group('code comparison (SAS)', () {
    testWidgets('shows the code and the peer name, and confirms when the codes match', (tester) async {
      await pumpResolvingHost(tester, comparing);

      expect(find.text('482913'), findsOneWidget);
      expect(find.text('Make sure Laptop shows the same code.'), findsOneWidget);

      await tester.tap(find.text('Codes match'));
      await tester.pumpAndSettle();

      expect(harness.sentCount<ConfirmPairingCodeCommand>(), 1);
      expect(harness.sentCount<CancelPairingCommand>(), 0);
      expect(outcome?.phase, SyncPairingPhase.completed);
    });

    testWidgets('cancels the pairing when the codes differ', (tester) async {
      await pumpResolvingHost(tester, comparing);

      await tester.tap(find.text('Codes differ'));
      await tester.pumpAndSettle();

      expect(harness.sentCount<CancelPairingCommand>(), 1);
      expect(harness.sentCount<ConfirmPairingCodeCommand>(), 0);
      expect(outcome?.phase, SyncPairingPhase.failed);
      expect(outcome?.errorCode, SyncPairingErrorCode.codesDiffer);
    });

    testWidgets('the inviting device shows the same dialog', (tester) async {
      harness.on<GetSyncPairingStatusQuery, SyncPairingStatus>(
        (_) => const SyncPairingStatus(
          phase: SyncPairingPhase.comparingCodes,
          role: SyncPairingRole.inviter,
          code: '482913',
          peerName: 'Phone',
        ),
      );
      await tester.pumpWidget(MaterialApp(
        home: SyncPairingStatusListener(
          mediator: harness.mediator,
          pollInterval: const Duration(milliseconds: 100),
          child: const Scaffold(body: SizedBox()),
        ),
      ));

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('Compare codes'), findsOneWidget);
      expect(find.text('Make sure Phone shows the same code.'), findsOneWidget);

      await tester.tap(find.text('Codes match'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });

  group('group switch', () {
    testWidgets('names the other device and confirms', (tester) async {
      await pumpResolvingHost(tester, switching);

      expect(find.textContaining('Laptop is in a different sync group'), findsOneWidget);

      await tester.tap(find.text('Switch group'));
      await tester.pumpAndSettle();

      expect(harness.sentCount<ConfirmGroupSwitchCommand>(), 1);
      expect(outcome?.phase, SyncPairingPhase.completed);
    });

    testWidgets('cancel ends the pairing without switching', (tester) async {
      await pumpResolvingHost(tester, switching);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(harness.sentCount<CancelPairingCommand>(), 1);
      expect(harness.sentCount<ConfirmGroupSwitchCommand>(), 0);
      expect(outcome?.errorCode, SyncPairingErrorCode.groupSwitchDeclined);
    });
  });
}
