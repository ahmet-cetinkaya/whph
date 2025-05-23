class PaginatedList<T> {
  List<T> items;
  int totalItemCount;
  int totalPageCount;
  int pageIndex;
  int pageSize;
  bool get hasNext => pageIndex < totalPageCount - 1;
  bool get hasPrevious => pageIndex > 0;

  PaginatedList({
    required this.items,
    required this.totalItemCount,
    required this.totalPageCount,
    required this.pageIndex,
    required this.pageSize,
  });
}
