import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkUtils {
  static Future<String?> getLocalIpAddress() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile devices için NetworkInfo Plus kullan
        final info = NetworkInfo();
        String? wifiIP = await info.getWifiIP();
        return wifiIP;
      } else {
        // Desktop için NetworkInterface kullan
        final interfaces = await NetworkInterface.list(
          includeLinkLocal: false,
          type: InternetAddressType.IPv4,
        );

        // Önce en muhtemel interface'leri kontrol et
        for (var interface in interfaces) {
          if (interface.name.toLowerCase().contains('wlan') ||
              interface.name.toLowerCase().contains('wi-fi') ||
              interface.name.toLowerCase().contains('eth')) {
            for (var addr in interface.addresses) {
              // Yerel ağ IP'lerini kontrol et (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
              if (_isValidLocalNetworkIP(addr.address)) {
                print('DEBUG: Found local IP: ${addr.address} on interface: ${interface.name}');
                return addr.address;
              }
            }
          }
        }

        // Eğer bulunamazsa tüm interface'leri kontrol et
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (_isValidLocalNetworkIP(addr.address)) {
              print('DEBUG: Found fallback IP: ${addr.address} on interface: ${interface.name}');
              return addr.address;
            }
          }
        }
      }
    } catch (e) {
      print('ERROR: Failed to get local IP: $e');
    }
    return null;
  }

  static bool _isValidLocalNetworkIP(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    // 192.168.x.x
    if (parts[0] == '192' && parts[1] == '168') return true;

    // 10.x.x.x
    if (parts[0] == '10') return true;

    // 172.16-31.x.x
    if (parts[0] == '172') {
      int second = int.tryParse(parts[1]) ?? 0;
      if (second >= 16 && second <= 31) return true;
    }

    return false;
  }

  static Future<bool> testWebSocketConnection(String host, {Duration? timeout}) async {
    try {
      final socket = await Socket.connect(host, 4040, timeout: timeout).catchError((e) {
        print('WebSocket connection test failed: $e');
        return null;
      });

      if (socket != null) {
        await socket.close();
        return true;
      }
    } catch (e) {
      print('WebSocket connection test failed: $e');
    }
    return false;
  }
}
