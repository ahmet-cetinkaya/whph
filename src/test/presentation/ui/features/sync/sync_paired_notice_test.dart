import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/queries/get_is_paired_query.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/presentation/ui/features/settings/components/reset_database_dialog.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_paired_notice.dart';
import 'package:whph/presentation/ui/features/sync/utils/sync_result_texts.dart';
import 'package:whph/core/application/features/demo/models/demo_reset_blocked_exception.dart';

import 'support/sync_test_support.dart';

void main() {
  late SyncTestHarness harness;

  const importUnionSentence = 'Replacing existing data does not delete items group-wide';
  const resetLeavesGroupSentence = 'Resetting also removes it from the sync group, so you must pair it again';

  setUp(() => harness = SyncTestHarness());

  void answerPaired({required bool isPaired}) => harness.on<GetIsPairedQuery, GetIsPairedQueryResponse>(
        (_) => GetIsPairedQueryResponse(
          isPaired: isPaired,
          groupState: isPaired ? SyncGroupState.member : SyncGroupState.ungrouped,
        ),
      );

  group('import dialog union sentence (U4)', () {
    testWidgets('paired: the union sentence is shown', (tester) async {
      answerPaired(isPaired: true);

      await pumpPage(tester, const SyncPairedNotice(translationKey: SettingsTranslationKeys.importStrategyPairedNote));
      await tester.pump();

      expect(find.textContaining(importUnionSentence), findsOneWidget);
      expect(find.textContaining('return to this device at the next sync'), findsOneWidget);
    });

    testWidgets('unpaired: the sentence is absent', (tester) async {
      answerPaired(isPaired: false);

      await pumpPage(tester, const SyncPairedNotice(translationKey: SettingsTranslationKeys.importStrategyPairedNote));
      await tester.pump();

      expect(find.textContaining(importUnionSentence), findsNothing);
    });
  });

  group('reset database dialog (U5)', () {
    testWidgets('paired: says the device leaves the sync group and must be re-paired', (tester) async {
      answerPaired(isPaired: true);

      await tester.pumpWidget(const MaterialApp(home: ResetDatabaseDialog()));
      await tester.pump();

      expect(find.textContaining(resetLeavesGroupSentence), findsOneWidget);
    });

    testWidgets('unpaired: the group text is absent', (tester) async {
      answerPaired(isPaired: false);

      await tester.pumpWidget(const MaterialApp(home: ResetDatabaseDialog()));
      await tester.pump();

      expect(find.textContaining('sync group'), findsNothing);
    });
  });

  group('refused operations (U6, D17)', () {
    String? messageFor(Object error) {
      final key = SyncResultTexts.refusalKey(error);
      return key == null ? null : harness.translations.translate(key);
    }

    test('the demo reset on a paired device explains why it is blocked', () {
      final message = messageFor(const DemoResetBlockedException());

      expect(message, contains('Demo data cannot be reset while this device is paired'));
      expect(message, contains('Remove this device from the sync group first'));
    });

    test('the preparing state error says sync is preparing', () {
      expect(messageFor(StateError('preparing: upgrade phase bootstrap is running')),
          'Sync is preparing. Please try again shortly.');
    });

    test('other errors have no refusal text', () {
      expect(messageFor(StateError('not in a group')), isNull);
      expect(messageFor(Exception('boom')), isNull);
    });
  });
}
