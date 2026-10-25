import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

/// First plaintext frame of a pairing connection: how the joiner pairs.
const int pairingModeQr = 1;
const int pairingModeSas = 2;

/// The plaintext answer of the inviter to the mode frame.
const int pairingStatusOk = 0;
const int pairingStatusExpiredOrUsed = 1;
const int pairingStatusPreparing = 2;
const int pairingStatusBusy = 3;

/// Longest wait for the next frame of the peer in a pairing step.
const Duration pairingStepTimeout = Duration(seconds: 30);

const String _typeKey = 't';
const String _errorCodeKey = 'code';

/// JSON messages of a pairing over an established Noise session (D7). The
/// payloads are small (a handover carries a few keys), so one Noise message
/// holds one JSON text.
class PairingChannel {
  final ISyncTransport _transport;
  final NoiseSession _session;
  final Duration _timeout;

  PairingChannel(this._transport, this._session, {Duration timeout = pairingStepTimeout}) : _timeout = timeout;

  Uint8List get remoteStatic => _session.remoteStatic;

  Uint8List get handshakeHash => _session.handshakeHash;

  Future<void> sendMap(Map<String, Object?> message) => sendBytes(utf8.encode(jsonEncode(message)));

  Future<void> sendBytes(List<int> payload) async {
    if (payload.length > noiseMaxTransportPayload) throw const SyncPairingException(SyncPairingErrorCode.refused);
    await _transport.send(_session.encrypt(payload));
  }

  Future<Uint8List> receiveBytes() async => _session.decrypt(await _transport.receive().timeout(_timeout));

  /// The next JSON message. A peer `error` or `abort` message becomes the
  /// matching [SyncPairingException]; a message of another type than
  /// [expected] is a refusal.
  Future<Map<String, dynamic>> receiveMap(String expected) async {
    final decoded = jsonDecode(utf8.decode(await receiveBytes()));
    if (decoded is! Map<String, dynamic>) throw const SyncPairingException(SyncPairingErrorCode.refused);
    final type = decoded[_typeKey];
    if (type == 'abort') throw const SyncPairingException(SyncPairingErrorCode.cancelled);
    if (type == 'error') {
      throw SyncPairingException((decoded[_errorCodeKey] as String?) ?? SyncPairingErrorCode.refused);
    }
    if (type != expected) throw const SyncPairingException(SyncPairingErrorCode.refused);
    return decoded;
  }

  Future<void> sendError(String code) => sendMap({_typeKey: 'error', _errorCodeKey: code});

  Future<void> sendAbort() => sendMap({_typeKey: 'abort'});

  void close() => _session.close();
}

Map<String, Object?> typed(String type, [Map<String, Object?> fields = const {}]) => {_typeKey: type, ...fields};

String hexOf(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List bytesOfHex(String hex) {
  if (hex.length.isOdd || !RegExp(r'^[0-9a-f]*$').hasMatch(hex)) throw const FormatException('bad hex');
  return Uint8List.fromList([for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)]);
}

/// The JSON form of what the inviter hands the joiner (D7).
Map<String, Object?> encodeHandover(PairingHandover handover) => typed('handover', {
      'group': handover.groupId.hex,
      'keys': [
        for (final entry in handover.epochKeys.entries)
          {'c': entry.key.counter, 'cr': entry.key.creator, 'k': base64.encode(entry.value)},
      ],
      'anchors': [for (final anchor in handover.anchors) hexOf(anchor.encode())],
      'revoked': handover.revokedAnchorIds.toList(),
      'revocations': [
        for (final revocation in handover.revocations)
          {
            'r': hexOf(revocation.recordBytes),
            're': revocation.revokerEntryBytes == null ? null : hexOf(revocation.revokerEntryBytes!),
            'co': revocation.carrierOrigin.hex,
            'cs': revocation.carrierSeq,
          },
      ],
    });

/// Throws a [FormatException] or [ArgumentError] for a malformed message.
PairingHandover decodeHandover(Map<String, dynamic> json) => PairingHandover(
      groupId: GroupId.fromHex(json['group'] as String),
      epochKeys: {
        for (final key in json['keys'] as List<dynamic>)
          EpochId((key as Map<String, dynamic>)['c'] as int, key['cr'] as String): base64.decode(key['k'] as String),
      },
      anchors: [
        for (final anchor in json['anchors'] as List<dynamic>) MemberEntry.decode(bytesOfHex(anchor as String)),
      ],
      revokedAnchorIds: (json['revoked'] as List<dynamic>).cast<String>().toSet(),
      revocations: [
        for (final item in json['revocations'] as List<dynamic>)
          LedgerRevocation(
            recordBytes: bytesOfHex((item as Map<String, dynamic>)['r'] as String),
            revokerEntryBytes: item['re'] == null ? null : bytesOfHex(item['re'] as String),
            carrierOrigin: OriginId.fromHex(item['co'] as String),
            carrierSeq: item['cs'] as int,
          ),
      ],
    );

Map<String, Object?> encodeRegistration(OriginRegistration registration) => typed('registration', {
      'o': registration.origin.hex,
      'p': hexOf(registration.memberPub),
      'h': registration.createdHlc,
      's': hexOf(registration.sig),
    });

OriginRegistration decodeRegistration(Map<String, dynamic> json) => OriginRegistration(
      origin: OriginId.fromHex(json['o'] as String),
      memberPub: bytesOfHex(json['p'] as String),
      createdHlc: json['h'] as int,
      sig: bytesOfHex(json['s'] as String),
    );
