import 'package:whph/corePackages/acore/repository/models/sort_direction.dart';

class CustomOrder {
  final String field;
  final SortDirection direction;

  CustomOrder({required this.field, this.direction = SortDirection.asc});
}
