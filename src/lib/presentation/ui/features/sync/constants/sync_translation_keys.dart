import 'package:whph/core/application/features/sync/constants/sync_translation_keys.dart' as application;

class SyncTranslationKeys extends application.SyncTranslationKeys {
  // Messages
  static const String testingConnection = 'sync.messages.testing_connection';
  static const String syncInProgress = 'sync.messages.sync_in_progress';
  static const String syncCompleted = 'sync.messages.sync_completed';
  static const String deviceAlreadyPaired = 'sync.messages.device_already_paired';
  static const String deviceAddedSuccess = 'sync.messages.device_added_success';

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
  static const String localIpError = 'sync.errors.local_ip_error';
  static const String deviceAlreadyPairedError = 'sync.errors.device_already_paired';

  // QR Code Dialog
  static const String qrDialogTitle = 'sync.qr_code.dialog_title';
  static const String qrDialogCloseButton = 'sync.qr_code.close_button';
  static const String qrCodeTitle = 'sync.qr_code.title';
  static const String qrCodeDescription = 'sync.qr_code.description';
  static const String connectionStringTitle = 'sync.qr_code.connection_string_title';
  static const String connectionStringDescription = 'sync.qr_code.connection_string_description';
  static const String connectionStringCopied = 'sync.qr_code.connection_string_copied';
  
  // Connect Info Dialog
  static const String connectInfoDialogTitle = 'sync.connect_info.dialog_title';
  static const String connectInfoMenuTitle = 'sync.connect_info.menu_title';
  static const String connectInfoQrTitle = 'sync.connect_info.qr_title';
  static const String connectInfoQrDescription = 'sync.connect_info.qr_description';
  static const String connectInfoConnectionStringTitle = 'sync.connect_info.connection_string_title';
  static const String connectInfoConnectionStringDescription = 'sync.connect_info.connection_string_description';
  static const String connectInfoConnectionStringCopied = 'sync.connect_info.connection_string_copied';

  // QR Scanner
  static const String scannerTitle = 'sync.scanner.title';
  static const String scannerInstruction = 'sync.scanner.instruction';

  // Mobile Server Mode
  static const String serverModeStarting = 'sync.server.starting';
  static const String serverModeActive = 'sync.server.active';
  static const String serverModeStopped = 'sync.server.stopped';
  static const String serverModeStartFailed = 'sync.server.start_failed';
  static const String serverModeStartTooltip = 'sync.server.start_tooltip';
  static const String serverModeStopTooltip = 'sync.server.stop_tooltip';
  static const String serverModeStartMenu = 'sync.server.start_menu';
  static const String serverModeStopMenu = 'sync.server.stop_menu';
  static const String serverModeError = 'sync.server.error';
  static const String deviceBecameServer = 'sync.server.device_became_server';

  // Sync Devices Page
  static const String pageTitle = 'sync.devices.title';
  static const String syncTooltip = 'sync.devices.sync_tooltip';
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

  // Manual IP Entry Dialog
  static const String manualConnection = 'sync.manual.connection';
  static const String ipAddress = 'sync.manual.ip_address';
  static const String port = 'sync.manual.port';
  static const String deviceName = 'sync.manual.device_name';
  static const String optional = 'sync.manual.optional';
  static const String connectingToDevice = 'sync.manual.connecting';
  static const String cancel = 'sync.manual.cancel';
  static const String connect = 'sync.manual.connect';
  static const String ipAddressRequired = 'sync.manual.ip_required';
  static const String invalidIPFormat = 'sync.manual.invalid_ip';
  static const String portRequired = 'sync.manual.port_required';
  static const String invalidPort = 'sync.manual.invalid_port';
  static const String connectionFailed = 'sync.manual.connection_failed';
  static const String connectionError = 'sync.manual.connection_error';

  // Add Device Menu
  static const String addDevice = 'sync.add.device';
  static const String addDeviceTooltip = 'sync.add.device_tooltip';
  static const String addSyncDevice = 'sync.add.sync_device';
  static const String addSyncDeviceTitle = 'sync.add.sync_device_title';
  static const String addSyncDeviceDescription = 'sync.add.sync_device_description';
  static const String scanningForDevices = 'sync.add.scanning_for_devices';
  static const String noNearbyDevices = 'sync.add.no_nearby_devices';
  static const String noNearbyDevicesHint = 'sync.add.no_nearby_devices_hint';
  static const String alternativeMethodsHint = 'sync.add.alternative_methods_hint';
  static const String scanQRCode = 'sync.add.scan_qr_code';
  static const String refreshScan = 'sync.add.refresh_scan';
  static const String lastSeen = 'sync.add.last_seen';
  static const String alreadyAdded = 'sync.add.already_added';

  // Desktop Sync Mode
  static const String desktopSyncMode = 'sync.desktop.mode_title';
  static const String desktopClientModeStart = 'sync.desktop.client_mode_start';
  static const String desktopClientModeStop = 'sync.desktop.client_mode_stop';
  static const String desktopClientModeDescription = 'sync.desktop.client_mode_description';
  static const String desktopServerModeDescription = 'sync.desktop.server_mode_description';
  static const String desktopSyncModeStart = 'sync.desktop.sync_mode_start';
  static const String desktopSyncModeStop = 'sync.desktop.sync_mode_stop';
  static const String desktopSyncModeStartMenu = 'sync.desktop.sync_mode_start_menu';
  static const String desktopSyncModeStopMenu = 'sync.desktop.sync_mode_stop_menu';
  static const String desktopClientModeStarting = 'sync.desktop.client_mode_starting';
  static const String desktopClientModeStarted = 'sync.desktop.client_mode_started';
  static const String desktopClientModeStopped = 'sync.desktop.client_mode_stopped';

  // Error Messages
  static const String noActiveInterfacesError = 'sync.errors.no_active_interfaces';
  static const String deviceDiscoveryFailedError = 'sync.errors.device_discovery_failed';
}
