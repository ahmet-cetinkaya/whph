import 'package:flutter/foundation.dart';
import 'package:whph/application/features/app_usages/commands/save_app_usage_command.dart';

class AppUsagesService {
  final ValueNotifier<SaveAppUsageCommandResponse?> onAppUsageSaved = ValueNotifier(null);
}
