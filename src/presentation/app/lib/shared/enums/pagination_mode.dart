/// Defines the pagination mode for list components.
enum PaginationMode {
  /// Show a "Load More" button at the bottom of the list.
  /// User must tap to load more items.
  loadMore,

  /// Automatically load more items when the user scrolls near the bottom.
  infinityScroll,
}
