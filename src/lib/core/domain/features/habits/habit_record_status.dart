enum HabitRecordStatus {
  complete('complete'),
  notDone('not_done'),
  unknown('unknown');

  final String value;
  const HabitRecordStatus(this.value);

  static HabitRecordStatus fromString(String value) {
    return HabitRecordStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => HabitRecordStatus.unknown,
    );
  }
}
