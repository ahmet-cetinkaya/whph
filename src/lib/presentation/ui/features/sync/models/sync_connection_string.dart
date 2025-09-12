import 'dart:convert';

/// Model for WHPH sync connection strings
/// Supports format: whph://192.168.1.100:44040?name=Desktop-Server&id=uuid&token=access-token
class SyncConnectionString {
  final String deviceId;
  final String deviceName;
  final String ipAddress;
  final int port;
  final String? accessToken;
  final Map<String, String>? additionalParams;

  const SyncConnectionString({
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    required this.port,
    this.accessToken,
    this.additionalParams,
  });

  /// Parse connection string into SyncConnectionString object
  /// Format: whph://192.168.1.100:44040?name=Desktop-Server&id=uuid&token=access-token
  static SyncConnectionString? fromString(String connectionString) {
    try {
      // Validate and parse the URI
      final uri = Uri.parse(connectionString);
      
      if (uri.scheme != 'whph') {
        return null;
      }

      if (uri.host.isEmpty) {
        return null;
      }

      final port = uri.port != 0 ? uri.port : 44040; // Default port
      final queryParams = uri.queryParameters;

      final deviceName = queryParams['name'];
      final deviceId = queryParams['id'];
      
      if (deviceName == null || deviceId == null) {
        return null;
      }

      final accessToken = queryParams['token'];
      
      // Extract additional parameters (excluding known ones)
      final additionalParams = Map<String, String>.from(queryParams);
      additionalParams.removeWhere((key, value) => 
          ['name', 'id', 'token'].contains(key));

      return SyncConnectionString(
        deviceId: deviceId,
        deviceName: deviceName,
        ipAddress: uri.host,
        port: port,
        accessToken: accessToken,
        additionalParams: additionalParams.isNotEmpty ? additionalParams : null,
      );
    } catch (e) {
      return null;
    }
  }

  /// Generate connection string for sharing
  /// Returns format: whph://192.168.1.100:44040?name=Desktop-Server&id=uuid&token=access-token
  String toConnectionString() {
    final queryParams = <String, String>{
      'name': deviceName,
      'id': deviceId,
    };

    if (accessToken != null) {
      queryParams['token'] = accessToken!;
    }

    // Add any additional parameters
    if (additionalParams != null) {
      queryParams.addAll(additionalParams!);
    }

    final uri = Uri(
      scheme: 'whph',
      host: ipAddress,
      port: port,
      queryParameters: queryParams,
    );

    return uri.toString();
  }

  /// Generate QR code data (same as connection string)
  String toQRCodeData() => toConnectionString();

  /// Generate a user-friendly display text for the connection
  String get displayText {
    return '$deviceName ($ipAddress:$port)';
  }

  /// Generate QR code JSON data (alternative format for QR codes)
  String toQRCodeJson() {
    final data = {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'ipAddress': ipAddress,
      'port': port,
      'protocol': 'whph-sync',
      'version': '1.0',
    };

    if (accessToken != null) {
      data['accessToken'] = accessToken!;
    }

    if (additionalParams != null) {
      data.addAll(additionalParams!);
    }

    return jsonEncode(data);
  }

  /// Create from QR code JSON data
  static SyncConnectionString? fromQRCodeJson(String jsonData) {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      
      final deviceId = data['deviceId'] as String?;
      final deviceName = data['deviceName'] as String?;
      final ipAddress = data['ipAddress'] as String?;
      final port = data['port'] as int?;
      
      if (deviceId == null || deviceName == null || 
          ipAddress == null || port == null) {
        return null;
      }

      final accessToken = data['accessToken'] as String?;
      
      // Extract additional parameters (excluding known ones)
      final additionalParams = <String, String>{};
      data.forEach((key, value) {
        if (!['deviceId', 'deviceName', 'ipAddress', 'port', 'accessToken', 'protocol', 'version'].contains(key)) {
          additionalParams[key] = value.toString();
        }
      });

      return SyncConnectionString(
        deviceId: deviceId,
        deviceName: deviceName,
        ipAddress: ipAddress,
        port: port,
        accessToken: accessToken,
        additionalParams: additionalParams.isNotEmpty ? additionalParams : null,
      );
    } catch (e) {
      return null;
    }
  }

  /// Validate if the connection string has valid format and data
  bool get isValid {
    return deviceId.isNotEmpty &&
           deviceName.isNotEmpty &&
           ipAddress.isNotEmpty &&
           port > 0 &&
           port < 65536 &&
           _isValidIPAddress(ipAddress);
  }

  /// Check if IP address format is valid (basic validation)
  bool _isValidIPAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    try {
      for (final part in parts) {
        final num = int.parse(part);
        if (num < 0 || num > 255) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create a copy with updated values
  SyncConnectionString copyWith({
    String? deviceId,
    String? deviceName,
    String? ipAddress,
    int? port,
    String? accessToken,
    Map<String, String>? additionalParams,
  }) {
    return SyncConnectionString(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      accessToken: accessToken ?? this.accessToken,
      additionalParams: additionalParams ?? this.additionalParams,
    );
  }

  @override
  String toString() {
    return 'SyncConnectionString('
        'deviceId: $deviceId, '
        'deviceName: $deviceName, '
        'ipAddress: $ipAddress, '
        'port: $port, '
        'hasToken: ${accessToken != null})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncConnectionString &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          deviceName == other.deviceName &&
          ipAddress == other.ipAddress &&
          port == other.port &&
          accessToken == other.accessToken;

  @override
  int get hashCode => Object.hash(
        deviceId,
        deviceName,
        ipAddress,
        port,
        accessToken,
      );
}