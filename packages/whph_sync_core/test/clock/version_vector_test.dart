import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

void main() {
  group('VersionVector.advance', () {
    test('advances to the declared upper bound of a contiguous range', () {
      final v = VersionVector();
      expect(v.advance('o1', fromSeq: 0, toSeq: 10), isTrue);
      expect(v.cursorOf('o1'), 10);
      // Declared bound, even if the range carried fewer cells (superseded seqs).
      expect(v.advance('o1', fromSeq: 10, toSeq: 25), isTrue);
      expect(v.cursorOf('o1'), 25);
      // Overlapping range reaching past the cursor.
      expect(v.advance('o1', fromSeq: 20, toSeq: 30), isTrue);
      expect(v.cursorOf('o1'), 30);
    });

    test('duplicates and gaps change nothing', () {
      final v = VersionVector({'o1': 10});
      expect(v.advance('o1', fromSeq: 0, toSeq: 10), isFalse);
      expect(v.advance('o1', fromSeq: 5, toSeq: 8), isFalse);
      expect(v.advance('o1', fromSeq: 11, toSeq: 20), isFalse);
      expect(v.advance('o2', fromSeq: 3, toSeq: 9), isFalse);
      expect(v.toMap(), {'o1': 10});
      expect(v.covers('o1', 10), isTrue);
      expect(v.covers('o1', 11), isFalse);
      expect(v.covers('o2', 0), isTrue);
    });

    test('rejects negative or inverted ranges', () {
      final v = VersionVector();
      expect(() => v.advance('o', fromSeq: -1, toSeq: 2), throwsArgumentError);
      expect(() => v.advance('o', fromSeq: 5, toSeq: 4), throwsArgumentError);
      expect(() => VersionVector({'o': -1}), throwsArgumentError);
    });
  });

  test('origins are listed sorted', () {
    expect(VersionVector({'c': 2, 'a': 7, 'b': 9}).origins, ['a', 'b', 'c']);
  });
}
