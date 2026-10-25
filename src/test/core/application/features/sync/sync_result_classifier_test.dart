// T23: how a session result becomes the category the peer's status shows
// (FR-016). The codes are not localized; "clock differs" does not exist (U10).
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/services/sync_result_classifier.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

SessionFailed _failed(SessionFailure failure) => SessionFailed(SessionStats(), 'peer', failure);

SessionPartial _partial(Set<PartialReason> reasons) => SessionPartial(SessionStats(), 'peer', reasons);

void main() {
  test('a complete session leaves no category', () {
    expect(classifySessionResult(SessionComplete(SessionStats(), 'peer')), isNull);
  });

  group('failed sessions', () {
    const expected = {
      SessionFailure.notReachable: SyncResultCategory.notReachable,
      SessionFailure.notAuthorized: SyncResultCategory.needsRepairing,
      SessionFailure.refusedByPeer: SyncResultCategory.needsRepairing,
      SessionFailure.needsUpdate: SyncResultCategory.needsUpdate,
      SessionFailure.peerPreparing: SyncResultCategory.preparing,
      SessionFailure.restoreDetected: SyncResultCategory.preparing,
      SessionFailure.protocolError: SyncResultCategory.rejectedItems,
      SessionFailure.securityError: SyncResultCategory.rejectedItems,
      SessionFailure.peerError: SyncResultCategory.someItemsFailed,
      SessionFailure.internal: SyncResultCategory.someItemsFailed,
    };

    for (final entry in expected.entries) {
      test('${entry.key.name} shows ${entry.value.code}', () {
        expect(classifySessionResult(_failed(entry.key)), entry.value);
        expect(leavesStatusUnchanged(_failed(entry.key)), isFalse);
      });
    }

    for (final failure in [SessionFailure.busy, SessionFailure.notPaired, SessionFailure.removedFromGroup]) {
      test('${failure.name} says nothing about the peer', () {
        expect(classifySessionResult(_failed(failure)), isNull);
        expect(leavesStatusUnchanged(_failed(failure)), isTrue);
      });
    }

    test('every failure is classified one way or the other', () {
      for (final failure in SessionFailure.values) {
        final classified = expected.containsKey(failure);
        final unchanged = leavesStatusUnchanged(_failed(failure));
        expect(classified != unchanged, isTrue, reason: failure.name);
      }
    });
  });

  group('partial sessions', () {
    test('each reason has its category', () {
      expect(classifySessionResult(_partial({PartialReason.itemsFailed})), SyncResultCategory.someItemsFailed);
      expect(classifySessionResult(_partial({PartialReason.itemsRejected})), SyncResultCategory.rejectedItems);
      expect(classifySessionResult(_partial({PartialReason.storageError})), SyncResultCategory.storageError);
    });

    test('several reasons show the most serious: storage error, then rejected items', () {
      expect(
        classifySessionResult(_partial({PartialReason.itemsFailed, PartialReason.itemsRejected})),
        SyncResultCategory.rejectedItems,
      );
      expect(
        classifySessionResult(_partial(PartialReason.values.toSet())),
        SyncResultCategory.storageError,
      );
    });
  });

  test('the stored codes round-trip and an unknown code is no category', () {
    for (final category in SyncResultCategory.values) {
      expect(SyncResultCategory.fromCode(category.code), category);
    }
    expect(SyncResultCategory.fromCode('clock_differs'), isNull);
    expect(SyncResultCategory.fromCode(null), isNull);
  });
}
