/// Why the last session with a peer was not fully successful (FR-016). The
/// codes are not localized: the UI layer (T24) maps each one to a text. There
/// is deliberately no "clock differs" category (U10).
enum SyncResultCategory {
  notReachable('not_reachable'),
  needsRepairing('needs_repairing'),
  needsUpdate('needs_update'),
  someItemsFailed('items_failed'),
  rejectedItems('items_rejected'),
  preparing('preparing'),
  duplicatedIdentity('duplicated_identity'),
  storageError('storage_error');

  /// The value stored in `sync_peer_state_table.last_result_category`.
  final String code;

  const SyncResultCategory(this.code);

  /// `null` for an empty or unknown stored value.
  static SyncResultCategory? fromCode(String? code) {
    for (final category in values) {
      if (category.code == code) return category;
    }
    return null;
  }
}

/// Error codes of a refused pairing step (non-localized, FR-025).
abstract final class SyncPairingErrorCode {
  /// The QR token is older than 5 minutes or was already used.
  static const String codeExpiredOrUsed = 'pairing_code_expired_or_used';
  static const String codesDiffer = 'pairing_codes_differ';
  static const String cancelled = 'pairing_cancelled';
  static const String unreachable = 'pairing_unreachable';
  static const String invalidInvitation = 'pairing_invalid_invitation';
  static const String groupSwitchDeclined = 'pairing_group_switch_declined';
  static const String preparing = 'pairing_preparing';
  static const String refused = 'pairing_refused';
  static const String noActivePairing = 'pairing_not_active';
}
