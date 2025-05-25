import 'package:whph/application/features/sync/constants/sync_translation_keys.dart' as application;

class SyncTranslationKeys extends application.SyncTranslationKeys {
  // Messages
  static const String testingConnection = 'sync.messages.testing_connection';
  static const String syncInProgress = 'sync.messages.sync_in_progress';
  static const String syncCompleted = 'sync.messages.sync_completed';
  static const String deviceAlreadyPaired = 'sync.messages.device_already_paired';

  // Errors
  static const String scanError = 'sync.error.scan';
  static const String parseError = 'sync.errors.parse_message';
  static const String ipAddressError = 'sync.errors.ip_address';
  static const String connectionFailedError = 'sync.errors.connection_failed';
  static const String saveDeviceError = 'sync.errors.save_device';
  static const String syncError = 'sync.errors.sync_failed';
  static const String syncTimeoutError = 'sync.errors.sync_timeout';
  static const String syncDeviceNotFoundError = 'sync.errors.device_not_found';
  static const String versionMismatchError = 'sync.errors.version_mismatch';
  static const String deviceMismatchError = 'sync.errors.device_mismatch';

  // QR Code Dialog
  static const String qrDialogTitle = 'sync.qr_code.dialog_title';
  static const String qrDialogCloseButton = 'sync.qr_code.close_button';

  // QR Scanner
  static const String scannerTitle = 'sync.scanner.title';
  static const String scannerHelpTitle = 'sync.scanner.help.title';
  static const String scannerHelpContent = 'sync.scanner.help.content';
  static const String scannerHelpIntro = 'sync.scanner.help.intro';
  static const String scannerHelpTipsTitle = 'sync.scanner.help.tips_title';
  static const String scannerHelpProcessTitle = 'sync.scanner.help.process_title';

  // Sync Devices Page
  static const String pageTitle = 'sync.devices.title';
  static const String noDevicesFound = 'sync.devices.no_devices_found';
  static const String loadDevicesError = 'sync.devices.errors.loading';
  static const String removeDeviceError = 'sync.devices.errors.removing';
  static const String syncDevicesError = 'sync.devices.errors.sync_failed';
  static const String unnamedDevice = 'sync.devices.unnamed_device';
  static const String fromLabel = 'sync.devices.from_label';
  static const String toLabel = 'sync.devices.to_label';
  static const String lastSyncLabel = 'sync.devices.last_sync_label';
  static const String helpTitle = 'sync.devices.help.title';
  static const String helpContent = 'sync.devices.help.content';
}
