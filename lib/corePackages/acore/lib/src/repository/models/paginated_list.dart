class PaginatedList<T> {
  List<T> items;
  int totalItemCount;
  late int totalPageCount;
  int pageIndex;
  int pageSize;
  bool get hasNext => pageIndex < totalPageCount - 1;
  bool get hasPrevious => pageIndex > 0;

  PaginatedList({
    required this.items,
    required this.totalItemCount,
    required this.pageIndex,
    required this.pageSize,
  }) {
    totalPageCount = pageSize > 0 ? (totalItemCount / pageSize).ceil() : (totalItemCount > 0 ? 1 : 0);
  }
}
