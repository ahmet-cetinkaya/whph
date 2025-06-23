import 'package:acore/acore.dart';

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
