import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/shared/services/sibling_reorder_service.dart';

class _Sibling {
  _Sibling(this.id, this.order);

  final String id;
  String order;
}

ReorderPlacement<_Sibling> _placeBetween(
  List<_Sibling> siblings, {
  required int targetIndex,
  String? beforeId,
  String? afterId,
}) {
  final moved = _Sibling('moved', 'U');
  return const SiblingReorderService().computePlacement(
    moved: moved,
    siblings: siblings,
    targetIndex: targetIndex,
    beforeId: beforeId,
    afterId: afterId,
    idOf: (item) => item.id,
    orderOf: (item) => item.order,
  );
}

void main() {
  group('SiblingReorderService.computePlacement', () {
    test('renormalizes duplicate sibling ranks into a complete ordered placement', () {
      final first = _Sibling('first', 'U');
      final second = _Sibling('second', 'U');

      final placement = _placeBetween([first, second], targetIndex: 1);

      expect(placement.requiresRenormalization, isTrue);
      expect(placement.order, isNot('U'));
      expect(placement.renumbered, hasLength(3));
      expect(placement.renumbered!.map((item) => item.id), ['first', 'moved', 'second']);
      // computePlacement must not mutate the entities it was given — the
      // caller applies renumberedOrder itself right before persisting.
      expect(first.order, 'U');
      expect(second.order, 'U');
      expect(
        placement.renumbered!.map((item) => placement.renumberedOrder![item.id]).toList(),
        orderedEquals(['F', 'V', 'k']),
      );
      expect(placement.order, placement.renumberedOrder![placement.renumbered![placement.position].id]);
    });

    test('renormalizes when the neighbour midpoint exceeds the maximum rank length', () {
      final lower = _Sibling('lower', 'A' * 32);
      final upper = _Sibling('upper', '${'A' * 31}B');

      final placement = _placeBetween([lower, upper], targetIndex: 1);

      expect(placement.requiresRenormalization, isTrue);
      expect(placement.order, 'V');
      expect(placement.renumbered!.map((item) => item.id), ['lower', 'moved', 'upper']);
      // computePlacement must not mutate the entities it was given.
      expect(lower.order, 'A' * 32);
      expect(upper.order, '${'A' * 31}B');
      expect(
        placement.renumbered!.map((item) => placement.renumberedOrder![item.id]).toList(),
        orderedEquals(['F', 'V', 'k']),
      );
      expect(placement.order, placement.renumberedOrder![placement.renumbered![placement.position].id]);
    });

    test('falls back to the target index when the before sibling is stale', () {
      final first = _Sibling('first', 'F');
      final second = _Sibling('second', 'k');

      final placement = _placeBetween([first, second], targetIndex: 1, beforeId: 'deleted');

      expect(placement.order.compareTo(first.order), greaterThan(0));
      expect(placement.order.compareTo(second.order), lessThan(0));
    });

    test('uses afterId before beforeId and targetIndex', () {
      final first = _Sibling('first', 'F');
      final second = _Sibling('second', 'V');
      final third = _Sibling('third', 'k');

      final placement = _placeBetween(
        [first, second, third],
        targetIndex: 3,
        beforeId: 'third',
        afterId: 'second',
      );

      expect(placement.position, 1);
      expect(placement.order.compareTo(first.order), greaterThan(0));
      expect(placement.order.compareTo(second.order), lessThan(0));
    });
  });
}
