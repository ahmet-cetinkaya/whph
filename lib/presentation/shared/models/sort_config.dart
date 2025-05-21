import 'package:whph/presentation/shared/models/sort_option_with_translation_key.dart';

class SortConfig<T> {
  final List<SortOptionWithTranslationKey<T>> orderOptions;
  final bool useCustomOrder;

  const SortConfig({
    required this.orderOptions,
    this.useCustomOrder = false,
  });

  SortConfig<T> copyWith({
    List<SortOptionWithTranslationKey<T>>? orderOptions,
    bool? useCustomOrder,
  }) {
    return SortConfig<T>(
      orderOptions: orderOptions ?? this.orderOptions,
      useCustomOrder: useCustomOrder ?? this.useCustomOrder,
    );
  }
}
