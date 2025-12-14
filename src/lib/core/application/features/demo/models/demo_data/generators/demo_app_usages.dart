import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';

/// Demo app usage data generator
class DemoAppUsages {
  /// Demo app usages for development and productivity tracking
  static List<AppUsage> get appUsages => [
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.whatsapp',
          displayName: 'WhatsApp',
          color: '25D366',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 6)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.instagram.android',
          displayName: 'Instagram',
          color: 'E4405F',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 5)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.google.android.youtube',
          displayName: 'YouTube',
          color: 'FF0000',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 4)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.spotify.music',
          displayName: 'Spotify',
          color: '1DB954',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 3)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.twitter.android',
          displayName: 'Twitter',
          color: '1DA1F2',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 2)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.google.android.gm',
          displayName: 'Gmail',
          color: 'EA4335',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.udemy.android',
          displayName: 'Udemy',
          color: 'A435F0',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
      ];

  /// Generates app usage time records with realistic patterns
  static List<AppUsageTimeRecord> generateTimeRecords(List<AppUsage> appUsages) {
    final records = <AppUsageTimeRecord>[];
    final now = DateTime.now();

    // Usage patterns for different app categories
    final socialApps = ['WhatsApp', 'Instagram', 'Twitter'];
    final mediaApps = ['YouTube', 'Spotify'];
    final productivityApps = ['Gmail', 'Udemy'];

    for (final app in appUsages) {
      // Generate 30 days of usage data
      for (int day = 0; day < 30; day++) {
        final recordDate = now.subtract(Duration(days: day));

        // Determine usage pattern based on app type
        int baseDuration;
        int variance;

        if (socialApps.contains(app.displayName)) {
          baseDuration = 20; // 20 minutes base
          variance = 40; // Up to 60 minutes total
        } else if (mediaApps.contains(app.displayName)) {
          baseDuration = 30; // 30 minutes base
          variance = 60; // Up to 90 minutes total
        } else if (productivityApps.contains(app.displayName)) {
          baseDuration = 15; // 15 minutes base
          variance = 25; // Up to 40 minutes total
        } else {
          baseDuration = 10;
          variance = 20;
        }

        // Add some randomness based on day of week
        final weekday = recordDate.weekday;
        final isWeekend = weekday == 6 || weekday == 7;

        if (isWeekend && socialApps.contains(app.displayName)) {
          baseDuration = (baseDuration * 1.5).round();
        }
        if (!isWeekend && productivityApps.contains(app.displayName)) {
          baseDuration = (baseDuration * 2).round();
        }

        // Create 1-3 usage sessions per day
        final sessionCount = 1 + (day % 3);
        for (int session = 0; session < sessionCount; session++) {
          final duration = Duration(
            minutes: baseDuration + ((day * session) % variance),
          );

          records.add(AppUsageTimeRecord(
            id: KeyHelper.generateStringId(),
            appUsageId: app.id,
            duration: duration.inSeconds,
            usageDate: recordDate.subtract(Duration(hours: session * 4)),
            createdDate: recordDate,
          ));
        }
      }
    }

    return records;
  }
}
