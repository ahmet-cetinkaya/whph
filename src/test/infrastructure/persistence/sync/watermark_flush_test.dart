// The app-level written-watermark flush: a failed ledger write is reported and
// retried on the next flush, and nothing is written when nothing is new.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/sync_ledger_mark_service.dart';
import 'package:whph/infrastructure/shared/features/sync/file_sync_key_store.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../shared/features/sync/sync_security_test_support.dart';
import 'restore_test_support.dart';

/// A key store whose watermark writes fail on demand.
class _FlakyKeyStore extends FileSyncKeyStore {
  _FlakyKeyStore(Directory keyDirectory, Directory ledgerDirectory)
      : super(keyDirectory: keyDirectory, ledgerDirectory: ledgerDirectory);

  int watermarkFailures = 0;

  @override
  Future<void> persistWrittenWatermark(OriginId origin, int nextSeq, int hlc) {
    if (watermarkFailures > 0) {
      watermarkFailures--;
      throw const SyncLedgerWriteException('injected');
    }
    return super.persistWrittenWatermark(origin, nextSeq, hlc);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory scratch;
  late SecurityDevice device;
  late _FlakyKeyStore keyStore;
  late SyncLedgerMarkService marks;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('watermark_flush_');
    device = await SecurityDevice.open('a', scratch, createIdentity: true);
    keyStore = _FlakyKeyStore(device.keyDirectory, device.ledgerDirectory);
    await keyStore.load();
    marks = SyncLedgerMarkService(keyStore: keyStore, changeStore: device.database.store);
    await device.database.insertNote('n1', 'title n1');
  });

  tearDown(() async {
    await device.database.close();
    await scratch.delete(recursive: true);
  });

  test('a failed watermark flush is reported and retried on the next flush', () async {
    keyStore.watermarkFailures = 1;
    expect(await marks.flushWrittenWatermark(), isFalse);
    expect(await marks.flushWrittenWatermark(), isTrue);
    expect(await marks.flushWrittenWatermark(), isFalse, reason: 'nothing new to write');
  });
}
