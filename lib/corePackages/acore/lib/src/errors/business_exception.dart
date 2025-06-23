class BusinessException implements Exception {
  final String message;
  final String errorCode;
  final Map<String, String>? args;

  BusinessException(this.message, this.errorCode, {this.args});

  @override
  String toString() => message;
}
