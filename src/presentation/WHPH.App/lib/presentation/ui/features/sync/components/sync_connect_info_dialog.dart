import 'dart:io';
import 'package:flutter/services.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/utils/network_utils.dart';
import 'package:whph/presentation/ui/features/sync/models/sync_qr_code_message.dart';
import 'package:whph/presentation/ui/features/sync/models/sync_connection_string.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:whph/presentation/api/api.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/presentation/ui/shared/components/custom_tab_bar.dart';

/// Dialog for displaying sync connection information (QR code and connection string)
class SyncConnectInfoDialog extends StatefulWidget {
  const SyncConnectInfoDialog({super.key});

  /// Static method to show the dialog from anywhere
  static Future<void> show(BuildContext context) async {
    await ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.large,
      child: const SyncConnectInfoDialog(),
    );
  }

  @override
  State<SyncConnectInfoDialog> createState() => _SyncConnectInfoDialogState();
}

class _SyncConnectInfoDialogState extends State<SyncConnectInfoDialog> {
  final _translationService = container.resolve<ITranslationService>();
  final _deviceIdService = container.resolve<IDeviceIdService>();

  String? _ipAddress;
  List<String> _ipAddresses = const [];
  String? _deviceName;
  String? _deviceId;
  String? _platform;
  String? _qrData;
  String? _connectionString;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConnectionInfo();
  }

  Future<void> _loadConnectionInfo() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get device information
      _ipAddresses = await NetworkUtils.getLocalIpAddresses();
      _ipAddress = _ipAddresses.isNotEmpty ? _ipAddresses.first : null;
      _deviceName = await DeviceInfoHelper.getDeviceName();
      _deviceId = await _deviceIdService.getDeviceId();

      // Determine platform
      if (Platform.isAndroid) {
        _platform = 'android';
      } else if (Platform.isIOS) {
        _platform = 'ios';
      } else if (PlatformUtils.isDesktop) {
        _platform = 'desktop';
      } else {
        _platform = 'unknown';
      }

      // Create QR code data
      final syncQrCodeMessage = SyncQrCodeMessage(
        localIP: _ipAddress ?? _translationService.translate(SyncTranslationKeys.unknownIp),
        deviceName: _deviceName!,
        deviceId: _deviceId!,
        platform: _platform!,
        ipAddresses: _ipAddresses.isEmpty ? null : _ipAddresses,
      );

      Logger.debug('Sync QR Code Message: ${syncQrCodeMessage.toCsv()}');
      _qrData = syncQrCodeMessage.toCsv();

      // Create connection string
      if (_ipAddress != null) {
        final syncConnectionString = SyncConnectionString(
          deviceId: _deviceId!,
          deviceName: _deviceName!,
          ipAddress: _ipAddress!,
          port: webSocketPort,
        );
        _connectionString = syncConnectionString.toConnectionString();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_translationService.translate(SyncTranslationKeys.connectInfoDialogTitle)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 48,
                      ),
                      const SizedBox(height: AppTheme.sizeMedium),
                      Text(
                        _translationService.translate(SyncTranslationKeys.errorLoadingConnectionInfo),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppTheme.sizeSmall),
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTheme.sizeMedium),
                      TextButton.icon(
                        onPressed: _loadConnectionInfo,
                        icon: const Icon(Icons.refresh),
                        label: Text(_translationService.translate(SyncTranslationKeys.retry)),
                      ),
                    ],
                  ),
                )
              : _ConnectInfoTabs(
                  qrData: _qrData!,
                  connectionString: _connectionString,
                  ipAddress: _ipAddress!,
                  port: webSocketPort,
                ),
    );
  }
}

class _ConnectInfoTabs extends StatefulWidget {
  final String qrData;
  final String? connectionString;
  final String ipAddress;
  final int port;

  const _ConnectInfoTabs({
    required this.qrData,
    required this.connectionString,
    required this.ipAddress,
    required this.port,
  });

  @override
  State<_ConnectInfoTabs> createState() => _ConnectInfoTabsState();
}

class _ConnectInfoTabsState extends State<_ConnectInfoTabs> {
  late PageController _pageController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.sizeMedium),
          child: CustomTabBar(
            items: [
              CustomTabItem(
                icon: Icons.qr_code,
                label: translationService.translate(SyncTranslationKeys.connectInfoQrTitle),
              ),
              CustomTabItem(
                icon: Icons.link,
                label: translationService.translate(SyncTranslationKeys.manualConnectionTab),
              ),
            ],
            selectedIndex: _selectedIndex,
            onTap: _onTabSelected,
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: [
              // QR Code Tab Content
              _QrCodeTabContent(qrData: widget.qrData),

              // Connection String Tab Content
              _ConnectionStringTabContent(
                connectionString: widget.connectionString,
                ipAddress: widget.ipAddress,
                port: widget.port,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QrCodeTabContent extends StatelessWidget {
  final String qrData;

  const _QrCodeTabContent({required this.qrData});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.sizeMedium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // QR Code Description
          Text(
            translationService.translate(SyncTranslationKeys.connectInfoQrDescription),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.sizeMedium),

          // QR Code
          SizedBox(
            width: 200.0,
            height: 200.0,
            child: Center(
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppTheme.textColor,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: AppTheme.textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionStringTabContent extends StatelessWidget {
  final String? connectionString;
  final String ipAddress;
  final int port;

  const _ConnectionStringTabContent({
    required this.connectionString,
    required this.ipAddress,
    required this.port,
  });

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    if (connectionString == null) {
      return Center(
        child: Text(
          translationService.translate(SyncTranslationKeys.connectionStringDescription),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.sizeMedium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Server Information Section
          Center(
            child: Text(
              translationService.translate(SyncTranslationKeys.serverDetailsTitle),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppTheme.sizeSmall),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium),
            child: Text(
              translationService.translate(SyncTranslationKeys.connectInfoServerDetailsDescription),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppTheme.sizeMedium),
          Container(
            padding: const EdgeInsets.all(AppTheme.sizeMedium),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.public,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppTheme.sizeSmall),
                    Expanded(
                      child: Text(
                        'IP Address: $ipAddress',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.sizeSmall),
                Row(
                  children: [
                    Icon(
                      Icons.network_check,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppTheme.sizeSmall),
                    Expanded(
                      child: Text(
                        'Port: $port',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.sizeMedium),
          Center(
            child: Text(
              translationService.translate(SyncTranslationKeys.connectionStringTitleAlt),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppTheme.sizeSmall),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium),
            child: Text(
              translationService.translate(SyncTranslationKeys.connectInfoConnectionStringDescription),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppTheme.sizeMedium),
          Container(
            padding: const EdgeInsets.all(AppTheme.sizeMedium),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        connectionString!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.sizeSmall),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(translationService.translate(SyncTranslationKeys.copy)),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: connectionString!));
                      if (context.mounted) {
                        OverlayNotificationHelper.showSuccess(
                          context: context,
                          message: translationService.translate(SyncTranslationKeys.connectInfoConnectionStringCopied),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
