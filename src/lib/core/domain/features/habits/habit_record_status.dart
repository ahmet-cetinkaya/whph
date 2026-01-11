enum HabitRecordStatus {
  complete('complete'),
  notDone('not_done'),
  skipped('skipped');

  final String value;
  const HabitRecordStatus(this.value);

  static HabitRecordStatus fromString(String value) {
    if (value == 'unknown') return HabitRecordStatus.skipped;
    return HabitRecordStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => HabitRecordStatus.skipped,
    );
  }
}
