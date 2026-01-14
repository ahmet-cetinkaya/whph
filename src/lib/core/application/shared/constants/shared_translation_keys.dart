class SharedTranslationKeys {
  // No domain/business logic errors for shared currently
  // This serves as the base class for presentation layer extensions

  static const String none = 'shared.none';
  static const String today = 'shared.date_group.today';
  static const String tomorrow = 'shared.date_group.tomorrow';
  static const String past = 'shared.date_group.past';
  static const String future = 'shared.date_group.future';
  static const String next7Days = 'shared.date_group.next_7_days';
  static const String noDate = 'shared.date_group.no_date';
  static const String yesterday = 'shared.date_group.yesterday';
  static const String last7Days = 'shared.date_group.last_7_days';
  static const String older = 'shared.date_group.older';

  // Duration bucket keys
  static const String durationLessThan15Min = 'shared.duration_group.less_than_15_min';
  static const String duration15To30Min = 'shared.duration_group.15_30_min';
  static const String duration30To60Min = 'shared.duration_group.30_60_min';
  static const String duration1To2Hours = 'shared.duration_group.1_2_hours';
  static const String durationMoreThan2Hours = 'shared.duration_group.more_than_2_hours';

  // Sort related keys
  static const String sortEnableGrouping = 'shared.sort.enable_grouping';
  static const String sortEnableGroupingDescription = 'shared.sort.enable_grouping_description';
  static const String sortAndGroup = 'shared.sort.sort_and_group';

  // Singular time unit keys for proper pluralization
  static const String timeMinute = 'shared.time.minute';
  static const String timeHour = 'shared.time.hour';
  static const String timeDay = 'shared.time.day';
  static const String timeWeek = 'shared.time.week';

  // Share related keys
  static const String shareDialogTitle = 'shared.share.dialog_title';
  static const String shareCreateTask = 'shared.share.create_task';
  static const String shareCreateTaskDescription = 'shared.share.create_task_description';
  static const String shareCreateNote = 'shared.share.create_note';
  static const String shareCreateNoteDescription = 'shared.share.create_note_description';
  static const String shareTaskCreated = 'shared.share.task_created';
  static const String shareNoteCreated = 'shared.share.note_created';
  static const String shareFailedToCreate = 'shared.share.failed_to_create';
}
