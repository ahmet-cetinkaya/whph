class AppUsageTimeRecordWithDetails {
  final String id;
  final String name;
  final String? displayName;
  final String? color;
  final String? deviceName;
  final int duration;

  AppUsageTimeRecordWithDetails({
    required this.id,
    required this.name,
    this.displayName,
    this.color,
    this.deviceName,
    required this.duration,
  });
}
