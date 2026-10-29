import 'package:test/test.dart';
import 'package:whph_sync_core/src/session/relay_winner.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

void main() {
  StoredCell cell(int seq) => StoredCell(
        CellRecord(
          key: const CellKey('task', 'w', 'title'),
          value: 'v$seq',
          clock: seq << 16,
          node: 'n',
          origin: 'ab' * 16,
          originSeq: seq,
        ),
        recordedAt: 0,
      );

  group('selectRelayWinner (F5)', () {
    test('returns the committed winner the receiver lacks', () {
      final winner = cell(7);
      expect(selectRelayWinner(winner, 6), same(winner));
      expect(selectRelayWinner(winner, 0), same(winner));
    });

    test('needs nothing when the receiver cursor already reaches the winner', () {
      expect(selectRelayWinner(cell(7), 7), isNull);
      expect(selectRelayWinner(cell(7), 9), isNull);
    });

    test('has no candidate when no cell is committed for the key', () {
      expect(selectRelayWinner(null, 0), isNull);
    });
  });
}
