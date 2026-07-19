import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderRank.neighborRank', () {
    test('returns initialStep for an empty list (both bounds null)', () {
      expect(OrderRank.neighborRank(), OrderRank.initialStep);
    });

    test('places strictly between two well-spaced neighbors (midpoint)', () {
      final rank = OrderRank.neighborRank(beforeOrder: 1000, afterOrder: 2000);
      expect(rank, greaterThan(1000));
      expect(rank, lessThan(2000));
      expect(rank, 1500);
    });

    test('places before the first item when beforeOrder is null', () {
      final rank = OrderRank.neighborRank(afterOrder: 1000);
      expect(rank, lessThan(1000));
    });

    test('places after the last item when afterOrder is null', () {
      final rank = OrderRank.neighborRank(beforeOrder: 3000);
      expect(rank, greaterThan(3000));
    });

    test('throws RankGapTooSmallException when neighbors are too close', () {
      expect(
        () => OrderRank.neighborRank(beforeOrder: 1000, afterOrder: 1000.5),
        throwsA(isA<RankGapTooSmallException>()),
      );
    });

    test('throws InvalidNeighborOrderException when neighbors are equal', () {
      expect(
        () => OrderRank.neighborRank(beforeOrder: 1000, afterOrder: 1000),
        throwsA(isA<InvalidNeighborOrderException>()),
      );
    });

    test('throws InvalidNeighborOrderException when neighbors are inverted', () {
      // A caller bug (before > after) must be distinguishable from a genuine
      // too-small gap so it is not silently masked by renormalization.
      expect(
        () => OrderRank.neighborRank(beforeOrder: 5000, afterOrder: 1000),
        throwsA(isA<InvalidNeighborOrderException>()),
      );
    });

    test('throws RankGapTooSmallException when appending would overflow maxOrder', () {
      expect(
        () => OrderRank.neighborRank(beforeOrder: OrderRank.maxOrder - 1),
        throwsA(isA<RankGapTooSmallException>()),
      );
    });
  });

  group('OrderRank.cannotFit', () {
    test('false for well-spaced neighbors', () {
      expect(OrderRank.cannotFit(beforeOrder: 1000, afterOrder: 2000), isFalse);
    });

    test('true when the gap is below minimumOrderGap', () {
      expect(OrderRank.cannotFit(beforeOrder: 1000, afterOrder: 1000.5), isTrue);
    });

    test('true when neighbors are inverted or equal', () {
      expect(OrderRank.cannotFit(beforeOrder: 2000, afterOrder: 1000), isTrue);
      expect(OrderRank.cannotFit(beforeOrder: 1000, afterOrder: 1000), isTrue);
    });

    test('false when prepending at the head (beforeOrder null)', () {
      expect(OrderRank.cannotFit(afterOrder: 1000), isFalse);
    });

    test('false when appending at the tail with headroom', () {
      expect(OrderRank.cannotFit(beforeOrder: 3000), isFalse);
    });

    test('true when appending at the tail would overflow maxOrder', () {
      expect(OrderRank.cannotFit(beforeOrder: OrderRank.maxOrder - 1), isTrue);
    });

    test('false for an empty list (both bounds null)', () {
      expect(OrderRank.cannotFit(), isFalse);
    });
  });

  group('OrderRank.needsNormalization', () {
    test('false for a cleanly spaced, positive, unique set', () {
      expect(OrderRank.needsNormalization([1000, 2000, 3000]), isFalse);
    });

    test('true when duplicates are present', () {
      expect(OrderRank.needsNormalization([1000, 1000, 3000]), isTrue);
    });

    test('true when an adjacent gap collapses below minimumOrderGap', () {
      expect(OrderRank.needsNormalization([1000, 1000.5, 3000]), isTrue);
    });

    test('true when a non-positive order is present', () {
      expect(OrderRank.needsNormalization([0, 1000, 2000]), isTrue);
      expect(OrderRank.needsNormalization([-5, 1000, 2000]), isTrue);
    });

    test('true when a positive-but-near-zero order is present', () {
      expect(OrderRank.needsNormalization([1e-9, 1000, 2000]), isTrue);
    });

    test('true when a value reaches or exceeds maxOrder', () {
      expect(OrderRank.needsNormalization([1000, 2000, OrderRank.maxOrder]), isTrue);
      expect(OrderRank.needsNormalization([1000, 2000, OrderRank.maxOrder + 1]), isTrue);
    });

    test('false for an empty set', () {
      expect(OrderRank.needsNormalization([]), isFalse);
    });

    test('unsorted input is evaluated after sorting', () {
      expect(OrderRank.needsNormalization([3000, 2000, 2000.4, 1000]), isTrue);
    });
  });

  group('OrderRank.hasNearZeroOrder', () {
    test('false for a normal positive set', () {
      expect(OrderRank.hasNearZeroOrder([1000, 2000, 3000]), isFalse);
    });

    test('true for an effectively-zero value', () {
      expect(OrderRank.hasNearZeroOrder([1e-11, 1000]), isTrue);
    });

    test('true for a positive-but-below-tolerance value', () {
      expect(OrderRank.hasNearZeroOrder([1e-7, 1000]), isTrue);
    });
  });

  group('OrderRank.assignSequential', () {
    test('assigns evenly spaced initialStep multiples in order', () {
      final items = ['a', 'b', 'c'];
      final orders = <String, double>{};
      OrderRank.assignSequential<String>(items, setOrder: (item, order) => orders[item] = order);
      expect(orders['a'], OrderRank.initialStep);
      expect(orders['b'], OrderRank.initialStep * 2);
      expect(orders['c'], OrderRank.initialStep * 3);
    });

    test('returns the order assigned to the placed item', () {
      final items = ['a', 'b', 'c'];
      final placed = OrderRank.assignSequential<String>(
        items,
        setOrder: (_, __) {},
        isPlaced: (item) => item == 'b',
      );
      expect(placed, OrderRank.initialStep * 2);
    });

    test('returns initialStep when no item is marked placed', () {
      final placed = OrderRank.assignSequential<String>(['a'], setOrder: (_, __) {});
      expect(placed, OrderRank.initialStep);
    });
  });

  group('regression: collapsed-gap reorder no longer collides', () {
    test('needsNormalization catches the accumulated-midpoint scenario', () {
      final orders = [1000.0, 1000.5, 1001.0, 3000.0];
      expect(OrderRank.needsNormalization(orders), isTrue);
    });
  });
}
