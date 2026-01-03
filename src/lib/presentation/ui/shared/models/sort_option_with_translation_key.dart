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

  factory SortOptionWithTranslationKey.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonT) {
    return SortOptionWithTranslationKey(
      field: fromJsonT(json['field']),
      translationKey: json['translationKey'] as String,
      direction: SortDirection.values.firstWhere(
        (e) => e.toString() == json['direction'],
        orElse: () => SortDirection.asc,
      ),
    );
  }

  Map<String, dynamic> toJson(dynamic Function(T) toJsonT) {
    return {
      'field': toJsonT(field),
      'translationKey': translationKey,
      'direction': direction.toString(),
    };
  }
}
