import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/shared/utils/pagination_utils.dart';

class _FetchResult {
  final List<int> items;
  final int totalItemCount;

  _FetchResult(this.items, this.totalItemCount);
}

/// Simulates a paged list backed by a DB of int ids, driving [PaginationUtils] the way
/// a list widget does. [drop] mimics Dart-side filtering applied after SQL paging while
/// `totalItemCount` stays unfiltered.
class _SimulatedList {
  List<int> db;
  final int pageSize;
  final bool Function(int id)? drop;

  List<int> items = [];
  int cursor = 0;
  int totalItemCount = 0;
  final List<(int, int)> requests = [];
  final List<({(int, int) request, int added})> loadMores = [];

  _SimulatedList({required this.db, required this.pageSize, this.drop});

  bool get hasMore => PaginationUtils.hasMore(cursor: cursor, totalItemCount: totalItemCount);

  _FetchResult _fetch(int pageIndex, int size) {
    requests.add((pageIndex, size));
    final slice = db.skip(pageIndex * size).take(size);
    final kept = drop == null ? slice.toList() : slice.where((id) => !drop!(id)).toList();
    return _FetchResult(kept, db.length);
  }

  void _updateCursor(int pageIndex, int size, int total) {
    totalItemCount = total;
    cursor = PaginationUtils.cursorAfter(pageIndex: pageIndex, pageSize: size, totalItemCount: total);
  }

  void initialLoad() {
    final result = _fetch(0, pageSize);
    items = result.items;
    _updateCursor(0, pageSize, result.totalItemCount);
  }

  void loadMore() {
    final pageIndex = PaginationUtils.nextPageIndex(cursor: cursor, pageSize: pageSize);
    final result = _fetch(pageIndex, pageSize);
    final before = items.length;
    items = PaginationUtils.appendUnique<int, int>(items, result.items, (id) => id);
    loadMores.add((request: (pageIndex, pageSize), added: items.length - before));
    _updateCursor(pageIndex, pageSize, result.totalItemCount);
  }

  void refresh() {
    final size = max(cursor, pageSize);
    final result = _fetch(0, size);
    items = result.items;
    _updateCursor(0, size, result.totalItemCount);
  }

  void loadUntilDone() {
    var guard = 0;
    while (hasMore) {
      loadMore();
      if (++guard > 1000) fail('Pagination did not terminate');
    }
  }
}

List<int> _range(int from, int to) => [for (var i = from; i <= to; i++) i];

