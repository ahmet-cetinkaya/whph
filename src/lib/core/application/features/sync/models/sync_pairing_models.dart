import 'dart:convert';
import 'dart:typed_data';

/// TCP port of the LAN sync server (D7). The transport layer binds it.
const int syncLanPort = 44040;

const String _invitationPrefix = 'whph-pair:1:';

/// What the QR code of a pairing invitation carries (FR-024, FR-025): where to
/// connect, who answers, the fingerprint of its static key and the one-time
/// token. [toString] never prints the token.
class PairingInvitation {
  final String memberId;
  final List<String> addresses;
  final int port;
  final Uint8List fingerprint;
  final Uint8List token;
  final DateTime expiresAt;

  PairingInvitation({
    required this.memberId,
    required this.addresses,
    required this.port,
    required List<int> fingerprint,
    required List<int> token,
    required this.expiresAt,
  })  : fingerprint = Uint8List.fromList(fingerprint),
        token = Uint8List.fromList(token);

  /// The text to show as a QR code.
  String encode() {
    final json = jsonEncode({
      'm': memberId,
      'a': addresses,
      'p': port,
      'f': base64Url.encode(fingerprint),
      't': base64Url.encode(token),
      'e': expiresAt.millisecondsSinceEpoch,
    });
    return _invitationPrefix + base64Url.encode(utf8.encode(json));
  }

  /// Parses [text] from a scanned QR code. Throws a [FormatException] when it
  /// is not a well-formed invitation.
  static PairingInvitation decode(String text) {
    if (!text.startsWith(_invitationPrefix)) throw const FormatException('not a pairing invitation');
    final json = jsonDecode(utf8.decode(base64Url.decode(text.substring(_invitationPrefix.length))));
    if (json is! Map<String, dynamic>) throw const FormatException('malformed invitation');
    final addresses = (json['a'] as List<dynamic>).cast<String>();
    final port = json['p'] as int;
    final memberId = json['m'] as String;
    if (addresses.isEmpty || memberId.isEmpty || port < 1 || port > 65535) {
      throw const FormatException('invalid invitation fields');
    }
    return PairingInvitation(
      memberId: memberId,
      addresses: addresses,
      port: port,
      fingerprint: base64Url.decode(json['f'] as String),
      token: base64Url.decode(json['t'] as String),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['e'] as int),
    );
  }

  @override
  String toString() => 'PairingInvitation($memberId, ${addresses.length} addresses, <redacted>)';
}

/// Which side of a pairing this device plays.
enum SyncPairingRole { inviter, joiner }

enum SyncPairingPhase {
  idle,

  /// The inviter shows its invitation and waits for a scan.
  waitingForScan,
  connecting,

  /// Both screens show [SyncPairingStatus.code]; the user compares and confirms.
  comparingCodes,

  /// The joiner would leave a group that has other members and needs the
  /// user's confirmation before the handover is requested.
  awaitingGroupSwitch,
  exchanging,
  completed,
  failed,
}

/// The state of the pairing in progress (or the last one). UI text for it is
/// T24; [errorCode] is a `SyncPairingErrorCode` value.
class SyncPairingStatus {
  final SyncPairingPhase phase;
  final SyncPairingRole? role;
  final String? code;
  final String? peerName;
  final String? peerMemberId;
  final String? errorCode;

  const SyncPairingStatus({
    required this.phase,
    this.role,
    this.code,
    this.peerName,
    this.peerMemberId,
    this.errorCode,
  });

  static const SyncPairingStatus idle = SyncPairingStatus(phase: SyncPairingPhase.idle);

  bool get isTerminal => phase == SyncPairingPhase.completed || phase == SyncPairingPhase.failed;

  @override
  String toString() => 'SyncPairingStatus($phase, error: $errorCode)';
}

/// A pairing step was refused or failed; nothing was changed on this device
/// beyond what the status reports. [code] is a `SyncPairingErrorCode` value.
class SyncPairingException implements Exception {
  final String code;
  const SyncPairingException(this.code);

  @override
  String toString() => 'SyncPairingException: $code';
}
