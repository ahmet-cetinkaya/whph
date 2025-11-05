import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/infrastructure/android/features/app_usage/android_app_usage_service.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_filter_service.dart';

/// Debug screen to test and compare app usage calculation methods.
/// This helps identify why usage statistics are inflated compared to Digital Wellbeing.
class AndroidAppUsageDebugPage extends StatefulWidget {
  final AndroidAppUsageService appUsageService;

  AndroidAppUsageDebugPage({super.key})
      : appUsageService = AndroidAppUsageService(
          container.resolve<IAppUsageRepository>(),
          container.resolve<IAppUsageTimeRecordRepository>(),
          container.resolve<IAppUsageTagRuleRepository>(),
          container.resolve<IAppUsageTagRepository>(),
          container.resolve<IAppUsageFilterService>(),
        );

  @override
  State<AndroidAppUsageDebugPage> createState() => _AndroidAppUsageDebugPageState();
}

class _AndroidAppUsageDebugPageState extends State<AndroidAppUsageDebugPage> {
  Map<String, dynamic>? _testResults;
  Map<String, dynamic>? _newMethodResults;
  bool _isLoading = false;
  String _selectedTimeRange = 'last_hour';

  final Map<String, String> _timeRanges = {
    'last_hour': 'Last Hour',
    'last_2_hours': 'Last 2 Hours',
    'last_4_hours': 'Last 4 Hours',
    'last_8_hours': 'Last 8 Hours',
    'last_12_hours': 'Last 12 Hours',
    'last_24_hours': 'Last 24 Hours',
    'today_from_midnight': 'Today (from midnight)',
    'yesterday': 'Yesterday (full day)',
    'last_3_days': 'Last 3 Days',
    'last_week': 'Last Week',
  };

  DateTime _getStartTime(String timeRange, DateTime now) {
    switch (timeRange) {
      case 'last_hour':
        return now.subtract(const Duration(hours: 1));
      case 'last_2_hours':
        return now.subtract(const Duration(hours: 2));
      case 'last_4_hours':
        return now.subtract(const Duration(hours: 4));
      case 'last_8_hours':
        return now.subtract(const Duration(hours: 8));
      case 'last_12_hours':
        return now.subtract(const Duration(hours: 12));
      case 'last_24_hours':
        return now.subtract(const Duration(hours: 24));
      case 'today_from_midnight':
        return DateTime(now.year, now.month, now.day, 0, 0, 0); // Today from midnight
      case 'yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
      case 'last_3_days':
        return now.subtract(const Duration(days: 3));
      case 'last_week':
        return now.subtract(const Duration(days: 7));
      default:
        return now.subtract(const Duration(hours: 1));
    }
  }

  DateTime _getEndTime(String timeRange, DateTime now) {
    switch (timeRange) {
      case 'yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
      default:
        return now;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: const Text('App Usage Debug'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Range Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Range',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _selectedTimeRange,
                      isExpanded: true,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedTimeRange = newValue!;
                        });
                      },
                      items: _timeRanges.keys.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(_timeRanges[value]!),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _runTest,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Test Usage Accuracy'),
              ),
            ),
            const SizedBox(height: 16),

            // Results
            if (_testResults != null) ...[
              Expanded(
                child: SingleChildScrollView(
                  child: _buildResults(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _runTest() async {
    setState(() {
      _isLoading = true;
      _newMethodResults = null;
    });

    try {
      final now = DateTime.now();
      final startTime = _getStartTime(_selectedTimeRange, now);
      final endTime = _getEndTime(_selectedTimeRange, now);

      final results = await widget.appUsageService.testUsageAccuracy(
        startTime: startTime,
        endTime: endTime,
      );

      setState(() {
        _newMethodResults = results;
      });

      // Print compact results to console
      _printCompactResults(results);
    } catch (e) {
      Logger.error('Error running usage test: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildResults() {
    if (_newMethodResults == null) return const SizedBox.shrink();

    if (_newMethodResults!.containsKey('error')) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Error',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red),
              ),
              const SizedBox(height: 8),
              Text(_newMethodResults!['error'].toString()),
            ],
          ),
        ),
      );
    }

    final timeRange = _newMethodResults!['timeRange'] as Map<String, dynamic>?;
    if (timeRange == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No time range data available'),
        ),
      );
    }

    // Handle both old and new key names for backward compatibility
    final Map<String, dynamic> newMethod = (_newMethodResults!['newMethod'] ??
        _newMethodResults!['eventBasedMethod'] ??
        <String, dynamic>{}) as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time Range Info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time Range',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Start: ${timeRange['start']}'),
                Text('End: ${timeRange['end']}'),
                Text('Selected Range: ${_timeRanges[_selectedTimeRange]}'),
                Text('Duration: ${timeRange['durationHours']} hours'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Event-based Method Apps: ${newMethod.length}'),
                const SizedBox(height: 8),
                Text(
                  'Event-based Method Apps:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                ...newMethod.entries.take(5).map((entry) {
                  final appData = entry.value as Map<String, dynamic>;
                  final appName = appData['appName'] as String;
                  final usageMinutes = (appData['usageTimeSeconds'] as int) / 60;
                  return Text('  • $appName: ${usageMinutes.toStringAsFixed(1)}m');
                }),
                if (newMethod.length > 5) Text('  • ... and ${newMethod.length - 5} more'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Prints compact test results to console for easy analysis
  void _printCompactResults(Map<String, dynamic> results) {
    if (results.containsKey('error')) {
      Logger.error('=== DEBUG TEST ERROR ===');
      Logger.error('Error: ${results['error']}');
      return;
    }

    final timeRange = results['timeRange'] as Map<String, dynamic>?;
    if (timeRange == null) {
      Logger.error('No time range data available');
      return;
    }

    // Handle both old and new key names for backward compatibility
    final Map<String, dynamic> newMethod =
        (results['newMethod'] ?? results['eventBasedMethod'] ?? <String, dynamic>{}) as Map<String, dynamic>;

    Logger.info('');
    Logger.info('=== USAGE DEBUG RESULTS ===');
    Logger.info('Range: ${_timeRanges[_selectedTimeRange]}');
    Logger.info('From: ${timeRange['start']}');
    Logger.info('To: ${timeRange['end']}');
    Logger.info('Duration: ${timeRange['durationHours']} hours');
    Logger.info('');

    Logger.info('--- SUMMARY ---');
    Logger.info('Event-based Method: ${newMethod.length} apps');
    Logger.info('');

    Logger.info('--- EVENT-BASED METHOD (accurate foreground) ---');
    final newSorted = newMethod.entries.toList()
      ..sort((a, b) {
        final aSeconds = (a.value as Map<String, dynamic>)['usageTimeSeconds'] as int;
        final bSeconds = (b.value as Map<String, dynamic>)['usageTimeSeconds'] as int;
        return bSeconds.compareTo(aSeconds); // Descending order
      });

    for (final entry in newSorted.take(10)) {
      final appData = entry.value as Map<String, dynamic>;
      final appName = appData['appName'] as String;
      final seconds = appData['usageTimeSeconds'] as int;
      final minutes = (seconds / 60).toStringAsFixed(1);
      Logger.info('  • $appName: ${minutes}m (${seconds}s)');
    }
    if (newSorted.length > 10) {
      Logger.info('  • ... and ${newSorted.length - 10} more apps');
    }
    Logger.info('');

    Logger.info('=== END DEBUG RESULTS ===');
    Logger.info('');
  }
}
