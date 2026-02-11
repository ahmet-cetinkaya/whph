import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:domain/features/sync/sync_device.dart';

/// Service responsible for validating sync prerequisites and data integrity
abstract class ISyncValidationService {
  /// Validates that the remote app version is compatible with the local version
  ///
  /// Throws [ValidationException] if versions are incompatible
  Future<void> validateVersion(String remoteVersion);

  /// Validates that the remote device is authorized and properly configured
  ///
  /// Throws [ValidationException] if device validation fails
  Future<void> validateDeviceId(SyncDevice remoteDevice);

  /// Validates that the environment mode (demo/production) matches between devices
  ///
  /// Throws [ValidationException] if environment modes don't match
  void validateEnvironmentMode(PaginatedSyncDataDto dto);

  /// Validates the integrity of sync data before processing
  ///
  /// Returns true if data is valid, false otherwise
  bool validateSyncDataIntegrity(PaginatedSyncDataDto dto);

  /// Validates that required sync prerequisites are met
  ///
  /// Throws [ValidationException] if prerequisites are not met
  Future<void> validateSyncPrerequisites();
}

/// Custom exception for sync validation errors
class SyncValidationException implements Exception {
  final String message;
  final String? code;
  final Map<String, String>? params;

  SyncValidationException(this.message, {this.code, this.params});

  @override
  String toString() =>
      'SyncValidationException: $message${code != null ? ' (Code: $code)' : ''}${params != null ? ' (Params: $params)' : ''}';
}
