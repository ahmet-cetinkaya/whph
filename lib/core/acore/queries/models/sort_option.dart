import 'package:whph/core/acore/repository/models/sort_direction.dart';

class SortOption<T> {
  final T field;
  final SortDirection direction;

  const SortOption({
    required this.field,
    this.direction = SortDirection.asc,
  });

  SortOption<T> withDirection(SortDirection direction) {
    return SortOption<T>(
      field: field,
      direction: direction,
    );
  }
}
