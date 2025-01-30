import 'dart:io';
import 'package:nanoid2/nanoid2.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whph/application/features/sync/services/abstraction/i_device_id_service.dart';

class DeviceIdService implements IDeviceIdService {
  static const String deviceIdFileName = 'device_id';
  String? _cachedDeviceId;

  @override
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    final dbFolder = await getApplicationDocumentsDirectory();
    final deviceIdFile = File(p.join(dbFolder.path, 'whph', deviceIdFileName));

    if (await deviceIdFile.exists()) {
      _cachedDeviceId = await deviceIdFile.readAsString();
    } else {
      _cachedDeviceId = nanoid();
      await deviceIdFile.parent.create(recursive: true);
      await deviceIdFile.writeAsString(_cachedDeviceId!);
    }

    return _cachedDeviceId!;
  }
}