void main() {
  group('PaginationUtils.cursorAfter', () {
    final cases = <(int, int, int, int)>[
      (0, 10, 45, 10),
      (2, 10, 45, 30),
      (4, 10, 45, 45),
      (0, 30, 45, 30),
      (0, 10, 0, 0),
      (5, 10, 45, 45),
      (2, 10, 23, 23),
    ];
    for (final (pageIndex, pageSize, total, expected) in cases) {
      test('returns $expected rows consumed for page $pageIndex of size $pageSize with $total total rows', () {
        expect(
          PaginationUtils.cursorAfter(pageIndex: pageIndex, pageSize: pageSize, totalItemCount: total),
          expected,
        );
      });
    }
  });

  group('PaginationUtils.nextPageIndex', () {
    final cases = <(int, int, int)>[
      (0, 10, 0),
      (10, 10, 1),
      (30, 10, 3),
      (23, 10, 2),
      (9, 10, 0),
      (3, 5, 0),
    ];
    for (final (cursor, pageSize, expected) in cases) {
      test('returns page $expected for cursor $cursor and page size $pageSize', () {
        expect(PaginationUtils.nextPageIndex(cursor: cursor, pageSize: pageSize), expected);
      });
    }
  });

  group('PaginationUtils.hasMore', () {
    final cases = <(int, int, bool)>[
      (30, 45, true),
      (45, 45, false),
      (50, 45, false),
      (0, 0, false),
    ];
    for (final (cursor, total, expected) in cases) {
      test('returns $expected for cursor $cursor with $total total rows', () {
        expect(PaginationUtils.hasMore(cursor: cursor, totalItemCount: total), expected);
      });
    }
  });

  group('PaginationUtils.appendUnique', () {
    test('drops incoming items already present and keeps order', () {
      final result = PaginationUtils.appendUnique<int, int>(_range(1, 30), _range(21, 40), (id) => id);
      expect(result, _range(1, 40));
    });

    test('appends items repeated within incoming only once', () {
      final result = PaginationUtils.appendUnique<int, int>(_range(1, 30), [31, 31, 32], (id) => id);
      expect(result, [..._range(1, 30), 31, 32]);
    });

    test('returns existing items unchanged when incoming is empty', () {
      final existing = _range(1, 30);
      final result = PaginationUtils.appendUnique<int, int>(existing, [], (id) => id);
      expect(result, _range(1, 30));
      expect(existing, _range(1, 30));
    });
  });

  group('PaginationUtils driving an unfiltered list', () {
    test('loads every row exactly once in order from scratch', () {
      final list = _SimulatedList(db: _range(1, 47), pageSize: 10);
      list.initialLoad();
      list.loadUntilDone();

      expect(list.items, _range(1, 47));
      expect(list.hasMore, isFalse);
    });

    test('refresh at cursor 30 reloads 30 rows and loading continues without gaps or duplicates', () {
      final list = _SimulatedList(db: _range(1, 47), pageSize: 10);
      list.initialLoad();
      list.loadMore();
      list.loadMore();
      expect(list.cursor, 30);

      list.refresh();
      expect(list.requests.last, (0, 30));
      expect(list.cursor, 30);
      expect(list.items, _range(1, 30));

      list.loadUntilDone();
      expect(list.items, _range(1, 47));
      expect(list.hasMore, isFalse);
    });

    test('refresh leaving a non-multiple cursor dedupes the overlap after the DB grows', () {
      final list = _SimulatedList(db: _range(1, 23), pageSize: 10);
      list.initialLoad();
      list.loadUntilDone();
      expect(list.cursor, 23);

      list.refresh();
      expect(list.requests.last, (0, 23));
      expect(list.cursor, 23);
      expect(list.hasMore, isFalse);

      // Rows are added and the list observes the new total (as a later response would report).
      list.db = _range(1, 47);
      list.totalItemCount = 47;
      expect(list.hasMore, isTrue);

      list.loadMore();
      expect(list.requests.last, (2, 10));
      expect(list.items, _range(1, 30));

      list.loadUntilDone();
      expect(list.items, _range(1, 47));
      expect(list.hasMore, isFalse);
    });
  });

  group('PaginationUtils driving a list filtered after SQL paging', () {
    final maxLoadMores = (47 / 5).ceil();

    test('reaches every kept row once in order when rows are dropped after slicing', () {
      bool drop(int id) => id % 3 == 0;
      final list = _SimulatedList(db: _range(1, 47), pageSize: 5, drop: drop);
      list.initialLoad();
      list.loadUntilDone();

      expect(list.items, _range(1, 47).where((id) => !drop(id)).toList());
      expect(list.hasMore, isFalse);
      expect(list.loadMores.length, lessThanOrEqualTo(maxLoadMores));
    });

    test('keeps loading past a page whose rows are all dropped', () {
      bool drop(int id) => id % 3 == 0 || (id >= 11 && id <= 15);
      final list = _SimulatedList(db: _range(1, 47), pageSize: 5, drop: drop);
      list.initialLoad();
      list.loadUntilDone();

      final emptyPage = list.loadMores.firstWhere((loadMore) => loadMore.request == (2, 5));
      expect(emptyPage.added, 0);
      expect(list.items.where((id) => id >= 16), isNotEmpty);
      expect(list.items, _range(1, 47).where((id) => !drop(id)).toList());
      expect(list.hasMore, isFalse);
      expect(list.loadMores.length, lessThanOrEqualTo(maxLoadMores));
    });
  });
}
