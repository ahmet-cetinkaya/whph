import 'package:whph/src/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/src/presentation/ui/shared/models/sort_option_with_translation_key.dart';

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
  );
}
