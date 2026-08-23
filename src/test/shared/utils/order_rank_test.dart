import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';

void _expectCanonicalAscending(List<String> ranks) {
  expect(OrderRank.needsNormalization(ranks), isFalse);
  for (var index = 1; index < ranks.length; index++) expect(ranks[index - 1].compareTo(ranks[index]), lessThan(0));
}

void _insertAndRecover(
  List<String> itemIds,
  Map<String, String> assignedRanks,
  String itemId,
  int insertionIndex,
) {
  final beforeOrder = insertionIndex == 0 ? null : assignedRanks[itemIds[insertionIndex - 1]];
  final afterOrder = insertionIndex == itemIds.length ? null : assignedRanks[itemIds[insertionIndex]];

  try {
    assignedRanks[itemId] = OrderRank.neighborRank(
      beforeOrder: beforeOrder,
      afterOrder: afterOrder,
    );
    itemIds.insert(insertionIndex, itemId);
  } on RankGapTooSmallException {
    itemIds.insert(insertionIndex, itemId);
    final placedRank = OrderRank.assignSequential<String>(
      itemIds,
      setOrder: (item, rank) => assignedRanks[item] = rank,
      isPlaced: (item) => item == itemId,
    );
    expect(placedRank, assignedRanks[itemId]);
  }

  _expectCanonicalAscending(itemIds.map((item) => assignedRanks[item]!).toList());
}

