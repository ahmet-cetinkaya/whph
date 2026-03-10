import 'package:whph/core/application/features/tags/models/tag_sort_fields.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';

class TagDefaults {
  static const SortConfig<TagSortFields> sorting = SortConfig<TagSortFields>(
    orderOptions: [
      SortOptionWithTranslationKey(
        field: TagSortFields.name,
        direction: SortDirection.asc,
        translationKey: SharedTranslationKeys.nameLabel,
      ),
    ],
    useCustomOrder: false,
    enableGrouping: false,
  );
}
