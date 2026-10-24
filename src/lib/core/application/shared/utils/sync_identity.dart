import 'package:crypto/crypto.dart';

/// D5: deterministic identities (FR-030). UUIDv5 (RFC 4122 §4.3, SHA-1 via
/// the existing `crypto` package) over the fixed WHPH namespace, with the
/// name format `kind|part|part` adopted verbatim from the S5 spike (U9/PA-4
/// D-6..D-8).
const String whphSyncNamespace = 'c26322fa-390b-53c7-92ba-b001998dc342';

/// Identity kinds (the first name part). Stable strings; never rename one.
const String identityKindHabitRecord = 'habit_record';
const String identityKindSetting = 'setting';
const String identityKindTaskStatus = 'task_status';
const String identityKindRecurringTask = 'recurring_task';
const String identityKindTaskTag = 'task_tag';
const String identityKindHabitTag = 'habit_tag';
const String identityKindNoteTag = 'note_tag';
const String identityKindAppUsageTag = 'app_usage_tag';
const String identityKindTagTag = 'tag_tag';
const String identityKindPairedDevice = 'paired_device';
const String identityKindTimeBucket = 'time_bucket';

/// UUIDv5 of [name] under the WHPH namespace: the fixed identity for equal
/// inputs on any device.
String syncDeterministicId(String name) {
  final namespaceBytes = _uuidBytes(whphSyncNamespace);
  final hash = sha1.convert([...namespaceBytes, ...name.codeUnits]).bytes;

  final h = hash.sublist(0, 16).toList();
  h[6] = (h[6] & 0x0f) | 0x50; // version 5
  h[8] = (h[8] & 0x3f) | 0x80; // RFC variant
  String hex(int from, int to) => h
      .sublist(from, to)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// `kind|part|part` name for a multi-part identity key.
String syncIdentityName(String kind, List<String> parts) =>
    [kind, ...parts].join('|');

/// Convenience: the full deterministic id for a `kind|parts` identity.
String syncIdentityId(String kind, List<String> parts) =>
    syncDeterministicId(syncIdentityName(kind, parts));

List<int> _uuidBytes(String uuid) {
  final hex = uuid.replaceAll('-', '');
  return [
    for (var i = 0; i < 16; i++)
      int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
  ];
}

/// D12: bucket kind part for each time-record table. Stable strings.
const String timeBucketKindTask = 'task_time';
const String timeBucketKindHabit = 'habit_time';
const String timeBucketKindAppUsage = 'app_usage_time';

/// D12: UTC hour-start epoch milliseconds of [at], normalized for the
/// identity key (the stored `created_date`/`usage_date` is unaffected).
int syncBucketHourStartMs(DateTime at) {
  final utc = at.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day, utc.hour)
      .millisecondsSinceEpoch;
}

/// D12: the deterministic id of this device's time-record bucket for
/// [kind] owned by [ownerId] at the UTC hour of [at]. Habits add the
/// `isEstimated` dimension; task and app-usage buckets do not.
String syncTimeBucketId({
  required String kind,
  required String ownerId,
  required DateTime at,
  required String deviceId,
  bool isEstimated = false,
}) {
  final parts = [
    kind,
    ownerId,
    syncBucketHourStartMs(at).toString(),
    deviceId,
    if (kind == timeBucketKindHabit) isEstimated.toString(),
  ];
  return syncIdentityId(identityKindTimeBucket, parts);
}
