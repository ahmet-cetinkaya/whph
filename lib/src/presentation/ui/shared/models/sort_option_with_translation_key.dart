import 'package:whph/corePackages/acore/queries/models/sort_option.dart';
import 'package:whph/corePackages/acore/repository/models/sort_direction.dart';

class SortOptionWithTranslationKey<T> extends SortOption<T> {
  final String translationKey;

  const SortOptionWithTranslationKey({
    required super.field,
    required this.translationKey,
    super.direction = SortDirection.asc,
  });

  @override
  SortOptionWithTranslationKey<T> withDirection(SortDirection direction) {
    return SortOptionWithTranslationKey<T>(
      field: field,
      translationKey: translationKey,
      direction: direction,
    );
  }
}
