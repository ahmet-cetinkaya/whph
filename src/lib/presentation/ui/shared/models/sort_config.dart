import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';

class SortConfig<T> {
  final List<SortOptionWithTranslationKey<T>> orderOptions;
  final bool useCustomOrder;
  final bool enableGrouping;

  const SortConfig({
    required this.orderOptions,
    this.useCustomOrder = false,
    this.enableGrouping = true,
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
}
