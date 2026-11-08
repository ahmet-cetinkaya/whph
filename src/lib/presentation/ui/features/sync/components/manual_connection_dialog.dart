import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:whph/presentation/ui/shared/components/custom_tab_bar.dart';
import 'package:whph/main.dart';

/// Dialog for manual connection to a WHPH server as client
class ManualConnectionDialog extends StatefulWidget {
  final Function(DeviceInfo deviceInfo) onConnect;
  final Future<void> Function(String pairingCode) onPairWithCode;
  final VoidCallback? onCancel;

  const ManualConnectionDialog({
    super.key,
    required this.onConnect,
    required this.onPairWithCode,
    this.onCancel,
  });

  @override
  State<ManualConnectionDialog> createState() => _ManualConnectionDialogState();
}

class _ManualConnectionDialogState extends State<ManualConnectionDialog> with SingleTickerProviderStateMixin {
  static const int _pairingCodeTabIndex = 0;
  static const int _pairingCodeLines = 4;

  final _pairingCodeFormKey = GlobalKey<FormState>();
  final _manualEntryFormKey = GlobalKey<FormState>();
  final _pairingCodeController = TextEditingController();
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
    _pairingCodeController.dispose();
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
            onPressed: _isConnecting ? null : _onConnectPressed,
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
                  label: _translationService.translate(SyncTranslationKeys.pairingCodeTab),
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
                _buildPairingCodeTab(),
                _buildManualEntryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onConnectPressed() {
    if (_selectedTabIndex == _pairingCodeTabIndex) {
      _submitPairingCode();
    } else {
      _attemptConnection();
    }
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

  /// Chat apps wrap long codes, so line breaks and spaces are not part of the code.
  String _withoutWhitespace(String text) => text.replaceAll(RegExp(r'\s'), '');

  String? _validatePairingCode(String? value) {
    final code = _withoutWhitespace(value ?? '');
    if (code.isEmpty) return _translationService.translate(SyncTranslationKeys.pairingCodeRequired);

    try {
      PairingInvitation.decode(code);
    } catch (_) {
      return _translationService.translate(SyncTranslationKeys.invalidPairingCode);
    }
    return null;
  }

  Future<void> _submitPairingCode() async {
    if (!_pairingCodeFormKey.currentState!.validate()) return;

    final pairingCode = _withoutWhitespace(_pairingCodeController.text);
    Navigator.of(context).pop(true);
    await widget.onPairWithCode(pairingCode);
  }

  Widget _buildPairingCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.sizeMedium),
      child: Form(
        key: _pairingCodeFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _translationService.translate(SyncTranslationKeys.pairingCodeInstruction),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.sizeMedium),
            TextFormField(
              controller: _pairingCodeController,
              decoration: InputDecoration(
                labelText: _translationService.translate(SyncTranslationKeys.pairingCodeLabel),
                hintText: _translationService.translate(SyncTranslationKeys.pairingCodeHint),
                prefixIcon: const Icon(Icons.vpn_key),
                border: const OutlineInputBorder(),
              ),
              maxLines: _pairingCodeLines,
              autocorrect: false,
              enableSuggestions: false,
              validator: _validatePairingCode,
            ),
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
            const SizedBox(height: AppTheme.sizeSmall),
            Text(
              _translationService.translate(SyncTranslationKeys.manualEntryQrHint),
              style: Theme.of(context).textTheme.bodySmall,
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
    if (!_manualEntryFormKey.currentState!.validate()) return;

    final ipAddress = _ipController.text.trim();
    final port = int.parse(_portController.text.trim());

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
