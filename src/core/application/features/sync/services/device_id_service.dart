import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:application/shared/utils/key_helper.dart';

class DeviceIdService implements IDeviceIdService {
  static const String deviceIdFileName = 'device_id';
  final IApplicationDirectoryService _applicationDirectoryService;
  String? _cachedDeviceId;

  /// Get the device ID filename with debug prefix if in debug mode
  String get _deviceIdFileName => kDebugMode ? 'debug_$deviceIdFileName' : deviceIdFileName;

  DeviceIdService({
    required IApplicationDirectoryService applicationDirectoryService,
  }) : _applicationDirectoryService = applicationDirectoryService;

  @override
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    final appDirectory = await _applicationDirectoryService.getApplicationDirectory();
    final deviceIdFile = File(p.join(appDirectory.path, _deviceIdFileName));

    if (await deviceIdFile.exists()) {
      _cachedDeviceId = await deviceIdFile.readAsString();
    } else {
      _cachedDeviceId = KeyHelper.generateStringId();
      await deviceIdFile.parent.create(recursive: true);
      await deviceIdFile.writeAsString(_cachedDeviceId!);
    }

    return _cachedDeviceId!;
  }
}
