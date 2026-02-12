import 'package:flutter_test/flutter_test.dart';
import 'package:application/features/app_usages/models/app_usage_list_item.dart';
import 'package:application/features/app_usages/models/app_usage_sort_fields.dart';
import 'package:application/features/app_usages/utils/app_usage_grouping_helper.dart';
import 'package:application/shared/constants/shared_translation_keys.dart';

void main() {
  group('AppUsageGroupingHelper', () {
    test('getGroupInfo returns null when sortField is null', () {
      final item = AppUsageListItem(
        id: 'com.example',
        name: 'App',
        duration: 0,
        // lastTimeUsed: DateTime.now(), // AppUsageListItem doesn't have lastTimeUsed from usage above, let's double check model
        // Wait, the model viewing result showed: id, name, displayName, color, deviceName, duration, compareDuration, tags, groupName, isGroupNameTranslatable.
        // It does NOT have lastTimeUsed.
      );
      final result = AppUsageGroupingHelper.getGroupInfo(item, null);
      expect(result, isNull);
    });

    test('getGroupInfo groups by Tag', () {
      final itemWithTag = AppUsageListItem(
        id: 'com.example.work',
        name: 'Work App',
        duration: 0,
        tags: [
          AppUsageTagListItem(
            id: 'aut1',
            appUsageId: 'com.example.work',
            tagId: 't1',
            tagName: 'Work',
          )
        ],
      );
      final itemNoTag = AppUsageListItem(
        id: 'com.example.fun',
        name: 'Fun App',
        duration: 0,
        tags: [],
      );

      final groupWithTag = AppUsageGroupingHelper.getGroupInfo(itemWithTag, AppUsageSortFields.tag);
      expect(groupWithTag?.name, 'Work');
      expect(groupWithTag?.isTranslatable, isFalse);

      final groupNoTag = AppUsageGroupingHelper.getGroupInfo(itemNoTag, AppUsageSortFields.tag);
      expect(groupNoTag?.name, SharedTranslationKeys.none);
      expect(groupNoTag?.isTranslatable, isTrue);
    });
  });
}
