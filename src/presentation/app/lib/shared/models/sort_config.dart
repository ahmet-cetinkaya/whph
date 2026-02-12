import 'package:whph/shared/models/sort_option_with_translation_key.dart';

class SortConfig<T> {
  final List<SortOptionWithTranslationKey<T>> orderOptions;
  final bool useCustomOrder;
  final bool enableGrouping;
  final SortOptionWithTranslationKey<T>? groupOption;
  final List<String>? customTagSortOrder;

  const SortConfig({
    required this.orderOptions,
    this.useCustomOrder = false,
    this.enableGrouping = false,
    this.groupOption,
    this.customTagSortOrder,
  });

  SortConfig<T> copyWith({
    List<SortOptionWithTranslationKey<T>>? orderOptions,
    bool? useCustomOrder,
    bool? enableGrouping,
    SortOptionWithTranslationKey<T>? groupOption,
    List<String>? customTagSortOrder,
  }) {
    return SortConfig<T>(
      orderOptions: orderOptions ?? this.orderOptions,
      useCustomOrder: useCustomOrder ?? this.useCustomOrder,
      enableGrouping: enableGrouping ?? this.enableGrouping,
      groupOption: groupOption ?? this.groupOption,
      customTagSortOrder: customTagSortOrder ?? this.customTagSortOrder,
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
      groupOption: json['groupOption'] != null
          ? SortOptionWithTranslationKey.fromJson(json['groupOption'] as Map<String, dynamic>, fromJsonT)
          : null,
      customTagSortOrder: (json['customTagSortOrder'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson(dynamic Function(T) toJsonT) {
    return {
      'orderOptions': orderOptions.map((e) => e.toJson(toJsonT)).toList(),
      'useCustomOrder': useCustomOrder,
      'enableGrouping': enableGrouping,
      'groupOption': groupOption?.toJson(toJsonT),
      'customTagSortOrder': customTagSortOrder,
    };
  }
}
