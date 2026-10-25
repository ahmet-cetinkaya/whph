import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/commands/cancel_pairing_command.dart';
import 'package:whph/core/application/features/sync/commands/create_pairing_invitation_command.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_pairing_status_query.dart';
import 'package:whph/presentation/ui/features/sync/components/pairing_qr_view.dart';

import 'support/sync_test_support.dart';

void main() {
  late SyncTestHarness harness;
  late DateTime now;
  late SyncPairingStatus status;

  const invitationLifetime = Duration(minutes: 5);

  PairingInvitation invitationExpiringAt(DateTime expiresAt) => PairingInvitation(
        memberId: 'member-1',
        addresses: const ['192.168.1.2'],
        port: syncLanPort,
        fingerprint: const [1, 2, 3],
        token: const [4, 5, 6],
        expiresAt: expiresAt,
      );

  setUp(() {
    harness = SyncTestHarness();
    now = DateTime(2026, 1, 1, 12);
    status = const SyncPairingStatus(phase: SyncPairingPhase.waitingForScan, role: SyncPairingRole.inviter);
    harness.on<CreatePairingInvitationCommand, CreatePairingInvitationCommandResponse>(
      (_) => CreatePairingInvitationCommandResponse(
        invitation: invitationExpiringAt(now.add(invitationLifetime)),
        qrText: 'whph-pair:1:test',
      ),
    );
    harness.on<GetSyncPairingStatusQuery, SyncPairingStatus>((_) => status);
    harness.on<CancelPairingCommand, void>((_) {});
  });

  Future<void> pumpQrView(WidgetTester tester) async {
    await pumpPage(tester, PairingQrView(now: () => now));
    await tester.pump();
  }

  Future<void> advance(WidgetTester tester, Duration elapsed) async {
    now = now.add(elapsed);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  testWidgets('shows the QR code with the 5-minute countdown', (tester) async {
    await pumpQrView(tester);

    expect(find.text('Expires in 05:00'), findsOneWidget);

    await advance(tester, const Duration(seconds: 90));

    expect(find.text('Expires in 03:30'), findsOneWidget);
  });

  testWidgets('shows expired after 5 minutes and regenerates a new code', (tester) async {
    await pumpQrView(tester);

    await advance(tester, invitationLifetime + const Duration(seconds: 1));

    expect(find.text('This code has expired.'), findsOneWidget);
    expect(find.textContaining('Expires in'), findsNothing);

    await tester.tap(find.text('Show a new code'));
    await tester.pump();
    await tester.pump();

    expect(harness.sentCount<CreatePairingInvitationCommand>(), 2);
    expect(find.text('Expires in 05:00'), findsOneWidget);
  });

  testWidgets('keeps showing the code at 4:59', (tester) async {
    await pumpQrView(tester);

    await advance(tester, const Duration(minutes: 4, seconds: 59));

    expect(find.text('Expires in 00:01'), findsOneWidget);
  });

  testWidgets('shows used when the code was already used', (tester) async {
    await pumpQrView(tester);
    status = const SyncPairingStatus(
      phase: SyncPairingPhase.failed,
      role: SyncPairingRole.inviter,
      errorCode: SyncPairingErrorCode.codeExpiredOrUsed,
    );

    await advance(tester, const Duration(seconds: 1));

    expect(find.text('This code was already used.'), findsOneWidget);
    expect(find.text('Show a new code'), findsOneWidget);
  });

  testWidgets('shows pairing in progress while the other device connects', (tester) async {
    await pumpQrView(tester);
    status = const SyncPairingStatus(phase: SyncPairingPhase.connecting, role: SyncPairingRole.inviter);

    await advance(tester, const Duration(seconds: 1));

    expect(find.text('Pairing in progress…'), findsOneWidget);
  });

  testWidgets('shows paired when the pairing completed', (tester) async {
    await pumpQrView(tester);
    status = const SyncPairingStatus(
      phase: SyncPairingPhase.completed,
      role: SyncPairingRole.inviter,
      peerName: 'Pixel',
    );

    await advance(tester, const Duration(seconds: 1));

    expect(find.text('Device paired'), findsOneWidget);
  });

  testWidgets('stops showing the invitation when the view closes', (tester) async {
    await pumpQrView(tester);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    expect(harness.sentCount<CancelPairingCommand>(), 1);
  });
}
