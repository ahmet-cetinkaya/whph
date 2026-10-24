import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_key_store.dart';
import 'package:whph/infrastructure/shared/utils/owner_only_file_utils.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

const keyFileName = 'sync_keys.json';
const ledgerFileName = 'sync_ledger.json';

const _documentVersion = 1;
const _maximumDocumentBytes = 8 * 1024 * 1024;
const _keySubject = 'sync key file';
const _ledgerSubject = 'sync ledger';

/// File-backed [ISyncKeyStore] (D7): the key file in [keyDirectory] and the
/// ledger in [ledgerDirectory], both written by [OwnerOnlyAtomicWriter].
///
/// The ledger is cached in memory after [load] so the synchronous
/// [SyncLedger] getters answer; every mutation writes the whole file before
/// it updates the cache, so a failed write changes nothing. The key file is
/// never cached.
class FileSyncKeyStore implements ISyncKeyStore {
  final Directory keyDirectory;
  final Directory ledgerDirectory;
  final OwnerOnlyAtomicWriter _writer;

  Future<void> _writeQueue = Future.value();
  _LedgerState? _ledger;

  FileSyncKeyStore({
    required this.keyDirectory,
    required this.ledgerDirectory,
    OwnerOnlyAtomicWriter? writer,
  }) : _writer = writer ?? OwnerOnlyAtomicWriter();

  File get keyFile => File(p.join(keyDirectory.path, keyFileName));
  File get ledgerFile => File(p.join(ledgerDirectory.path, ledgerFileName));

  // -- key file ---------------------------------------------------------------

  @override
  Future<bool> keyFileExists() => keyFile.exists();

  @override
  Future<SyncKeyFileContent?> readKeyFile() async {
    try {
      if (!await keyFile.exists()) return null;
      await rejectSymbolicLink(keyFile.path, _keySubject);
      await requireOwnerOnlyMode(keyFile.path, ownerFileMode, _keySubject);
      return _decodeKeyFile(await _readBounded(keyFile));
    } on SyncKeyStoreException {
      rethrow;
    } on OwnerOnlyFileException catch (error) {
      throw SyncKeyStoreException(error.message);
    } on Object {
      throw const SyncKeyStoreException('sync key file could not be read safely');
    }
  }

  @override
  Future<void> writeKeyFile(SyncKeyFileContent content) {
    final bytes = utf8.encode(jsonEncode(_encodeKeyFile(content)));
    return _serialized(() async {
      try {
        await _prepareDirectory(keyDirectory);
        await _writer.write(keyFile, bytes, subject: _keySubject);
      } on OwnerOnlyFileException catch (error) {
        throw SyncKeyStoreException(error.message);
      } on Object {
        throw const SyncKeyStoreException('sync key file could not be saved safely');
      }
    });
  }

  // -- ledger -------------------------------------------------------------------

  @override
  Future<void> load() async {
    try {
      if (!await ledgerFile.exists()) return _ledger = null;
      await rejectSymbolicLink(ledgerFile.path, _ledgerSubject);
      _ledger = _decodeLedger(await _readBounded(ledgerFile));
    } on Object {
      _ledger = null;
    }
  }

  @override
  bool get isReadable => _ledger != null;

  @override
  List<OriginEntry> get entries => List.unmodifiable(_ledger?.entries ?? const <OriginEntry>[]);

  @override
  int get epochCounterHigh => _ledger?.epochCounterHigh ?? 0;

  @override
  List<LedgerRevocation> get revocations => List.unmodifiable(_ledger?.revocations.values ?? const []);

  @override
  Future<void> append(OriginEntry entry) => _mutate((state) => state.entries.add(entry), startFresh: true);

  @override
  Future<void> commit(OriginId origin) =>
      _mutate((state) => state.replace(origin, (e) => e.copyWith(state: OriginEntryState.committed)));

  @override
  Future<void> drop(OriginId origin) => _mutate((state) => state.entries.removeWhere((e) => e.origin == origin));

  @override
  Future<void> persistSentMark(OriginId origin, int seq, int hlc) => _mutate(
        (state) => state.replace(
          origin,
          (e) => e.copyWith(maxSentSeq: math.max(seq, e.maxSentSeq), hlcHigh: math.max(hlc, e.hlcHigh)),
        ),
      );

