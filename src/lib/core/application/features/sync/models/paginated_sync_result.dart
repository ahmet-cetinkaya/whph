/// Result of paginated sync operation
class PaginatedSyncResult {
  final bool success;
  final bool hasMorePages;
  final int? totalPages;
  final int? totalItems;
  final String? errorMessage;

  PaginatedSyncResult({
    required this.success,
    this.hasMorePages = false,
    this.totalPages,
    this.totalItems,
    this.errorMessage,
  });

  factory PaginatedSyncResult.success({
    bool hasMorePages = false,
    int? totalPages,
    int? totalItems,
  }) {
    return PaginatedSyncResult(
      success: true,
      hasMorePages: hasMorePages,
      totalPages: totalPages,
      totalItems: totalItems,
    );
  }

  factory PaginatedSyncResult.failure(String errorMessage) {
    return PaginatedSyncResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}
