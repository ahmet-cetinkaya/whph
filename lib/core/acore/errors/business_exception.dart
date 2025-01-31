class BusinessException implements Exception {
  final String messageKey;
  final Map<String, String>? args;

  BusinessException(this.messageKey, {this.args});

  @override
  String toString() => messageKey;
}
