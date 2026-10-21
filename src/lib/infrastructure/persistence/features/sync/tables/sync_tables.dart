import 'package:drift/drift.dart';

/// Local-only sync metadata (D13). One row; ids are fixed at 'singleton'.
class SyncStateTable extends Table {
  TextColumn get id => text()();
  TextColumn get memberId => text().nullable()();
  TextColumn get groupId => text().nullable()();
  TextColumn get localOriginId => text().nullable()();
  IntColumn get hlc => integer().withDefault(const Constant(0))();
  IntColumn get nextSeq => integer().withDefault(const Constant(1))();
  IntColumn get applyMode => integer().withDefault(const Constant(0))();
  IntColumn get cascadeCauseTblId => integer().nullable()();
  TextColumn get cascadeCausePk => text().nullable()();
  TextColumn get reauthorSpec => text().nullable()();
  TextColumn get upgradePhase => text().nullable()();
  IntColumn get upgradeCursor => integer().withDefault(const Constant(0))();
  TextColumn get captureVersion => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local-only integer interning of node and origin ids (D1). Integers never
/// leave the device.
class SyncInternTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()();
  TextColumn get value => text()();

  @override
  List<String> get customConstraints => ['UNIQUE(kind, value)'];
}

/// Local-only row-key interning for the PA-1 V2 physical clock shape (D1).
/// A row id is never reused while a cause references it (AUTOINCREMENT).
class SyncRowTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tblId => integer()();
  TextColumn get pk => text()();

  @override
  List<String> get customConstraints => ['UNIQUE(tbl_id, pk)'];
}

/// Per-cell clock metadata (D1, PA-1 V2 physical shape): key is
/// row_id * 256 + col_id. `tombValue` carries the row's deleted_date for the
/// existence cell; `causeRowId` links cascade child tombstones (D5b).
class SyncClockTable extends Table {
  IntColumn get key => integer()();
  IntColumn get hlc => integer()();
  IntColumn get nodeId => integer()();
  IntColumn get originId => integer()();
  IntColumn get originSeq => integer()();
  IntColumn get manifestId => integer().nullable()();
  IntColumn get tombValue => integer().nullable()();
  IntColumn get causeRowId => integer().nullable()();
  IntColumn get recordedAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Synced (D13): one row per group member. `id = UUIDv5(member id)`.
class SyncMemberTableTable extends Table {
  TextColumn get id => text()();
  TextColumn get memberId => text()();
  TextColumn get name => text().nullable()();
  TextColumn get platform => text().nullable()();
  TextColumn get x25519Pub => text()();
  TextColumn get ed25519Pub => text()();
  TextColumn get addedBy => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get deletedDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Synced (D7): origin registrations, self-authenticating rows sent first in
/// every session.
class SyncOriginTable extends Table {
  TextColumn get originId => text()();
  TextColumn get memberEd25519Pub => text()();
  IntColumn get createdHlc => integer()();
  TextColumn get sig => text()();
  DateTimeColumn get createdDate => dateTime()();

  @override
  Set<Column> get primaryKey => {originId};
}

/// Synced (D7): revocation records with per-origin cutoffs.
class SyncRevocationTable extends Table {
  TextColumn get revokedPub => text()();
  TextColumn get revokerPub => text()();
  TextColumn get originId => text()();
  IntColumn get originSeq => integer()();
  TextColumn get cutoffs => text()();
  TextColumn get sig => text()();
  IntColumn get hlc => integer()();

  @override
  Set<Column> get primaryKey => {revokedPub, revokerPub};
}

/// Synced (D7): epoch key grants.
class SyncEpochGrantTable extends Table {
  TextColumn get id => text()();
  IntColumn get counter => integer()();
  TextColumn get creator => text()();
  TextColumn get grantedTo => text()();
  TextColumn get keyCiphertext => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Synced (D7): manifests, forwarded verbatim by relays.
class SyncOriginBatchTable extends Table {
  IntColumn get manifestId => integer()();
  TextColumn get originId => text()();
  IntColumn get fromSeq => integer()();
  IntColumn get toSeq => integer()();
  BlobColumn get hashes => blob()();
  TextColumn get sig => text()();

  @override
  Set<Column> get primaryKey => {manifestId};
}

/// Local-only (D13): this device's received vector per origin.
class SyncVectorTable extends Table {
  TextColumn get originId => text()();
  IntColumn get cursor => integer()();

  @override
  Set<Column> get primaryKey => {originId};
}

/// Local-only (D13): last-known peer transport state.
class SyncPeerStateTableTable extends Table {
  TextColumn get memberId => text()();
  TextColumn get addresses => text()();
  DateTimeColumn get lastSuccessLocal => dateTime().nullable()();
  TextColumn get lastResultCategory => text().nullable()();
  IntColumn get lastPeerWall => integer().nullable()();
  DateTimeColumn get lastPeerWallReceived => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {memberId};
}

/// Local-only (D13): encrypted changes held unapplied.
class SyncHeldEnvelopeTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tbl => text()();
  TextColumn get pk => text()();
  TextColumn get col => text()();
  TextColumn get peer => text()();
  TextColumn get reason => text()();
  IntColumn get failCount => integer().withDefault(const Constant(0))();
  TextColumn get category => text().nullable()();
  BlobColumn get envelope => blob()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local-only (D13): decrypted cells held outside base rows.
class SyncHeldCellTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tbl => text()();
  TextColumn get pk => text()();
  TextColumn get col => text()();
  TextColumn get kind => text()();
  BlobColumn get value => blob().nullable()();
  IntColumn get hlc => integer()();
  TextColumn get node => text()();
  TextColumn get originId => text()();
  IntColumn get originSeq => integer()();
  IntColumn get manifestId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
