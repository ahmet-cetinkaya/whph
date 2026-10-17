/// Protocol versioning, negotiation, D8 limits and unknown-schema passthrough.
library;

import '../model/change.dart';
import '../store/replica_store.dart';
import 'errors.dart';
import 'messages.dart';

/// The sync protocol version this build speaks (`SYNC_PROTOCOL_VERSION`, D8).
/// The legacy engine is implicitly version 1.
const syncProtocolVersion = 2;

/// The oldest protocol version this build still syncs with
/// (`MIN_COMPATIBLE_PROTOCOL_VERSION`, D8).
const minCompatibleProtocolVersion = 2;

/// D8 limits, enforced by every decoder (FR-015).
abstract final class SyncLimits {
  /// Maximum size of one encoded frame (8 MiB).
  static const maxFrameBytes = 8 * 1024 * 1024;

  /// Maximum payload size of one change value (2 MiB).
  static const maxValueBytes = 2 * 1024 * 1024;

  /// Room for the value encoding header, AEAD tag and future plaintext
  /// framing (T11) on top of [maxValueBytes].
  static const envelopeOverheadBytes = 64;

  /// Maximum envelope ciphertext size.
  static const maxEnvelopeCiphertextBytes = maxValueBytes + envelopeOverheadBytes;

  /// Maximum number of changes in one batch, and of seqs in one manifest.
  static const maxBatchChanges = 1000;
}

// --- Negotiation (FR-040, FR-041, FR-043) -------------------------------------

/// A device named by an `UpdateRequired` outcome.
final class DeviceRef {
  const DeviceRef(this.memberId, this.deviceName);

  final String memberId;
  final String deviceName;

  @override
  bool operator ==(Object other) => other is DeviceRef && other.memberId == memberId && other.deviceName == deviceName;

  @override
  int get hashCode => Object.hash(memberId, deviceName);

  @override
  String toString() => 'DeviceRef($memberId, $deviceName)';
}

/// Outcome of the version check.
sealed class NegotiationResult {
  const NegotiationResult();
}

/// Both devices sync at [agreedVersion] (the lower of the two versions). The
/// app versions play no role (FR-043).
final class Compatible extends NegotiationResult {
  const Compatible(this.agreedVersion);

  final int agreedVersion;

  @override
  String toString() => 'Compatible(v$agreedVersion)';
}

/// No data may be exchanged; [mustUpdate] is the device with the older
/// protocol, shown on both sides (FR-041).
final class Incompatible extends NegotiationResult {
  const Incompatible(this.mustUpdate);

  final DeviceRef mustUpdate;

  @override
  String toString() => 'Incompatible(update ${mustUpdate.deviceName})';
}

/// The version check shared by both sides: compatible iff each side's
/// version is at least the other's minimum. Symmetric: both sides compute
/// the same result.
NegotiationResult negotiate(Hello local, Hello remote) {
  if (local.protocolVersion >= remote.minCompatible && remote.protocolVersion >= local.minCompatible) {
    return Compatible(
      local.protocolVersion < remote.protocolVersion ? local.protocolVersion : remote.protocolVersion,
    );
  }
  // Incompatible implies different versions (each Hello has min <= version).
  final older = local.protocolVersion < remote.protocolVersion ? local : remote;
  return Incompatible(DeviceRef(older.memberId, older.deviceName));
}

/// Responder side: the answer to a received [remote] Hello — a [HelloAck]
/// carrying this device's Hello fields and the agreed version, or
/// [UpdateRequired] naming the older device.
SyncMessage answerHello({required Hello local, required Hello remote}) => switch (negotiate(local, remote)) {
      Compatible(:final agreedVersion) => HelloAck(hello: local, agreedVersion: agreedVersion),
      Incompatible(:final mustUpdate) =>
        UpdateRequired(memberId: mustUpdate.memberId, deviceName: mustUpdate.deviceName),
    };

/// Initiator side: evaluates the responder's [answer] to [local]'s Hello.
///
/// A [HelloAck] is re-checked locally; an agreed version that differs from
/// the local computation is a protocol violation
/// ([MalformedMessageException]). Any other message type before the version
/// check completes is also rejected.
NegotiationResult evaluateHelloAnswer({required Hello local, required SyncMessage answer}) {
  switch (answer) {
    case HelloAck(:final hello, :final agreedVersion):
      final result = negotiate(local, hello);
      if (result is Compatible && result.agreedVersion != agreedVersion) {
        throw MalformedMessageException('HelloAck agreed v$agreedVersion, expected v${result.agreedVersion}');
      }
      if (result is Incompatible) throw const MalformedMessageException('HelloAck from an incompatible peer');
      return result;
    case UpdateRequired(:final memberId, :final deviceName):
      return Incompatible(DeviceRef(memberId, deviceName));
    default:
      throw MalformedMessageException('expected HelloAck or UpdateRequired, got ${answer.type.name}');
  }
}

// --- Unknown table/column passthrough (FR-042) --------------------------------

/// The synced tables and columns this build understands.
abstract interface class SyncSchema {
  bool knowsTable(String table);

  /// Whether [col] of the known [table] is understood. The existence cell
  /// `~` is known for every known table without asking.
  bool knowsColumn(String table, String col);
}

/// A [SyncSchema] backed by a `table -> columns` map.
final class MapSyncSchema implements SyncSchema {
  MapSyncSchema(Map<String, Set<String>> columns)
      : _columns = {for (final e in columns.entries) e.key: Set.unmodifiable(e.value)};

  final Map<String, Set<String>> _columns;

  @override
  bool knowsTable(String table) => _columns.containsKey(table);

  @override
  bool knowsColumn(String table, String col) => _columns[table]?.contains(col) ?? false;
}

/// Why a change cannot be applied to base rows and is held verbatim.
enum PassthroughReason { unknownTable, unknownColumn, unknownValueType }

/// A received change, classified against the local schema.
sealed class ClassifiedChange {
  const ClassifiedChange(this.change);

  final Change change;
}

/// A change this build can apply to its base rows.
final class KnownChange extends ClassifiedChange {
  const KnownChange(super.change);
}

/// A change for a table, column or value type this build does not know. It
/// is stored as-is (`sync_held_cell` kind `unknown`, D8) and relayed
/// unchanged: its canonical bytes, hash and envelope metadata are preserved
/// exactly (FR-042).
final class PassthroughChange extends ClassifiedChange {
  const PassthroughChange(super.change, this.reason);

  final PassthroughReason reason;
}

/// The passthrough reason for a change to [tbl]/[col], or `null` when the
/// schema knows both (usable on envelope metadata before decryption).
PassthroughReason? passthroughReasonFor(SyncSchema schema, String tbl, String col) {
  if (!schema.knowsTable(tbl)) return PassthroughReason.unknownTable;
  if (col != CellKey.existenceCol && !schema.knowsColumn(tbl, col)) return PassthroughReason.unknownColumn;
  return null;
}

/// Classifies [change] against [schema].
ClassifiedChange classifyChange(Change change, SyncSchema schema) {
  final reason = passthroughReasonFor(schema, change.tbl, change.col) ??
      (change.value is UnknownValue ? PassthroughReason.unknownValueType : null);
  return reason == null ? KnownChange(change) : PassthroughChange(change, reason);
}
