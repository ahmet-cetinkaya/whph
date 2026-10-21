/// D1/D3: the one registry of synced user tables. `tblId` and `colId` are
/// fixed constants baked into the generated trigger SQL (PA-4 D-8); changing
/// one is a plan amendment, never a local refactor.
///
/// Levels (D1): field-level tables capture one cell per synced column;
/// row-level tables (D11: `task_time_record`, `habit_time_record`,
/// `app_usage_time_record`) capture a single `*` cell. `~` (colId 0) is the
/// existence cell every table has; `*` is colId 1.
///
/// The sync_* tables themselves are written only by the change store inside
/// `apply_mode` and get no triggers; `sync_device_table` is legacy pairing
/// state, never synced.
library;

const int tombstoneColId = 0;
const int rowLevelColId = 1;
const int packedKeyFactor = 256;

class SyncTablePolicy {
  final String tableName;
  final int tblId;
  final bool rowLevel;

  /// Synced columns (id/created_date/modified_date/deleted_date excluded)
  /// with their fixed col ids, 2.. on field-level tables; empty on row-level.
  final Map<String, int> columns;

  const SyncTablePolicy({
    required this.tableName,
    required this.tblId,
    required this.rowLevel,
    this.columns = const {},
  });

  static const Set<String> excludedColumns = {
    'id',
    'created_date',
    'modified_date',
    'deleted_date'
  };
}

// tblId space: user tables 1..99 in the order below; 100+ reserved.
// Levels per plan D1 (row-level list): AppUsageTimeRecord, TaskTimeRecord,
// HabitRecord, HabitTimeRecord, AppUsageTagRule, AppUsageIgnoreRule and the
// join tables TaskTag, HabitTag, NoteTag, AppUsageTag, TagTag.
const List<SyncTablePolicy> syncTablePolicies = [
  SyncTablePolicy(tableName: 'task_table', tblId: 1, rowLevel: false, columns: {
    'parent_task_id': 2,
    'title': 3,
    'description': 4,
    'priority': 5,
    'planned_date': 6,
    'deadline_date': 7,
    'estimated_time': 8,
    'completed_at': 9,
    'status_id': 10,
    'order': 11,
    'planned_date_reminder_time': 12,
    'deadline_date_reminder_time': 13,
    'planned_date_reminder_custom_offset': 14,
    'deadline_date_reminder_custom_offset': 15,
    'recurrence_type': 16,
    'recurrence_interval': 17,
    'recurrence_days_string': 18,
    'recurrence_start_date': 19,
    'recurrence_end_date': 20,
    'recurrence_count': 21,
    'recurrence_parent_id': 22,
    'recurrence_configuration': 23,
  }),
  SyncTablePolicy(tableName: 'task_tag_table', tblId: 2, rowLevel: true),
  SyncTablePolicy(
      tableName: 'task_time_record_table', tblId: 3, rowLevel: true),
  SyncTablePolicy(
      tableName: 'task_status_table',
      tblId: 4,
      rowLevel: false,
      columns: {
        'name': 2,
        'color': 3,
        'order': 4,
        'is_built_in': 5,
        'is_done_status': 6,
      }),
  SyncTablePolicy(
      tableName: 'habit_table',
      tblId: 5,
      rowLevel: false,
      columns: {
        'type': 2,
        'name': 3,
        'description': 4,
        'estimated_time': 5,
        'archived_date': 6,
        'has_reminder': 7,
        'reminder_time': 8,
        'reminder_days': 9,
        'has_goal': 10,
        'target_frequency': 11,
        'period_days': 12,
        'daily_target': 13,
        'order': 14,
      }),
  SyncTablePolicy(tableName: 'habit_record_table', tblId: 6, rowLevel: true),
  SyncTablePolicy(tableName: 'habit_tag_table', tblId: 7, rowLevel: true),
  SyncTablePolicy(
      tableName: 'habit_time_record_table', tblId: 8, rowLevel: true),
  SyncTablePolicy(tableName: 'note_table', tblId: 9, rowLevel: false, columns: {
    'title': 2,
    'content': 3,
    'order': 4,
  }),
  SyncTablePolicy(tableName: 'note_tag_table', tblId: 10, rowLevel: true),
  SyncTablePolicy(tableName: 'tag_table', tblId: 11, rowLevel: false, columns: {
    'name': 2,
    'color': 3,
    'is_archived': 4,
    'type': 5,
  }),
  SyncTablePolicy(tableName: 'tag_tag_table', tblId: 12, rowLevel: true),
  SyncTablePolicy(
      tableName: 'setting_table',
      tblId: 13,
      rowLevel: false,
      columns: {
        'key': 2,
        'value': 3,
        'value_type': 4,
      }),
  SyncTablePolicy(
      tableName: 'app_usage_table',
      tblId: 14,
      rowLevel: false,
      columns: {
        'name': 2,
        'display_name': 3,
        'color': 4,
        'device_name': 5,
      }),
  SyncTablePolicy(tableName: 'app_usage_tag_table', tblId: 15, rowLevel: true),
  SyncTablePolicy(
      tableName: 'app_usage_tag_rule_table', tblId: 16, rowLevel: true),
  SyncTablePolicy(
      tableName: 'app_usage_ignore_rule_table', tblId: 17, rowLevel: true),
  SyncTablePolicy(
      tableName: 'app_usage_time_record_table', tblId: 18, rowLevel: true),
];
