class PaginatedList<T> {
  List<T> items;
  int totalItemCount;
  int totalPageCount;
  int pageIndex;
  int pageSize;

  PaginatedList({
    required this.items,
    required this.totalItemCount,
    required this.totalPageCount,
    required this.pageIndex,
    required this.pageSize,
  });
}