void main() {
  group('rank grammar', () {
    test('uses the canonical base-62 fractional ranks', () {
      expect(OrderRank.initialRank, 'U');
      expect(OrderRank.neighborRank(), 'U');
      expect(OrderRank.neighborRank(afterOrder: 'a'), 'I');
      expect(OrderRank.neighborRank(beforeOrder: 'a'), 'n');
      expect(OrderRank.neighborRank(beforeOrder: 'a', afterOrder: 'b'), 'aV');
      expect(OrderRank.neighborRank(beforeOrder: 'az', afterOrder: 'b'), 'azV');
      expect(OrderRank.neighborRank(beforeOrder: 'a', afterOrder: 'aV'), 'aF');
      expect(OrderRank.neighborRank(beforeOrder: 'a', afterOrder: 'a0000001'), 'a0000000V');
    });

    test('returns a canonical rank strictly between valid bounds', () {
      final rank = OrderRank.neighborRank(beforeOrder: 'aF', afterOrder: 'aV');

      expect(rank.compareTo('aF'), greaterThan(0));
      expect(rank.compareTo('aV'), lessThan(0));
      expect(rank.endsWith('0'), isFalse);
    });

    test('normalizes malformed, oversized, duplicate, and inverted ranks', () {
      expect(OrderRank.needsNormalization(['a', 'b']), isFalse);
      expect(OrderRank.needsNormalization(['']), isTrue);
      expect(OrderRank.needsNormalization(['0']), isTrue);
      expect(OrderRank.needsNormalization(['000']), isTrue);
      expect(OrderRank.needsNormalization(['a0']), isTrue);
      expect(OrderRank.needsNormalization(['a!']), isTrue);
      expect(OrderRank.needsNormalization(['a', 'a']), isTrue);
      expect(OrderRank.needsNormalization(['b', 'a']), isTrue);
      expect(OrderRank.needsNormalization(['${'a' * OrderRank.maxRankLength}1']), isTrue);
    });
  });

  group('failure paths', () {
    test('rejects inverted and malformed neighbor bounds', () {
      final invalidBounds = [
        (before: 'a', after: 'a'),
        (before: 'zz', after: 'aa'),
        (before: 'a!', after: 'b'),
        (before: 'a', after: 'b!'),
        (before: 'a0', after: 'b'),
        (before: 'a', after: 'b0'),
        (before: '000', after: 'b'),
        (before: 'a', after: '000'),
      ];

      for (final bounds in invalidBounds)
        expect(
          () => OrderRank.neighborRank(
            beforeOrder: bounds.before,
            afterOrder: bounds.after,
          ),
          throwsA(isA<InvalidNeighborOrderException>()),
        );
    });

    test('cannotFit identifies invalid bounds and an overlength midpoint', () {
      final before = 'a' * OrderRank.maxRankLength;

      for (final bounds in [
        (before: 'a!', after: 'b'),
        (before: '000', after: 'b'),
        (before: 'a0', after: 'b'),
        (before: 'a', after: 'a'),
        (before: 'b', after: 'a'),
        (before: before, after: '${before}1'),
      ])
        expect(
          OrderRank.cannotFit(
            beforeOrder: bounds.before,
            afterOrder: bounds.after,
          ),
          isTrue,
        );

      expect(OrderRank.cannotFit(beforeOrder: 'a', afterOrder: 'b'), isFalse);
    });

    test('reserves RankGapTooSmallException for an overlength midpoint', () {
      final before = 'a' * OrderRank.maxRankLength;

      expect(
        () => OrderRank.neighborRank(beforeOrder: before, afterOrder: '${before}1'),
        throwsA(isA<RankGapTooSmallException>()),
      );
    });
  });

  group('legacy conversion', () {
    test('maps the lowest bucket to a prependable canonical rank', () {
      final zero = OrderRank.fromLegacyDouble(0);

      expect(zero, '0000001');
      expect(OrderRank.neighborRank(afterOrder: zero).compareTo(zero), lessThan(0));
      expect(zero.compareTo(OrderRank.fromLegacyDouble(1)), lessThan(0));
    });

    test('maps non-finite legacy values to the initial rank', () {
      expect(OrderRank.fromLegacyDouble(double.nan), OrderRank.initialRank);
      expect(OrderRank.fromLegacyDouble(double.infinity), OrderRank.initialRank);
      expect(OrderRank.fromLegacyDouble(double.negativeInfinity), OrderRank.initialRank);
    });

    test('is non-decreasing across the legacy range', () {
      final ranks = [0.0, 1.0, 2.0, 1000.0, 1000000.0].map(OrderRank.fromLegacyDouble).toList();

      for (var index = 1; index < ranks.length; index++)
        expect(ranks[index - 1].compareTo(ranks[index]), lessThanOrEqualTo(0));
    });
  });

  group('sequential assignment', () {
    test('assigns canonical ascending ranks and returns the placed rank', () {
      final assignedRanks = <String, String>{};
      final placedRank = OrderRank.assignSequential<String>(
        ['first', 'placed', 'last'],
        setOrder: (item, rank) => assignedRanks[item] = rank,
        isPlaced: (item) => item == 'placed',
      );

      expect(assignedRanks['first']!.compareTo(assignedRanks['placed']!), lessThan(0));
      expect(assignedRanks['placed']!.compareTo(assignedRanks['last']!), lessThan(0));
      expect(placedRank, assignedRanks['placed']);
      expect(OrderRank.needsNormalization(assignedRanks.values.toList()), isFalse);
    });

    test('keeps 62 and 63 assignments canonical, unique, and ordered', () {
      for (final itemCount in [62, 63]) {
        final itemIds = List.generate(itemCount, (index) => 'item-$index');
        final assignedRanks = <String, String>{};
        final placedItem = itemIds.last;
        final placedRank = OrderRank.assignSequential<String>(
          itemIds,
          setOrder: (item, rank) => assignedRanks[item] = rank,
          isPlaced: (item) => item == placedItem,
        );
        final ranks = itemIds.map((item) => assignedRanks[item]!).toList();

        expect(ranks.toSet(), hasLength(itemCount));
        _expectCanonicalAscending(ranks);
        expect(placedRank, assignedRanks[placedItem]);
      }
    });
  });

  group('repeated insertion recovery', () {
    test('preserves every placement through 1000 same-gap insertions', () {
      final itemIds = ['lower', 'upper'];
      final assignedRanks = {'lower': 'a', 'upper': 'b'};

      for (var index = 0; index < 1000; index++) _insertAndRecover(itemIds, assignedRanks, 'gap-$index', 1);

      expect(itemIds, hasLength(1002));
      _expectCanonicalAscending(itemIds.map((item) => assignedRanks[item]!).toList());
    });

    test('preserves every placement through 1000 prepends', () {
      final itemIds = ['initial'];
      final assignedRanks = {'initial': OrderRank.initialRank};

      for (var index = 0; index < 1000; index++) _insertAndRecover(itemIds, assignedRanks, 'prepend-$index', 0);

      expect(itemIds, hasLength(1001));
      _expectCanonicalAscending(itemIds.map((item) => assignedRanks[item]!).toList());
    });

    test('preserves every placement through 1000 appends', () {
      final itemIds = ['initial'];
      final assignedRanks = {'initial': OrderRank.initialRank};

      for (var index = 0; index < 1000; index++)
        _insertAndRecover(itemIds, assignedRanks, 'append-$index', itemIds.length);

      expect(itemIds, hasLength(1001));
      _expectCanonicalAscending(itemIds.map((item) => assignedRanks[item]!).toList());
    });
  });
}
