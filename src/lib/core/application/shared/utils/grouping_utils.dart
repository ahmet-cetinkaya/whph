import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';

class GroupingUtils {
  static String getTitleGroup(String? title) {
    if (title == null || title.isEmpty) return "#";
    final firstChar = title[0];
    if (firstChar.toUpperCase() != firstChar.toLowerCase()) {
      return firstChar.toUpperCase();
    }
    return "#";
  }

  static String getDurationGroup(int? minutes) {
    if (minutes == null || minutes == 0) return SharedTranslationKeys.none;
    if (minutes < 15) return SharedTranslationKeys.durationLessThan15Min;
    if (minutes < 30) return SharedTranslationKeys.duration15To30Min;
    if (minutes < 60) return SharedTranslationKeys.duration30To60Min;
    if (minutes < 120) return SharedTranslationKeys.duration1To2Hours;
    return SharedTranslationKeys.durationMoreThan2Hours;
  }

  static String getForwardDateGroup(DateTime? date, {DateTime? now}) {
    if (date == null) return SharedTranslationKeys.noDate;

    final nowValue = now ?? DateTime.now();
    final today = DateTime(nowValue.year, nowValue.month, nowValue.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck.isBefore(today)) {
      return SharedTranslationKeys.past;
    } else if (dateToCheck.isAtSameMomentAs(today)) {
      return SharedTranslationKeys.today;
    } else if (dateToCheck.isAtSameMomentAs(tomorrow)) {
      return SharedTranslationKeys.tomorrow;
    } else if (dateToCheck.isBefore(nextWeek)) {
      return SharedTranslationKeys.next7Days;
    } else {
      return SharedTranslationKeys.future;
    }
  }

  static String getBackwardDateGroup(DateTime? date, {DateTime? now}) {
    if (date == null) return SharedTranslationKeys.noDate;

    final nowValue = now ?? DateTime.now();
    final today = DateTime(nowValue.year, nowValue.month, nowValue.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));

    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck.isAtSameMomentAs(today)) {
      return SharedTranslationKeys.today;
    } else if (dateToCheck.isAtSameMomentAs(yesterday)) {
      return SharedTranslationKeys.yesterday;
    } else if (!dateToCheck.isBefore(lastWeek)) {
      return SharedTranslationKeys.last7Days;
    } else {
      return SharedTranslationKeys.older;
    }
  }

  static String getTagGroup(List<dynamic>? tags) {
    if (tags == null || tags.isEmpty) return SharedTranslationKeys.none;
    final firstTag = tags.first;
    if (firstTag is String) return firstTag;

    // Use dynamic access to handle different tag list item types without importing them
    try {
      return (firstTag as dynamic).tagName;
    } catch (_) {
      try {
        return (firstTag as dynamic).name;
      } catch (_) {
        return SharedTranslationKeys.none;
      }
    }
  }
}
