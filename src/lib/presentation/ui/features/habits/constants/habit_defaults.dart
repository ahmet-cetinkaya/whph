import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';

class HabitDefaults {
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
  );
}
