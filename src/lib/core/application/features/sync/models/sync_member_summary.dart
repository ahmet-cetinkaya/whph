import 'package:whph/core/application/features/sync/models/sync_result_category.dart';

/// One device of the sync group as the status list shows it (FR-016, FR-017).
class SyncMemberSummary {
  /// The member id, or the legacy device row id when [isLegacy].
  final String memberId;
  final String name;
  final String? platform;

  /// Local time of the last fully successful session; unchanged by failures.
  final DateTime? lastSuccessfulSync;

  /// Why the last session was not fully successful; `null` when it was.
  final SyncResultCategory? lastResult;

  /// FR-017: the same item failed to apply in 3 consecutive sessions.
  final bool itemsCannotBeApplied;

  /// A device paired with the old sync (FR-061): it must pair again.
  final bool isLegacy;
  final bool isThisDevice;

  const SyncMemberSummary({
    required this.memberId,
    required this.name,
    this.platform,
    this.lastSuccessfulSync,
    this.lastResult,
    this.itemsCannotBeApplied = false,
    this.isLegacy = false,
    this.isThisDevice = false,
  });
}
