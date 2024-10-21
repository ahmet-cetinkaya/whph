import 'dart:io';

class NetworkUtils {
  static const String _localIPPrefix = '192.168.';
  static const String _unknownIP = 'unknown';

  static Future<String?> getLocalIpAddress() async {
    List<NetworkInterface> interfaces = await NetworkInterface.list();
    for (var interface in interfaces.where((interface) => interface.addresses.isNotEmpty)) {
      var localIPAddress = interface.addresses.where((addr) => addr.address.startsWith(_localIPPrefix));
      if (localIPAddress.isEmpty) continue;

      return localIPAddress.first.address;
    }
    return null;
  }
}
