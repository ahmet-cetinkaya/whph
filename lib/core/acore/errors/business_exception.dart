class BusinessException implements Exception {
  final String message;

  BusinessException(this.message);

  @override
  String toString() => message;
}
