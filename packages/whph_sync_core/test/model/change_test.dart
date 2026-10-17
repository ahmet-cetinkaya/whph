/// Canonical change encoding, values and the wire rule (T10 acc. 7).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'model_fixtures.dart';

/// One device's local intern table (models `sync_intern` and the
/// `SyncTablePolicy` constants): names/ids ↔ local integers.
final class _InternTable {
  _InternTable({required this.tables, required this.cols, required this.nodes, required this.origins});

  final Map<String, int> tables;
  final Map<String, int> cols;
  final Map<String, int> nodes;
  final Map<String, int> origins;

  static String _name(Map<String, int> m, int id) => m.entries.firstWhere((e) => e.value == id).key;
}

/// A `sync_clock` row as stored on one device: interned integers only.
final class _LocalClockRow {
  const _LocalClockRow({
    required this.tblId,
    required this.pk,
    required this.colId,
    required this.value,
    required this.hlc,
    required this.nodeId,
    required this.originId,
    required this.originSeq,
    this.causeTblId,
    this.causePk,
  });

  final int tblId;
  final String pk;
  final int colId;
  final Object? value;
  final int hlc;
  final int nodeId;
  final int originId;
  final int originSeq;
  final int? causeTblId;
  final String? causePk;
}

/// The encoder: maps local ids to names (wire rule, D1).
Change _encode(_LocalClockRow row, _InternTable t) => Change(
      groupId: groupId,
      tbl: _InternTable._name(t.tables, row.tblId),
      pk: row.pk,
      col: _InternTable._name(t.cols, row.colId),
      value: ChangeValue.of(row.value),
      hlc: row.hlc,
      node: _InternTable._name(t.nodes, row.nodeId),
      origin: OriginId.fromHex(_InternTable._name(t.origins, row.originId)),
      originSeq: row.originSeq,
      cause: row.causeTblId == null ? null : RowRef(_InternTable._name(t.tables, row.causeTblId!), row.causePk!),
    );

/// The same logical change as stored by a device using [t].
_LocalClockRow _rowOn(_InternTable t, Change c) => _LocalClockRow(
      tblId: t.tables[c.tbl]!,
      pk: c.pk,
      colId: t.cols[c.col]!,
      value: c.value.toDart(),
      hlc: c.hlc,
      nodeId: t.nodes[c.node]!,
      originId: t.origins[c.origin.hex]!,
      originSeq: c.originSeq,
      causeTblId: c.cause == null ? null : t.tables[c.cause!.table],
      causePk: c.cause?.pk,
    );