  @override
  Future<void> persistWrittenWatermark(OriginId origin, int nextSeq, int hlc) => _mutate(
        (state) => state.replace(origin, (e) => e.copyWith(nextSeqHigh: nextSeq, hlcHighWritten: hlc)),
      );

  @override
  Future<void> persistEpochCounterHigh(int counter) =>
      _mutate((state) => state.epochCounterHigh = math.max(state.epochCounterHigh, counter));

  @override
  Future<void> resetEpochCounterHigh() async {
    if (_ledger != null) await _mutate((state) => state.epochCounterHigh = 0);
  }

  @override
  Future<void> persistRevocations(Iterable<LedgerRevocation> revocations) => _mutate((state) {
        for (final revocation in revocations) {
          state.revocations.putIfAbsent(_revocationId(revocation), () => revocation);
        }
      });

  @override
  Future<void> clearRevocations() async {
    if (_ledger != null) await _mutate((state) => state.revocations.clear());
  }

  @override
  Future<void> deleteAll() => _serialized(() async {
        _ledger = null;
        await deleteWithTemporaryFiles(keyFile);
        await deleteWithTemporaryFiles(ledgerFile);
      });

  Future<void> _mutate(void Function(_LedgerState state) change, {bool startFresh = false}) =>
      _serialized(() async {
        final current = _ledger;
        if (current == null && !startFresh) throw const SyncLedgerWriteException('sync ledger missing');
        final next = (current ?? _LedgerState.empty()).copy();
        change(next);
        await _saveLedger(next);
        _ledger = next;
      });

  Future<void> _saveLedger(_LedgerState state) async {
    try {
      await _prepareDirectory(ledgerDirectory);
      await _writer.write(ledgerFile, utf8.encode(jsonEncode(_encodeLedger(state))), subject: _ledgerSubject);
    } on Object {
      throw const SyncLedgerWriteException('sync ledger could not be saved safely');
    }
  }

  // -- shared ---------------------------------------------------------------------

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _prepareDirectory(Directory directory) async {
    await rejectSymbolicLink(directory.path, 'sync storage directory');
    await directory.create(recursive: true);
    await rejectSymbolicLink(directory.path, 'sync storage directory');
  }

  Future<String> _readBounded(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > _maximumDocumentBytes) throw const FormatException('document too large');
    return utf8.decode(bytes);
  }
}

String _revocationId(LedgerRevocation revocation) => '${revocation.carrierId}:${base64Encode(revocation.recordBytes)}';

class _LedgerState {
  final List<OriginEntry> entries;
  int epochCounterHigh;
  final Map<String, LedgerRevocation> revocations;

  _LedgerState(this.entries, this.epochCounterHigh, this.revocations);

  factory _LedgerState.empty() => _LedgerState([], 0, {});

  _LedgerState copy() => _LedgerState(List.of(entries), epochCounterHigh, Map.of(revocations));

  void replace(OriginId origin, OriginEntry Function(OriginEntry) update) {
    final index = entries.lastIndexWhere((e) => e.origin == origin);
    if (index < 0) throw SyncLedgerWriteException('no entry for origin $origin');
    entries[index] = update(entries[index]);
  }
}

// -- ledger codec ---------------------------------------------------------------------

Map<String, Object?> _encodeLedger(_LedgerState state) => {
      'version': _documentVersion,
      'epoch_counter_high': state.epochCounterHigh,
      'origins': [
        for (final e in state.entries)
          {
            'origin_id': e.origin.hex,
            'state': e.state.name,
            'reason': e.reason.name,
            'max_sent_seq': e.maxSentSeq,
            'hlc_high': e.hlcHigh,
            'next_seq_high': e.nextSeqHigh,
            'hlc_high_written': e.hlcHighWritten,
          },
      ],
      'revocations': [
        for (final r in state.revocations.values)
          {
            'record': base64Encode(r.recordBytes),
            'revoker_entry': r.revokerEntryBytes == null ? null : base64Encode(r.revokerEntryBytes!),
            'carrier_origin': r.carrierOrigin.hex,
            'carrier_seq': r.carrierSeq,
          },
      ],
    };

