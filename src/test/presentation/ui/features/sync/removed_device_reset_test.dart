import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/commands/renew_sync_identity_command.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/services/sync_pairing_flow.dart';
import 'package:whph/presentation/ui/features/sync/utils/sync_result_texts.dart';

import 'support/sync_test_support.dart';

void main() {
  late SyncTestHarness harness;

  SyncPairingStatus removedStatus(SyncPairingRole role) => SyncPairingStatus(
        phase: SyncPairingPhase.failed,
        role: role,
        errorCode: SyncPairingErrorCode.removedDevice,
      );

  setUp(() {
    harness = SyncTestHarness();
    harness.on<RenewSyncIdentityCommand, void>((_) {});
  });

  Future<void> pumpOutcomeHost(WidgetTester tester, SyncPairingStatus status) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => SyncPairingFlow.showOutcome(context, status),
          child: const Text('finish'),
        ),
      ),
    ));
    await tester.tap(find.text('finish'));
    await tester.pumpAndSettle();
  }

  test('maps the removed device error code to its own text', () {
    expect(SyncResultTexts.pairingErrorKey(SyncPairingErrorCode.removedDevice),
        SyncTranslationKeys.pairingErrorRemovedDevice);
    expect(harness.translations.hasText(SyncTranslationKeys.pairingErrorRemovedDevice), isTrue);
  });

  testWidgets('offers the identity reset to a joiner that was removed', (tester) async {
    await pumpOutcomeHost(tester, removedStatus(SyncPairingRole.joiner));

    expect(find.text('Reset identity'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('sends nothing when the user cancels', (tester) async {
    await pumpOutcomeHost(tester, removedStatus(SyncPairingRole.joiner));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(harness.sentCount<RenewSyncIdentityCommand>(), 0);
  });

  testWidgets('renews the identity and asks for a new code when the user confirms', (tester) async {
    await pumpOutcomeHost(tester, removedStatus(SyncPairingRole.joiner));

    await tester.tap(find.text('Reset identity'));
    await tester.pumpAndSettle();

    expect(harness.sentCount<RenewSyncIdentityCommand>(), 1);
    expect(find.textContaining('Scan a new code'), findsOneWidget);
  });

  testWidgets('does not offer the reset to the inviter', (tester) async {
    await pumpOutcomeHost(tester, removedStatus(SyncPairingRole.inviter));

    expect(find.text('Reset identity'), findsNothing);
  });
}
