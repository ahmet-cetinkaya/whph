class MigrationException implements Exception {
  final String message;
  final Object? originalError;

  MigrationException(this.message, this.originalError);

  @override
  String toString() => 'MigrationException: $message';
}
