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

    test('throws when neighbors are too close to fit a value between them', () {
      // Exactly minimumOrderGap apart -> the gap is not strictly greater, so
      // no reliable midpoint exists.
      expect(
        () => OrderRank.neighborRank(beforeOrder: 1000, afterOrder: 1000.5),
        throwsA(isA<RankGapTooSmallException>()),
      );
    });

    test('throws when neighbors are equal (duplicate orders)', () {
      expect(
        () => OrderRank.neighborRank(beforeOrder: 1000, afterOrder: 1000),
        throwsA(isA<RankGapTooSmallException>()),
      );
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

    test('false for an empty set', () {
      expect(OrderRank.needsNormalization([]), isFalse);
    });

    test('unsorted input is evaluated after sorting', () {
      // Contains a collapsed gap once sorted (2000 and 2000.4).
      expect(OrderRank.needsNormalization([3000, 2000, 2000.4, 1000]), isTrue);
    });
  });

  group('regression: collapsed-gap reorder no longer collides', () {
    test('needsNormalization catches the accumulated-midpoint scenario', () {
      // Reproduces the diagnosis: repeated midpoint insertions collapse the gap
      // between the first two items below minimumOrderGap. The set must now be
      // flagged for renormalization before the next drag.
      final orders = [1000.0, 1000.5, 1001.0, 3000.0];
      expect(OrderRank.needsNormalization(orders), isTrue);
    });
  });
}
