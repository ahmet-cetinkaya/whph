import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';

/// Demo app usage data generator
class DemoAppUsages {
  /// Demo app usages - 15 different apps for a full page
  static List<AppUsage> get appUsages => [
        // Social Apps
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.whatsapp',
          displayName: 'WhatsApp',
          color: '25D366',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.instagram.android',
          displayName: 'Instagram',
          color: 'E4405F',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.twitter.android',
          displayName: 'Twitter',
          color: '1DA1F2',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.facebook.katana',
          displayName: 'Facebook',
          color: '1877F2',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),

        // Media Apps
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.google.android.youtube',
          displayName: 'YouTube',
          color: 'FF0000',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.spotify.music',
          displayName: 'Spotify',
          color: '1DB954',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.netflix.mediaclient',
          displayName: 'Netflix',
          color: 'E50914',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),

        // Productivity Apps
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.google.android.gm',
          displayName: 'Gmail',
          color: 'EA4335',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.slack',
          displayName: 'Slack',
          color: '4A154B',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.microsoft.teams',
          displayName: 'Teams',
          color: '464EB8',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),

        // Learning Apps
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.udemy.android',
          displayName: 'Udemy',
          color: 'A435F0',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.duolingo',
          displayName: 'Duolingo',
          color: '58CC02',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),

        // Utility Apps
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.google.android.apps.maps',
          displayName: 'Maps',
          color: '4285F4',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.google.android.calendar',
          displayName: 'Calendar',
          color: '4285F4',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.amazon.mShop.android.shopping',
          displayName: 'Amazon',
          color: 'FF9900',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
      ];

  /// Generates app usage time records for last 7 days with reduced, realistic patterns
  static List<AppUsageTimeRecord> generateTimeRecords(List<AppUsage> appUsages) {
    final records = <AppUsageTimeRecord>[];
    final now = DateTime.now();

    // Usage patterns for different app categories
    final socialApps = ['WhatsApp', 'Instagram', 'Twitter', 'Facebook'];
    final mediaApps = ['YouTube', 'Spotify', 'Netflix'];
    final productivityApps = ['Gmail', 'Slack', 'Teams'];
    final learningApps = ['Udemy', 'Duolingo'];

    for (final app in appUsages) {
      // Generate 7 days of usage data (last week)
      for (int day = 0; day < 7; day++) {
        final recordDate = now.subtract(Duration(days: day));

        // Determine usage pattern based on app type
        int durationMinutes;

        if (socialApps.contains(app.displayName)) {
          durationMinutes = 15 + (day * 3) % 20; // 15-35 minutes
        } else if (mediaApps.contains(app.displayName)) {
          durationMinutes = 20 + (day * 5) % 30; // 20-50 minutes
        } else if (productivityApps.contains(app.displayName)) {
          durationMinutes = 10 + (day * 2) % 15; // 10-25 minutes
        } else if (learningApps.contains(app.displayName)) {
          durationMinutes = 15 + (day * 4) % 25; // 15-40 minutes
        } else {
          durationMinutes = 5 + (day * 2) % 10; // 5-15 minutes
        }

        // Single session per day to reduce records
        records.add(AppUsageTimeRecord(
          id: KeyHelper.generateStringId(),
          appUsageId: app.id,
          duration: durationMinutes * 60, // Convert to seconds
          usageDate: recordDate,
          createdDate: recordDate,
        ));
      }
    }

    return records;
  }
}
