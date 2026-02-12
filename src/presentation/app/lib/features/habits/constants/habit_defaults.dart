import 'package:application/features/habits/models/habit_sort_fields.dart';
import 'package:acore/acore.dart';
import 'package:whph/shared/models/sort_config.dart';
import 'package:whph/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';

import 'package:whph/features/habits/models/habit_list_style.dart';

class HabitDefaults {
  static const HabitListStyle defaultListStyle = HabitListStyle.grid;

  static const SortConfig<HabitSortFields> sorting = SortConfig<HabitSortFields>(
    orderOptions: [
      SortOptionWithTranslationKey(
        field: HabitSortFields.name,
        direction: SortDirection.asc,
        translationKey: SharedTranslationKeys.nameLabel,
      ),
      SortOptionWithTranslationKey(
        field: HabitSortFields.createdDate,
        direction: SortDirection.desc,
        translationKey: SharedTranslationKeys.createdDateLabel,
      ),
    ],
    useCustomOrder: false,
    enableGrouping: false,
  );
}