void main() {
  group('wire rule (acc. 7)', () {
    final deviceA = _InternTable(
      tables: {'Task': 1, 'TaskTag': 2, 'Tag': 3},
      cols: {'~': 0, 'title': 5, '*': 9},
      nodes: {'member-a': 1, 'member-b': 2},
      origins: {originA.hex: 3, originB.hex: 4},
    );
    final deviceB = _InternTable(
      tables: {'Tag': 1, 'Task': 17, 'TaskTag': 40},
      cols: {'~': 0, '*': 2, 'title': 31},
      nodes: {'member-b': 1, 'member-a': 77},
      origins: {originB.hex: 1, originA.hex: 12},
    );

    for (final (label, change) in [
      ('without a cause', goldenChangeWithoutCause()),
      ('with a cause', goldenChangeWithCause()),
    ]) {
      test('the same logical change $label encodes identically from two intern tables', () {
        final rowA = _rowOn(deviceA, change);
        final rowB = _rowOn(deviceB, change);
        expect(rowA.tblId, isNot(rowB.tblId), reason: 'the devices really intern differently');
        expect(rowA.nodeId, isNot(rowB.nodeId));
        expect(rowA.originId, isNot(rowB.originId));
        final fromA = _encode(rowA, deviceA);
        final fromB = _encode(rowB, deviceB);
        expect(fromA.canonicalBytes(), orderedEquals(fromB.canonicalBytes()));
        expect(fromA.canonicalHash(), orderedEquals(fromB.canonicalHash()));
        expect(fromA.canonicalBytes(), orderedEquals(change.canonicalBytes()));
        // Envelope metadata and AD are name-based too.
        expect(sealForTest(fromA).encode(), orderedEquals(sealForTest(fromB).encode()));
        expect(
          sealForTest(fromA).associatedData(groupId: groupId, protocolVersion: 2),
          orderedEquals(sealForTest(fromB).associatedData(groupId: groupId, protocolVersion: 2)),
        );
      });
    }

    test('adding, removing or altering the cause changes the canonical hash', () {
      final withCause = goldenChangeWithCause();
      Change variant(RowRef? cause) => Change(
            groupId: withCause.groupId,
            tbl: withCause.tbl,
            pk: withCause.pk,
            col: withCause.col,
            value: withCause.value,
            hlc: withCause.hlc,
            node: withCause.node,
            origin: withCause.origin,
            originSeq: withCause.originSeq,
            cause: cause,
          );
      final hashes = {
        hex(withCause.canonicalHash()),
        hex(variant(null).canonicalHash()),
        hex(variant(const RowRef('Task', 'task-2')).canonicalHash()),
        hex(variant(const RowRef('Habit', 'task-1')).canonicalHash()),
      };
      expect(hashes, hasLength(4));
    });
  });

  group('canonical encoding', () {
    test('is unambiguous across field boundaries', () {
      Change c(String tbl, String pk) => Change(
            groupId: groupId,
            tbl: tbl,
            pk: pk,
            col: 'title',
            value: const NullValue(),
            hlc: baseHlc,
            node: 'n',
            origin: originA,
            originSeq: 1,
          );
      expect(c('ab', 'c').canonicalBytes(), isNot(orderedEquals(c('a', 'bc').canonicalBytes())));
    });

    test('distinguishes value types with the same payload bytes', () {
      final asString = ChangeValue.of('A').encode();
      final asBytes = ChangeValue.of(Uint8List.fromList([0x41])).encode();
      expect(asString, isNot(orderedEquals(asBytes)));
      expect(const NullValue().encode(), isNot(orderedEquals(ChangeValue.of('').encode())));
    });

    test('round-trips every value type, a leading BOM and non-ASCII text', () {
      for (final value in <ChangeValue>[
        const NullValue(),
        const IntValue(-1),
        const IntValue(0x7FFFFFFFFFFFFFFF),
        StringValue('\uFEFFbom-led, ğüşİ 😀'),
        BytesValue([0, 1, 255]),
        UnknownValue(200, [9, 8, 7]),
      ]) {
        expect(ChangeValue.decode(value.encode()), value, reason: '$value');
        final change = Change(
          groupId: groupId,
          tbl: 'T',
          pk: '\uFEFFpk',
          col: 'c',
          value: value,
          hlc: baseHlc,
          node: 'n',
          origin: originA,
          originSeq: 5,
        );
        final bytes = change.canonicalBytes();
        final decoded = Change.fromCanonicalBytes(bytes);
        expect(decoded, change);
        expect(decoded.canonicalBytes(), orderedEquals(bytes));
      }
    });

    test('rejects unencodable strings and invalid fields at construction', () {
      expect(() => StringValue('\uD800'), throwsArgumentError);
      expect(
        () => Change(
          groupId: groupId,
          tbl: '',
          pk: 'p',
          col: 'c',
          value: const NullValue(),
          hlc: baseHlc,
          node: 'n',
          origin: originA,
          originSeq: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => Change(
          groupId: groupId,
          tbl: 't',
          pk: 'p',
          col: 'c',
          value: const NullValue(),
          hlc: baseHlc,
          node: 'n',
          origin: originA,
          originSeq: 0,
        ),
        throwsArgumentError,
      );
    });

    test('decoding rejects malformed input with typed errors', () {
      final good = goldenChangeWithCause().canonicalBytes();
      expect(
          () => Change.fromCanonicalBytes(good.sublist(0, good.length - 1)), throwsA(isA<TruncatedMessageException>()));
      expect(
          () => Change.fromCanonicalBytes(Uint8List.fromList([...good, 0])), throwsA(isA<MalformedMessageException>()));
      final badMarker = Uint8List.fromList(good);
      badMarker[good.length - 19] = 2; // the cause marker, followed by str "Task" (4+4) and str "task-1" (4+6)
      expect(() => Change.fromCanonicalBytes(badMarker), throwsA(isA<MalformedMessageException>()));
      expect(() => ChangeValue.decode(Uint8List.fromList([ChangeValue.tagInt, 0, 0, 0, 4, 1, 2, 3, 4])),
          throwsA(isA<MalformedMessageException>()));
      expect(() => ChangeValue.decode(Uint8List.fromList([ChangeValue.tagString, 0, 0, 0, 2, 0xC0, 0x80])),
          throwsA(isA<MalformedMessageException>()));
    });

    test('values above 2 MiB are rejected on decode and on construction', () {
      final big = Uint8List(SyncLimits.maxValueBytes + 1);
      final header = ByteData(5)
        ..setUint8(0, ChangeValue.tagBytes)
        ..setUint32(1, big.length);
      expect(() => ChangeValue.decode(Uint8List.fromList([...header.buffer.asUint8List(), ...big])),
          throwsA(isA<ValueTooLargeException>()));
      expect(
        () => Change(
          groupId: groupId,
          tbl: 't',
          pk: 'p',
          col: 'c',
          value: BytesValue(big),
          hlc: baseHlc,
          node: 'n',
          origin: originA,
          originSeq: 1,
        ),
        throwsA(isA<ValueTooLargeException>()),
      );
      expect(ChangeValue.decode(BytesValue(Uint8List(SyncLimits.maxValueBytes)).encode()), isA<BytesValue>());
    });

    test('toString never prints the value', () {
      final change = goldenChangeWithoutCause();
      expect('$change', isNot(contains('Buy milk')));
      expect(utf8.decode(change.canonicalBytes().sublist(0, 23)), contains('whph-sync/change/v1'));
    });

    test('store round trip preserves the canonical bytes', () {
      for (final change in [goldenChangeWithoutCause(), goldenChangeWithCause()]) {
        final back = Change.fromCellRecord(change.toCellRecord(), groupId: groupId);
        expect(back.canonicalBytes(), orderedEquals(change.canonicalBytes()));
      }
    });
  });
}
