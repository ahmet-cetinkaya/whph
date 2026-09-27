import 'dart:math';

/// Pure helpers for list pagination driven by a database-row cursor.
///
/// The cursor is the number of underlying DB rows consumed so far (the SQL offset
/// already read), not the number of items kept in the list. The two can differ when a
/// query filters rows in Dart after SQL paging, so paging must advance by the cursor to
/// reach every row even when a page contributes zero kept items.
class PaginationUtils {
  PaginationUtils._();

  /// Returns the DB-row cursor after a fetch of [pageIndex]/[pageSize] against a dataset
  /// of [totalItemCount] rows: `min(totalItemCount, (pageIndex + 1) * pageSize)`, never
  /// negative. Use the request's own values, not the ones echoed in the response.
  static int cursorAfter({required int pageIndex, required int pageSize, required int totalItemCount}) {
    assert(pageSize > 0, 'pageSize must be greater than 0');
    assert(pageIndex >= 0, 'pageIndex must not be negative');
    return max(0, min(totalItemCount, (pageIndex + 1) * pageSize));
  }

  /// Returns the page index for the next load-more: `cursor ~/ pageSize`.
  ///
  /// When [cursor] is not a multiple of [pageSize] (e.g. after a refresh), the page
  /// re-reads fewer than [pageSize] already-consumed rows; dedupe them with [appendUnique].
  static int nextPageIndex({required int cursor, required int pageSize}) {
    assert(pageSize > 0, 'pageSize must be greater than 0');
    return cursor ~/ pageSize;
  }

  /// Whether DB rows remain beyond [cursor] out of [totalItemCount] (unfiltered) rows.
  static bool hasMore({required int cursor, required int totalItemCount}) => cursor < totalItemCount;

  /// Returns a new list with [existing] in order followed by the [incoming] items whose
  /// key (from [keyOf]) is not already in [existing] and has not appeared earlier in
  /// [incoming].
  static List<T> appendUnique<T, K>(List<T> existing, List<T> incoming, K Function(T) keyOf) {
    final seen = <K>{for (final item in existing) keyOf(item)};
    final result = List<T>.of(existing);
    for (final item in incoming) {
      if (seen.add(keyOf(item))) result.add(item);
    }
    return result;
  }
}
