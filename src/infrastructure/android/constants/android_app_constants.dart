class AndroidAppConstants {
  static const String packageName = 'me.ahmetcetinkaya.whph';

  static const channels = _Channels();
  static const notificationChannels = _NotificationChannels();
}

class _Channels {
  const _Channels();

  final String batteryOptimization = 'me.ahmetcetinkaya.whph/battery_optimization';
  final String exactAlarm = 'me.ahmetcetinkaya.whph/exact_alarm';
  final String notification = 'me.ahmetcetinkaya.whph/notification';
}

class _NotificationChannels {
  const _NotificationChannels();

  final String taskChannelId = 'task_channel';
  final String taskChannelName = 'Tasks';
  final String habitChannelId = 'habit_channel';
  final String habitChannelName = 'Habits';
}
