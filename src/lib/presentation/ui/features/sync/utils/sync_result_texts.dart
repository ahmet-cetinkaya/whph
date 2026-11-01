import 'package:whph/core/application/features/demo/models/demo_reset_blocked_exception.dart';
import 'package:whph/core/application/features/sync/constants/sync_translation_keys.dart' as application;
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Turns the non-localized results of the sync application layer (result
/// categories, pairing error codes, refused operations) into translation keys.
abstract final class SyncResultTexts {
  /// Every [SyncResultCategory] has a text; the switch is exhaustive.
  static String categoryKey(SyncResultCategory category) => switch (category) {
        SyncResultCategory.notReachable => SyncTranslationKeys.syncStatusNotReachable,
        SyncResultCategory.needsRepairing => SyncTranslationKeys.syncStatusNeedsRepairing,
        SyncResultCategory.needsUpdate => SyncTranslationKeys.syncStatusNeedsUpdate,
        SyncResultCategory.thisDeviceNeedsUpdate => SyncTranslationKeys.syncStatusThisDeviceNeedsUpdate,
        SyncResultCategory.someItemsFailed => SyncTranslationKeys.syncStatusItemsFailed,
        SyncResultCategory.rejectedItems => SyncTranslationKeys.syncStatusItemsRejected,
        SyncResultCategory.preparing => SyncTranslationKeys.syncStatusPeerPreparing,
        SyncResultCategory.duplicatedIdentity => SyncTranslationKeys.syncStatusDuplicatedIdentity,
        SyncResultCategory.storageError => SyncTranslationKeys.syncStatusStorageError,
      };

  /// An unknown code falls back to the generic refusal text.
  static String pairingErrorKey(String? errorCode) => switch (errorCode) {
        SyncPairingErrorCode.codeExpiredOrUsed => SyncTranslationKeys.pairingErrorCodeExpiredOrUsed,
        SyncPairingErrorCode.codesDiffer => SyncTranslationKeys.pairingErrorCodesDiffer,
        SyncPairingErrorCode.cancelled => SyncTranslationKeys.pairingErrorCancelled,
        SyncPairingErrorCode.unreachable => SyncTranslationKeys.pairingErrorUnreachable,
        SyncPairingErrorCode.invalidInvitation => SyncTranslationKeys.pairingErrorInvalidInvitation,
        SyncPairingErrorCode.groupSwitchDeclined => SyncTranslationKeys.pairingErrorGroupSwitchDeclined,
        SyncPairingErrorCode.preparing => SyncTranslationKeys.pairingErrorPreparing,
        SyncPairingErrorCode.noActivePairing => SyncTranslationKeys.pairingErrorNotActive,
        _ => SyncTranslationKeys.pairingErrorRefused,
      };

  /// The text of a category; [deviceName] fills the placeholder of "needs update".
  static String categoryText(ITranslationService translationService, SyncResultCategory category, String deviceName) =>
      translationService.translate(categoryKey(category), namedArgs: {'device': deviceName});

  static String pairingErrorText(ITranslationService translationService, String? errorCode) =>
      translationService.translate(pairingErrorKey(errorCode));

  /// The key for a refusal the sync layer throws (U6 demo gate, D17 upgrade
  /// gate), or `null` when [error] is none of them.
  static String? refusalKey(Object error) {
    if (error is DemoResetBlockedException) return SyncTranslationKeys.demoResetBlocked;
    if (error is StateError && error.message.startsWith(_preparingMessagePrefix)) {
      return application.SyncTranslationKeys.syncPreparingError;
    }
    return null;
  }

  /// The change store throws `StateError('preparing: ...')` while the upgrade runs.
  static const String _preparingMessagePrefix = 'preparing';
}
