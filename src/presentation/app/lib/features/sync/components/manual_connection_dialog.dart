import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:application/features/sync/services/device_handshake_service.dart';
import 'package:whph/features/sync/models/sync_connection_string.dart';
import 'package:whph/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/utils/overlay_notification_helper.dart';
import 'package:whph/shared/components/custom_tab_bar.dart';
import 'package:whph/main.dart';

/// Dialog for manual connection to a WHPH server as client
class ManualConnectionDialog extends StatefulWidget {
  final Function(DeviceInfo deviceInfo) onConnect;
  final VoidCallback? onCancel;

  const ManualConnectionDialog({
    super.key,
    required this.onConnect,
    this.onCancel,
  });

  @override
  State<ManualConnectionDialog> createState() => _ManualConnectionDialogState();
}

class _ManualConnectionDialogState extends State<ManualConnectionDialog> with SingleTickerProviderStateMixin {
  final _connectionStringFormKey = GlobalKey<FormState>();
  final _manualEntryFormKey = GlobalKey<FormState>();
  final _connectionStringController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '44040');

  bool _isCancelled = false;

  final _translationService = container.resolve<ITranslationService>();
  final _handshakeService = container.resolve<DeviceHandshakeService>();

  late TabController _tabController;
  int _selectedTabIndex = 0;

  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _connectionStringController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_translationService.translate(SyncTranslationKeys.manualConnection)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isConnecting) {
              setState(() {
                _isCancelled = true;
                _isConnecting = false;
                _errorMessage = null;
              });
            }
            widget.onCancel?.call();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: _isConnecting ? null : _attemptConnection,
            child: _isConnecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _translationService.translate(SyncTranslationKeys.connect),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.sizeMedium),
            child: CustomTabBar(
              items: [
                CustomTabItem(
                  icon: Icons.link,
                  label: _translationService.translate(SyncTranslationKeys.connectionStringTab),
                ),
                CustomTabItem(
                  icon: Icons.settings_input_antenna,
                  label: _translationService.translate(SyncTranslationKeys.manualEntryTab),
                ),
              ],
              selectedIndex: _selectedTabIndex,
              onTap: (index) {
                setState(() {
                  _selectedTabIndex = index;
                  _tabController.animateTo(index);
                });
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConnectionStringTab(),
                _buildManualEntryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _validateIPAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _translationService.translate(SyncTranslationKeys.ipAddressRequired);
    }

    final ip = value.trim();
    final parts = ip.split('.');

    if (parts.length != 4) {
      return _translationService.translate(SyncTranslationKeys.invalidIPFormat);
    }

    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return _translationService.translate(SyncTranslationKeys.invalidIPFormat);
      }
    }

    return null;
  }

  String? _validatePort(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _translationService.translate(SyncTranslationKeys.portRequired);
    }

    final port = int.tryParse(value.trim());
    if (port == null || port < 1 || port > 65535) {
      return _translationService.translate(SyncTranslationKeys.invalidPort);
    }

    return null;
  }

  String? _validateConnectionString(String? value) {
    if (value == null || value.isEmpty) {
      return _translationService.translate(SyncTranslationKeys.connectionStringRequired);
    }

    final connectionString = SyncConnectionString.fromString(value);
    if (connectionString == null || !connectionString.isValid) {
      return _translationService.translate(SyncTranslationKeys.invalidConnectionString);
    }

    return null;
  }

  void _parseConnectionString(String value) {
    if (value.isEmpty) return;

    final connectionString = SyncConnectionString.fromString(value);
    if (connectionString != null && connectionString.isValid) {
      // Parse IP and port from connection string and populate fields
      setState(() {
        _ipController.text = connectionString.ipAddress;
        _portController.text = connectionString.port.toString();
      });
    }
  }

  Widget _buildConnectionStringTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.sizeMedium),
      child: Form(
        key: _connectionStringFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _translationService.translate(SyncTranslationKeys.manualConnectionStringInstruction),
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: AppTheme.sizeMedium),

            TextFormField(
              controller: _connectionStringController,
              decoration: InputDecoration(
                labelText: _translationService.translate(SyncTranslationKeys.connectionStringLabel),
                hintText: 'whph://192.168.1.100:44040?name=Server&id=uuid',
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: _validateConnectionString,
              onChanged: _parseConnectionString,
              enabled: !_isConnecting,
            ),

            const SizedBox(height: AppTheme.sizeMedium),

            // Test Connection Button
            ElevatedButton.icon(
              onPressed: _isConnecting ? null : _testConnectionString,
              icon: const Icon(Icons.wifi_find, size: 16),
              label: Text(_translationService.translate(SyncTranslationKeys.testConnection)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              ),
            ),

            const SizedBox(height: AppTheme.sizeSmall),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.sizeSmall),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.sizeSmall),
            ],

            if (_isConnecting) ...[
              const SizedBox(height: AppTheme.sizeMedium),
              const LinearProgressIndicator(),
              const SizedBox(height: AppTheme.sizeSmall),
              Text(
                _translationService.translate(SyncTranslationKeys.connectingToDevice),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManualEntryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.sizeMedium),
      child: Form(
        key: _manualEntryFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _translationService.translate(SyncTranslationKeys.enterServerDetails),
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: AppTheme.sizeMedium),

            // IP Address Input
            TextFormField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: _translationService.translate(SyncTranslationKeys.ipAddress),
                hintText: '192.168.1.100',
                prefixIcon: const Icon(Icons.computer),
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: _validateIPAddress,
              enabled: !_isConnecting,
            ),
            const SizedBox(height: AppTheme.sizeMedium),

            // Port Input
            TextFormField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: _translationService.translate(SyncTranslationKeys.port),
                hintText: '44040',
                prefixIcon: const Icon(Icons.settings_ethernet),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: _validatePort,
              enabled: !_isConnecting,
            ),
            const SizedBox(height: AppTheme.sizeMedium),

            // Test Connection Button
            ElevatedButton.icon(
              onPressed: _isConnecting ? null : _testManualConnection,
              icon: const Icon(Icons.wifi_find, size: 16),
              label: Text(_translationService.translate(SyncTranslationKeys.testConnection)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              ),
            ),

            const SizedBox(height: AppTheme.sizeSmall),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.sizeSmall),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.sizeSmall),
            ],

            if (_isConnecting) ...[
              const SizedBox(height: AppTheme.sizeMedium),
              const LinearProgressIndicator(),
              const SizedBox(height: AppTheme.sizeSmall),
              Text(
                _translationService.translate(SyncTranslationKeys.connectingToDevice),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _attemptConnection() async {
    String ipAddress;
    int port;

    // Validate based on the active tab
    if (_tabController.index == 0) {
      // Connection string tab
      if (!_connectionStringFormKey.currentState!.validate()) return;

      final connectionString = SyncConnectionString.fromString(_connectionStringController.text);
      if (connectionString == null) return;

      ipAddress = connectionString.ipAddress;
      port = connectionString.port;
    } else {
      // Manual entry tab
      if (!_manualEntryFormKey.currentState!.validate()) {
        return;
      }

      ipAddress = _ipController.text.trim();
      port = int.parse(_portController.text.trim());
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
      _isCancelled = false;
    });

    try {
      // Test connection with timeout and cancellation check
      final deviceInfo = await _handshakeService.getDeviceInfo(ipAddress, port).timeout(const Duration(seconds: 10));

      // Check if operation was cancelled
      if (_isCancelled || !mounted) {
        return;
      }

      if (deviceInfo == null) {
        if (mounted) {
          setState(() {
            _errorMessage = _translationService.translate(SyncTranslationKeys.connectionFailed);
            _isConnecting = false;
          });
        }
        return;
      }

      // Connection successful, call onConnect callback with device info
      widget.onConnect(deviceInfo);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (_isCancelled || !mounted) {
        return;
      }

      if (mounted) {
        setState(() {
          if (e is TimeoutException) {
            _errorMessage = _translationService.translate(SyncTranslationKeys.connectionTimeout);
          } else {
            _errorMessage =
                _translationService.translate(SyncTranslationKeys.connectionError, namedArgs: {'0': e.toString()});
          }
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _testConnectionString() async {
    if (!_connectionStringFormKey.currentState!.validate()) return;

    final connectionString = SyncConnectionString.fromString(_connectionStringController.text);
    if (connectionString == null) return;

    await _testConnection(connectionString.ipAddress, connectionString.port);
  }

  Future<void> _testManualConnection() async {
    if (_validateIPAddress(_ipController.text) != null || _validatePort(_portController.text) != null) {
      return;
    }

    final ipAddress = _ipController.text.trim();
    final port = int.parse(_portController.text.trim());

    await _testConnection(ipAddress, port);
  }

  Future<void> _testConnection(String ipAddress, int port) async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
      _isCancelled = false;
    });

    try {
      final deviceInfo = await _handshakeService.getDeviceInfo(ipAddress, port).timeout(const Duration(seconds: 10));

      // Check if operation was cancelled
      if (_isCancelled || !mounted) {
        return;
      }

      if (deviceInfo == null) {
        if (mounted) {
          setState(() {
            _errorMessage = _translationService.translate(SyncTranslationKeys.connectionTestFailedNoResponse);
            _isConnecting = false;
          });
        }
        return;
      }

      // Show success message temporarily
      if (mounted) {
        setState(() {
          _errorMessage = null;
          _isConnecting = false;
        });

        // Show success notification
        OverlayNotificationHelper.showSuccess(
          context: context,
          message: _translationService.translate(SyncTranslationKeys.connectionTestSuccessful),
        );
      }
    } catch (e) {
      if (_isCancelled || !mounted) {
        return;
      }

      if (mounted) {
        setState(() {
          if (e is TimeoutException) {
            _errorMessage = _translationService.translate(SyncTranslationKeys.connectionTestTimeout);
          } else {
            _errorMessage = _translationService
                .translate(SyncTranslationKeys.connectionTestFailedGeneric, namedArgs: {'0': e.toString()});
          }
          _isConnecting = false;
        });
      }
    }
  }
}
