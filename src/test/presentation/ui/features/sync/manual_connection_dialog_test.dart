import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:whph/presentation/ui/features/sync/components/manual_connection_dialog.dart';

import 'support/sync_test_support.dart';

class _FakeHandshakeService extends Fake implements DeviceHandshakeService {}

void main() {
  late List<String> pairedCodes;

  final validCode = PairingInvitation(
    memberId: 'member-1',
    addresses: const ['192.168.1.2'],
    port: syncLanPort,
    fingerprint: const [1, 2, 3],
    token: const [4, 5, 6],
    expiresAt: DateTime(2026, 1, 1, 12),
  ).encode();

  setUp(() {
    SyncTestHarness(extraServices: {DeviceHandshakeService: _FakeHandshakeService()});
    pairedCodes = [];
  });

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ManualConnectionDialog(
        onConnect: (_) {},
        onPairWithCode: (code) async => pairedCodes.add(code),
      ),
    ));
    await tester.pump();
  }

  testWidgets('rejects text that is not a pairing invitation', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextFormField).first, 'whph://192.168.1.2:44040?name=A&id=b');
    await tester.tap(find.text('Connect'));
    await tester.pump();

    expect(find.text('This is not a valid pairing code'), findsOneWidget);
    expect(pairedCodes, isEmpty);
  });

  testWidgets('rejects an empty pairing code', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.text('Connect'));
    await tester.pump();

    expect(find.text('Pairing code is required'), findsOneWidget);
    expect(pairedCodes, isEmpty);
  });

  testWidgets('hands a real invitation to onPairWithCode', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextFormField).first, validCode);
    await tester.tap(find.text('Connect'));
    await tester.pump();

    expect(pairedCodes, [validCode]);
  });
}
