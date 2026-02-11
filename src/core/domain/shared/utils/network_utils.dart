import 'dart:io';
import 'package:domain/shared/utils/logger.dart';

class NetworkUtils {
  /// Check if an IP is from a private network
  static bool isPrivateIP(String ip) {
    try {
      final address = InternetAddress(ip);

      if (address.type == InternetAddressType.IPv4) {
        final parts = ip.split('.');
        if (parts.length != 4) return false;

        final first = int.tryParse(parts[0]);
        final second = int.tryParse(parts[1]);
        if (first == null || second == null) return false;

        return (first == 10) ||
            (first == 172 && second >= 16 && second <= 31) ||
            (first == 192 && second == 168) ||
            (first == 127);
      }

      if (address.type == InternetAddressType.IPv6) {
        return ip.startsWith('fe80:') || ip == '::1' || ip.startsWith('fc') || ip.startsWith('fd');
      }
    } catch (e) {
      DomainLogger.debug('Error parsing IP address $ip: $e');
      return false;
    }
    return false;
  }
}