_LedgerState _decodeLedger(String source) {
  final json = _versionedMap(jsonDecode(source));
  final revocations = <String, LedgerRevocation>{};
  for (final item in _list(json['revocations'])) {
    final map = _map(item);
    final revokerEntry = map['revoker_entry'];
    final revocation = LedgerRevocation(
      recordBytes: base64Decode(_string(map['record'])),
      revokerEntryBytes: revokerEntry == null ? null : base64Decode(_string(revokerEntry)),
      carrierOrigin: OriginId.fromHex(_string(map['carrier_origin'])),
      carrierSeq: _int(map['carrier_seq']),
    );
    revocations[_revocationId(revocation)] = revocation;
  }
  return _LedgerState(
    [for (final item in _list(json['origins'])) _decodeEntry(_map(item))],
    _int(json['epoch_counter_high']),
    revocations,
  );
}

OriginEntry _decodeEntry(Map<String, Object?> map) => OriginEntry(
      origin: OriginId.fromHex(_string(map['origin_id'])),
      state: OriginEntryState.values.byName(_string(map['state'])),
      reason: OriginSwitchReason.values.byName(_string(map['reason'])),
      maxSentSeq: _int(map['max_sent_seq']),
      hlcHigh: _int(map['hlc_high']),
      nextSeqHigh: _int(map['next_seq_high']),
      hlcHighWritten: _int(map['hlc_high_written']),
    );

// -- key file codec -------------------------------------------------------------------

Map<String, Object?> _encodeKeyFile(SyncKeyFileContent content) {
  final snapshot = content.snapshot;
  return {
    'version': _documentVersion,
    'member_id': snapshot.memberId,
    'name': snapshot.name,
    'x25519_private': base64Encode(snapshot.x25519Private),
    'ed25519_seed': base64Encode(snapshot.ed25519Seed),
    'group_id': snapshot.groupId?.hex,
    'removed': snapshot.removed,
    'needs_repairing': content.needsRepairing,
    'epoch_keys': [
      for (final e in snapshot.epochKeys.entries)
        {'counter': e.key.counter, 'creator': e.key.creator, 'key': base64Encode(e.value)},
    ],
    'anchors': [
      for (final a in snapshot.anchors)
        {
          'member_id': a.memberId,
          'x25519_pub': base64Encode(a.x25519Pub),
          'ed25519_pub': base64Encode(a.ed25519Pub),
          'name': a.name,
          'added_by': a.addedBy,
          'revoked': snapshot.revokedAnchors.contains(a.memberId),
        },
    ],
  };
}

SyncKeyFileContent _decodeKeyFile(String source) {
  final json = _versionedMap(jsonDecode(source));
  final anchors = <MemberEntry>[];
  final revokedAnchors = <String>{};
  for (final item in _list(json['anchors'])) {
    final map = _map(item);
    final anchor = MemberEntry(
      memberId: _string(map['member_id']),
      x25519Pub: base64Decode(_string(map['x25519_pub'])),
      ed25519Pub: base64Decode(_string(map['ed25519_pub'])),
      name: _string(map['name']),
      addedBy: _string(map['added_by']),
    );
    anchors.add(anchor);
    if (map['revoked'] == true) revokedAnchors.add(anchor.memberId);
  }
  final groupHex = json['group_id'];
  final snapshot = KeyFileSnapshot(
    memberId: _string(json['member_id']),
    name: _string(json['name']),
    x25519Private: Uint8List.fromList(base64Decode(_string(json['x25519_private']))),
    ed25519Seed: Uint8List.fromList(base64Decode(_string(json['ed25519_seed']))),
    groupId: groupHex == null ? null : GroupId.fromHex(_string(groupHex)),
    epochKeys: {
      for (final item in _list(json['epoch_keys']))
        EpochId(_int(_map(item)['counter']), _string(_map(item)['creator'])):
            Uint8List.fromList(base64Decode(_string(_map(item)['key']))),
    },
    anchors: anchors,
    revokedAnchors: revokedAnchors,
    removed: json['removed'] == true,
  );
  return SyncKeyFileContent(snapshot: snapshot, needsRepairing: json['needs_repairing'] == true);
}

Map<String, Object?> _versionedMap(Object? decoded) {
  final map = _map(decoded);
  if (map['version'] != _documentVersion) throw const FormatException('unsupported version');
  return map;
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map<String, dynamic>) throw const FormatException('expected an object');
  return value;
}

List<Object?> _list(Object? value) {
  if (value is! List) throw const FormatException('expected a list');
  return value;
}

String _string(Object? value) {
  if (value is! String) throw const FormatException('expected a string');
  return value;
}

int _int(Object? value) {
  if (value is! int) throw const FormatException('expected an integer');
  return value;
}
