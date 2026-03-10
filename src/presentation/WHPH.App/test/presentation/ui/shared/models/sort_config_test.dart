import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';

void main() {
  group('SortConfig', () {
    test('should correctly serialize and deserialize with customTagSortOrder', () {
      final config = SortConfig<TaskSortFields>(
        orderOptions: [
          SortOptionWithTranslationKey(
            field: TaskSortFields.tag,
            translationKey: 'key',
            direction: SortDirection.asc,
          ),
        ],
        customTagSortOrder: ['tag1', 'tag2', 'tag3'],
        useCustomOrder: true,
      );

      final json = config.toJson((field) => field.name);

      expect(json['customTagSortOrder'], isA<List>());
      expect(json['customTagSortOrder'], ['tag1', 'tag2', 'tag3']);
      expect(json['useCustomOrder'], true);

      final decoded = SortConfig<TaskSortFields>.fromJson(
        json,
        (value) => TaskSortFields.values.byName(value),
      );

      expect(decoded.customTagSortOrder, ['tag1', 'tag2', 'tag3']);
      expect(decoded.useCustomOrder, true);
      expect(decoded.orderOptions.first.field, TaskSortFields.tag);
    });
  });
}
