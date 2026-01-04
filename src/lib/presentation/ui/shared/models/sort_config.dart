import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';

class SortConfig<T> {
  final List<SortOptionWithTranslationKey<T>> orderOptions;
  final bool useCustomOrder;
  final bool enableGrouping;

  const SortConfig({
    required this.orderOptions,
    this.useCustomOrder = false,
    this.enableGrouping = false,
  });

  SortConfig<T> copyWith({
    List<SortOptionWithTranslationKey<T>>? orderOptions,
    bool? useCustomOrder,
    bool? enableGrouping,
  }) {
    return SortConfig<T>(
      orderOptions: orderOptions ?? this.orderOptions,
      useCustomOrder: useCustomOrder ?? this.useCustomOrder,
      enableGrouping: enableGrouping ?? this.enableGrouping,
    );
  }

  factory SortConfig.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonT) {
    return SortConfig(
      orderOptions: (json['orderOptions'] as List<dynamic>?)
              ?.map((e) => SortOptionWithTranslationKey.fromJson(e as Map<String, dynamic>, fromJsonT))
              .toList() ??
          [],
      useCustomOrder: json['useCustomOrder'] as bool? ?? false,
      enableGrouping: json['enableGrouping'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson(dynamic Function(T) toJsonT) {
    return {
      'orderOptions': orderOptions.map((e) => e.toJson(toJsonT)).toList(),
      'useCustomOrder': useCustomOrder,
      'enableGrouping': enableGrouping,
    };
  }
}
