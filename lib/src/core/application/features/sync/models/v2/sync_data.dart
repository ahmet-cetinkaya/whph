/// Generic sync data container for any entity type
class SyncData<T> {
  final List<T> createSync;
  final List<T> updateSync; 
  final List<T> deleteSync;
  final int pageIndex;
  final int pageSize;
  final int totalPages;
  final int totalItems;
  final bool isLastPage;
  final String entityType;

  const SyncData({
    required this.createSync,
    required this.updateSync,
    required this.deleteSync,
    required this.pageIndex,
    required this.pageSize,
    required this.totalPages,
    required this.totalItems,
    required this.isLastPage,
    required this.entityType,
  });

  /// Total count of items in this sync data
  int get itemCount => createSync.length + updateSync.length + deleteSync.length;

  /// Check if sync data is empty
  bool get isEmpty => itemCount == 0;

  /// Factory constructor from repository data
  factory SyncData.fromRepository({
    required List<T> creates,
    required List<T> updates,
    required List<T> deletes,
    required int pageIndex,
    required int pageSize,
    required int totalItems,
    required String entityType,
  }) {
    final totalPages = (totalItems / pageSize).ceil();
    final isLastPage = pageIndex >= totalPages - 1;
    
    return SyncData(
      createSync: creates,
      updateSync: updates,
      deleteSync: deletes,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalPages: totalPages,
      totalItems: totalItems,
      isLastPage: isLastPage,
      entityType: entityType,
    );
  }

  /// Convert to JSON for transmission
  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) serializer) {
    return {
      'createSync': createSync.map(serializer).toList(),
      'updateSync': updateSync.map(serializer).toList(),
      'deleteSync': deleteSync.map(serializer).toList(),
      'pageIndex': pageIndex,
      'pageSize': pageSize,
      'totalPages': totalPages,
      'totalItems': totalItems,
      'isLastPage': isLastPage,
      'entityType': entityType,
    };
  }

  /// Create from JSON
  factory SyncData.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) deserializer,
  ) {
    return SyncData(
      createSync: (json['createSync'] as List)
          .map((e) => deserializer(e as Map<String, dynamic>))
          .toList(),
      updateSync: (json['updateSync'] as List)
          .map((e) => deserializer(e as Map<String, dynamic>))
          .toList(),
      deleteSync: (json['deleteSync'] as List)
          .map((e) => deserializer(e as Map<String, dynamic>))
          .toList(),
      pageIndex: json['pageIndex'] as int,
      pageSize: json['pageSize'] as int,
      totalPages: json['totalPages'] as int,
      totalItems: json['totalItems'] as int,
      isLastPage: json['isLastPage'] as bool,
      entityType: json['entityType'] as String,
    );
  }

  @override
  String toString() => 'SyncData<$entityType>(creates: ${createSync.length}, updates: ${updateSync.length}, deletes: ${deleteSync.length}, page: $pageIndex/$totalPages)';
}