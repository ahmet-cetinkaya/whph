import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_concurrent_connection_service.dart';
import 'package:whph/core/application/features/sync/commands/save_sync_command.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/utils/network_utils.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:acore/acore.dart' show BusinessException;

/// Dialog for manual IP address entry as a fallback for automatic discovery
class ManualIPInputDialog extends StatefulWidget {
  final VoidCallback? onSyncDeviceAdded;
  final IConcurrentConnectionService? connectionService;
  final String? initialIP;
  final String? initialPort;
  final String? initialDeviceName;
  final String? preDiscoveredDeviceId;

  const ManualIPInputDialog({
    super.key,
    this.onSyncDeviceAdded,
    this.connectionService,
    this.initialIP,
    this.initialPort,
    this.initialDeviceName,
    this.preDiscoveredDeviceId,
  });

  @override
  State<ManualIPInputDialog> createState() => _ManualIPInputDialogState();
}

class _ManualIPInputDialogState extends State<ManualIPInputDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '44040');
  final _deviceNameController = TextEditingController();
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill controllers with initial values if provided
    if (widget.initialIP != null) {
      _ipController.text = widget.initialIP!;
    }
    if (widget.initialPort != null) {
      _portController.text = widget.initialPort!;
    }
    if (widget.initialDeviceName != null) {
      _deviceNameController.text = widget.initialDeviceName!;
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _translationService.translate(SyncTranslationKeys.manualConnection),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _translationService.translate(SyncTranslationKeys.manualConnectionDescription),
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
              
              // Device Name Input (Optional)
              TextFormField(
                controller: _deviceNameController,
                decoration: InputDecoration(
                  labelText: _translationService.translate(SyncTranslationKeys.deviceName),
                  hintText: _translationService.translate(SyncTranslationKeys.optional),
                  prefixIcon: const Icon(Icons.device_hub),
                  border: const OutlineInputBorder(),
                ),
                enabled: !_isConnecting,
              ),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: AppTheme.sizeSmall),
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
      ),
      actions: [
        TextButton(
          onPressed: _isConnecting ? null : () => Navigator.of(context).pop(),
          child: Text(_translationService.translate(SyncTranslationKeys.cancel)),
        ),
        ElevatedButton(
          onPressed: _isConnecting ? null : _attemptConnection,
          child: _isConnecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_translationService.translate(SyncTranslationKeys.connect)),
        ),
      ],
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

  Future<void> _attemptConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });
    
    try {
      final ipAddress = _ipController.text.trim();
      final port = int.parse(_portController.text.trim());
      final deviceName = _deviceNameController.text.trim().isNotEmpty 
          ? _deviceNameController.text.trim() 
          : 'Manual Device';
      
      // First test connection if service is available
      if (widget.connectionService != null) {
        final isReachable = await widget.connectionService!.testWebSocketConnection(
          ipAddress, 
          port, 
          timeout: const Duration(seconds: 5),
        );
        
        if (!isReachable) {
          setState(() {
            _errorMessage = _translationService.translate(SyncTranslationKeys.connectionFailed);
            _isConnecting = false;
          });
          return;
        }
      }
      
      // If connection test passes, create and save the sync device
      await _createSyncDevice(ipAddress, port, deviceName);
      
    } catch (e) {
      setState(() {
        _errorMessage = _translationService.translate(SyncTranslationKeys.connectionError, namedArgs: {'0': e.toString()});
        _isConnecting = false;
      });
    }
  }

  Future<void> _createSyncDevice(String ipAddress, int port, String deviceName) async {
    final mediator = container.resolve<Mediator>();
    final deviceIdService = container.resolve<IDeviceIdService>();
    
    await AsyncErrorHandler.execute<void>(
      context: context,
      errorMessage: _translationService.translate(SyncTranslationKeys.saveDeviceError),
      operation: () async {
        // Get local device information
        final localIp = await NetworkUtils.getLocalIpAddress();
        if (localIp == null) {
          throw BusinessException(
            _translationService.translate(SyncTranslationKeys.localIpError),
            SyncTranslationKeys.ipAddressError,
          );
        }

        final localDeviceId = await deviceIdService.getDeviceId();
        final localDeviceName = await DeviceInfoHelper.getDeviceName();
        
        // Use pre-discovered device ID if available, otherwise generate one
        final remoteDeviceId = widget.preDiscoveredDeviceId ?? 'manual-$ipAddress:$port';
        
        // Check if device already exists
        final existingDevice = await mediator.send<GetSyncDeviceQuery, GetSyncDeviceQueryResponse?>(
          GetSyncDeviceQuery(fromDeviceId: remoteDeviceId, toDeviceId: localDeviceId)
        );

        if (existingDevice?.id.isNotEmpty == true && existingDevice?.deletedDate == null) {
          throw BusinessException(
            _translationService.translate(SyncTranslationKeys.deviceAlreadyPairedError),
            SyncTranslationKeys.deviceAlreadyPaired,
          );
        }

        // Create the sync device
        // For manual connections, treat the remote device as server and local as client
        final saveCommand = SaveSyncDeviceCommand(
          fromIP: ipAddress, // Remote device IP (server)
          toIP: localIp,     // Local device IP (client)
          fromDeviceId: remoteDeviceId,
          toDeviceId: localDeviceId,
          name: "$deviceName ↔ $localDeviceName",
        );

        await mediator.send<SaveSyncDeviceCommand, SaveSyncDeviceCommandResponse>(saveCommand);
        
        return;
      },
      onSuccess: (_) async {
        if (mounted) {
          // Show success message
          OverlayNotificationHelper.showSuccess(
            context: context,
            message: _translationService.translate(
              SyncTranslationKeys.deviceAddedSuccess,
              namedArgs: {'deviceName': deviceName},
            ),
            duration: const Duration(seconds: 3),
          );
          
          // Close dialog
          Navigator.of(context).pop(true); // Return true to indicate success
          
          // Notify parent to refresh
          widget.onSyncDeviceAdded?.call();
        }
      },
    );
  }
}