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
    setOrder: (item, order) => item.order = order,
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
      expect(
        placement.renumbered!.map((item) => item.order).toList(),
        orderedEquals(['F', 'V', 'k']),
      );
      expect(placement.order, placement.renumbered![placement.position].order);
    });

    test('renormalizes when the neighbour midpoint exceeds the maximum rank length', () {
      final lower = _Sibling('lower', 'A' * 32);
      final upper = _Sibling('upper', '${'A' * 31}B');

      final placement = _placeBetween([lower, upper], targetIndex: 1);

      expect(placement.requiresRenormalization, isTrue);
      expect(placement.order, 'V');
      expect(placement.renumbered!.map((item) => item.id), ['lower', 'moved', 'upper']);
      expect(
        placement.renumbered!.map((item) => item.order).toList(),
        orderedEquals(['F', 'V', 'k']),
      );
      expect(placement.order, placement.renumbered![placement.position].order);
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
