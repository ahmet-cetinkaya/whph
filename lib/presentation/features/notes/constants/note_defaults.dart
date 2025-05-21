import 'package:whph/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/core/acore/repository/models/sort_direction.dart';
import 'package:whph/presentation/shared/models/sort_config.dart';
import 'package:whph/presentation/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';

class NoteDefaults {
  static const SortConfig<NoteSortFields> sorting = SortConfig<NoteSortFields>(
    orderOptions: [
      SortOptionWithTranslationKey(
        field: NoteSortFields.createdDate,
        direction: SortDirection.desc,
        translationKey: SharedTranslationKeys.createdDateLabel,
      ),
    ],
    useCustomOrder: false,
  );
}
